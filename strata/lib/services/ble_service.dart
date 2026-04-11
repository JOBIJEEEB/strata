import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Set to true to use SoilMockGenerator instead of the real Pi hardware.
// Set to false for production / real hardware testing.
// ─────────────────────────────────────────────────────────────────────────────
const bool kBleDebugMode = false;

// ── UUID constants ────────────────────────────────────────────────────────────
class StrataUUIDs {
  StrataUUIDs._();

  static const String service = '56c36f56-da27-464a-952a-9e6631168f6d';

  // Pi diagnostics
  static const String cpuUsage = '56c36f57-da27-464a-952a-9e6631168f6d';
  static const String cpuTemp = '56c36f58-da27-464a-952a-9e6631168f6d';
  static const String battery = '56c36f59-da27-464a-952a-9e6631168f6d';

  // Soil sensors
  static const String soilPh = '56c36f60-da27-464a-952a-9e6631168f6d';
  static const String soilMoisture = '56c36f61-da27-464a-952a-9e6631168f6d';
  static const String soilTemp = '56c36f62-da27-464a-952a-9e6631168f6d';
  static const String ecLevel = '56c36f63-da27-464a-952a-9e6631168f6d';
  static const String nitrogen = '56c36f64-da27-464a-952a-9e6631168f6d';
  static const String phosphorus = '56c36f65-da27-464a-952a-9e6631168f6d';
  static const String potassium = '56c36f66-da27-464a-952a-9e6631168f6d';

  // Scan trigger (write-only from app side)
  static const String scanTrigger = '56c36f67-da27-464a-952a-9e6631168f6d';

  static const List<String> allSoilUUIDs = [
    soilPh,
    soilMoisture,
    soilTemp,
    ecLevel,
    nitrogen,
    phosphorus,
    potassium,
  ];
}

// ── Soil scan result ──────────────────────────────────────────────────────────
class BleSoilReading {
  final double soilPh;
  final double moisture;
  final double soilTemp;
  final double ecLevel;
  final int nitrogen;
  final int phosphorus;
  final int potassium;

  const BleSoilReading({
    required this.soilPh,
    required this.moisture,
    required this.soilTemp,
    required this.ecLevel,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
  });
}

// ── Pi diagnostics result ─────────────────────────────────────────────────────
class BleDiagnostics {
  final double cpuUsage;
  final double cpuTemp;
  final int battery;

  const BleDiagnostics({
    required this.cpuUsage,
    required this.cpuTemp,
    required this.battery,
  });
}

// ── BLE Service ───────────────────────────────────────────────────────────────
class BleService {
  static final BleService instance = BleService._();
  BleService._();

  BluetoothDevice? _device;
  final Map<String, BluetoothCharacteristic> _chars = {};
  final _connectionController = StreamController<bool>.broadcast();

  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  /// Broadcast stream of connected (true) / disconnected (false) events.
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _device != null;
  String get deviceName => _device?.platformName ?? '';

  // ── Scan & Connect ──────────────────────────────────────────────────────────

