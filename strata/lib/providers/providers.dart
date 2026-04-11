import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/services/ble_service.dart';

// ── Theme Mode ────────────────────────────────────────────────────────────────
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setDarkMode(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// ── BLE Service singleton provider ───────────────────────────────────────────
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService.instance;
  ref.onDispose(service.dispose);
  return service;
});

// ── BLE Connection State ──────────────────────────────────────────────────────
class BleConnectionState {
  final bool isConnected;
  final String deviceName;

  const BleConnectionState({
    this.isConnected = false,
    this.deviceName = '',
  });
}

class BleConnectionNotifier extends StateNotifier<BleConnectionState> {
  final BleService _ble;

  BleConnectionNotifier(this._ble)
      : super(const BleConnectionState()) {
    // Keep state in sync with real BLE events from BleService
    _ble.connectionStream.listen((connected) {
      state = BleConnectionState(
        isConnected: connected,
        deviceName: connected ? _ble.deviceName : '',
      );
    });
  }

  /// Called by PairingScreen after BleService.connectTo() succeeds.
  void onConnected(String deviceName) {
    state = BleConnectionState(isConnected: true, deviceName: deviceName);
  }

  void onDisconnected() {
    state = const BleConnectionState();
  }
}

final bleConnectionProvider =
    StateNotifierProvider<BleConnectionNotifier, BleConnectionState>((ref) {
  final ble = ref.watch(bleServiceProvider);
  return BleConnectionNotifier(ble);
});

// ── Soil Mock Generator (used only when kBleDebugMode = true) ────────────────
class SoilMockGenerator {
  static ScanRecord generateMockScan({
    required String plotName,
    required String soilType,
    int? overrideId,
  }) {
    final rand = Random();

    bool isPoor = rand.nextInt(100) < 40;
    if (plotName.toLowerCase() == 'unhealthy') {
      isPoor = true;
    }

    final phLevel =
        isPoor ? (rand.nextDouble() * 2 + 4.0) : (rand.nextDouble() * 1.5 + 6.0);
    final n = isPoor ? rand.nextInt(35) : 50 + rand.nextInt(50);
    final p = isPoor ? rand.nextInt(25) : 30 + rand.nextInt(40);
    final k = isPoor ? rand.nextInt(20) : 40 + rand.nextInt(40);

    final isHealthy =
        phLevel >= 5.8 && phLevel <= 7.5 && n >= 40 && p >= 25 && k >= 30;

    return ScanRecord(
      id: overrideId,
      plotName: plotName,
      soilType: soilType,
      timestamp: DateTime.now().toIso8601String(),
      soilPh: phLevel,
      moisture: 30 + rand.nextDouble() * 40,
      temperature: 20 + rand.nextDouble() * 10,
      ecLevel: rand.nextDouble() * 2,
      nitrogen: n,
      phosphorus: p,
      potassium: k,
      healthStatus: isHealthy ? 'Healthy' : 'Unhealthy',
      cropRecommendation: isHealthy
          ? 'Tomato, Maize, Onion, Pechay, Radish, Cabbage, Pepper, Beans'
          : 'Spread organic compost, Apply bio-fertilizers, Use mulching techniques, Practice crop rotation, Add agricultural lime, Integrate green manure, Deep soil aeration, Balanced organic NPK application',
    );
  }
}