  /// Scans for a device advertising the Strata service UUID.
  /// Calls [onDeviceFound] for each candidate device found.
  /// Returns when [stopScan] is called or after [timeout].
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    required void Function(ScanResult result) onDeviceFound,
  }) async {
    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(StrataUUIDs.service)],
        timeout: timeout,
      );

      FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          onDeviceFound(r);
        }
      });
    } catch (e) {
      debugPrint('[BleService] startScan error: $e');
      rethrow;
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connects to a specific [device], discovers services, and caches
  /// all Strata characteristics.
  Future<void> connectTo(BluetoothDevice device) async {
    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
      _device = device;

      // Listen for disconnection events
      _connStateSub?.cancel();
      _connStateSub =
          device.connectionState.listen((state) {
            if (state == BluetoothConnectionState.disconnected) {
              _chars.clear();
              _device = null;
              _connectionController.add(false);
              debugPrint('[BleService] Device disconnected.');
            }
          });

      await _discoverAndCache(device);
      _connectionController.add(true);
      debugPrint('[BleService] Connected to ${device.platformName}');
    } catch (e) {
      _device = null;
      debugPrint('[BleService] connectTo error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      await _device?.disconnect();
    } catch (e) {
      debugPrint('[BleService] disconnect error: $e');
    } finally {
      _chars.clear();
      _device = null;
      _connStateSub?.cancel();
      _connectionController.add(false);
    }
  }

  // ── Internal characteristic discovery ─────────────────────────────────────

  Future<void> _discoverAndCache(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == Guid(StrataUUIDs.service)) {
        for (final char in service.characteristics) {
          _chars[char.uuid.toString().toLowerCase()] = char;
        }
        debugPrint('[BleService] Cached ${_chars.length} characteristics.');
        return;
      }
    }
    throw Exception('Strata service not found on device.');
  }

  BluetoothCharacteristic? _char(String uuid) =>
      _chars[uuid.toLowerCase()];

  // ── Soil Scan ──────────────────────────────────────────────────────────────

  /// Writes 0x01 to the scan trigger, waits for NOTIFY on all 7 soil
  /// characteristics, then returns a [BleSoilReading].
  /// Throws a [TimeoutException] if not all values arrive within [timeout].
  Future<BleSoilReading> readSoilScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _assertConnected();

    final Map<String, String> values = {};
    final List<StreamSubscription> subs = [];
    final completer = Completer<BleSoilReading>();

    // Subscribe to NOTIFY on all soil characteristics
    for (final uuid in StrataUUIDs.allSoilUUIDs) {
      final char = _char(uuid);
      if (char == null) {
        throw Exception('Characteristic $uuid not found on device.');
      }
      await char.setNotifyValue(true);

      final sub = char.onValueReceived.listen((data) {
        if (completer.isCompleted) return;
        values[uuid] = String.fromCharCodes(data);
        debugPrint('[BleService] $uuid → ${values[uuid]}');

        if (values.length == StrataUUIDs.allSoilUUIDs.length) {
          completer.complete(_parseReading(values));
        }
      });
      subs.add(sub);
    }

    // Trigger the scan on the Pi
    final triggerChar = _char(StrataUUIDs.scanTrigger);
    if (triggerChar == null) {
      throw Exception('Scan trigger characteristic not found.');
    }
    await triggerChar.write([0x01], withoutResponse: false);
    debugPrint('[BleService] Scan trigger sent.');

    // Wait with timeout
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      debugPrint('[BleService] Soil scan timed out.');
      rethrow;
    } finally {
      for (final sub in subs) {
        await sub.cancel();
      }
      // Disable notifications
      for (final uuid in StrataUUIDs.allSoilUUIDs) {
        await _char(uuid)?.setNotifyValue(false).catchError((_) => false);
      }
    }
  }

  BleSoilReading _parseReading(Map<String, String> raw) {
    double parseD(String uuid, [double fallback = 0.0]) =>
        double.tryParse(raw[uuid] ?? '') ?? fallback;
    int parseI(String uuid, [int fallback = 0]) =>
        int.tryParse(raw[uuid] ?? '') ?? fallback;

    return BleSoilReading(
      soilPh: parseD(StrataUUIDs.soilPh),
      moisture: parseD(StrataUUIDs.soilMoisture),
      soilTemp: parseD(StrataUUIDs.soilTemp),
      ecLevel: parseD(StrataUUIDs.ecLevel),
      nitrogen: parseI(StrataUUIDs.nitrogen),
      phosphorus: parseI(StrataUUIDs.phosphorus),
      potassium: parseI(StrataUUIDs.potassium),
    );
  }

  // ── Pi Diagnostics ─────────────────────────────────────────────────────────

  Future<BleDiagnostics> readDiagnostics() async {
    _assertConnected();

    Future<String> readChar(String uuid) async {
      final char = _char(uuid);
      if (char == null) return 'Err';
      try {
        final bytes = await char.read();
        return String.fromCharCodes(bytes);
      } catch (e) {
        debugPrint('[BleService] readDiagnostics $uuid error: $e');
        return 'Err';
      }
    }

    final cpuRaw = await readChar(StrataUUIDs.cpuUsage);
    final tempRaw = await readChar(StrataUUIDs.cpuTemp);
    final battRaw = await readChar(StrataUUIDs.battery);

    return BleDiagnostics(
      cpuUsage: double.tryParse(cpuRaw) ?? 0.0,
      cpuTemp: double.tryParse(tempRaw) ?? 0.0,
      battery: int.tryParse(battRaw) ?? 0,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _assertConnected() {
    if (_device == null) {
      throw StateError('BleService: not connected to any device.');
    }
  }

  void dispose() {
    _connStateSub?.cancel();
    _connectionController.close();
  }
}
