import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/theme/components.dart';
import 'package:strata/providers/providers.dart';
import 'package:strata/services/ble_service.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

enum _ScanState { scanning, found, connecting, error }

class _PairingScreenState extends ConsumerState<PairingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  _ScanState _state = _ScanState.scanning;
  String _errorMessage = '';

  // All discovered Strata devices
  final List<ScanResult> _foundDevices = [];

  // The one device the user tapped to connect
  BluetoothDevice? _connectingDevice;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start BLE scan on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    BleService.instance.stopScan().catchError((_) {});
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _state = _ScanState.scanning;
      _foundDevices.clear();
      _errorMessage = '';
    });

    try {
      // Ensure Bluetooth is on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage =
              'Bluetooth is turned off. Please enable Bluetooth and retry.';
        });
        return;
      }

      await BleService.instance.startScan(
        timeout: const Duration(seconds: 15),
        onDeviceFound: (result) {
          if (!mounted) return;
          final alreadyAdded =
              _foundDevices.any((r) => r.device.remoteId == result.device.remoteId);
          if (!alreadyAdded) {
            setState(() {
              _foundDevices.add(result);
              _state = _ScanState.found;
            });
          }
        },
      );

      // Scan finished naturally (timeout) with no devices
      if (mounted && _foundDevices.isEmpty) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage =
              'No Strata device found nearby. Make sure the Pi is powered on and within Bluetooth range.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Scan failed: $e';
        });
      }
    }
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    await BleService.instance.stopScan();
    setState(() {
      _state = _ScanState.connecting;
      _connectingDevice = device;
    });

    try {
      await BleService.instance.connectTo(device);
      ref
          .read(bleConnectionProvider.notifier)
          .onConnected(device.platformName);

      if (mounted) context.goNamed('main');
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = 'Connection failed: $e';
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

              // ── Logo ──────────────────────────────────────────────────────
              Semantics(
                label: 'Strata Logo',
                child: Image.asset(
                  'assets/strata_logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.eco_rounded,
                        size: 48, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Connect Your Device',
                  style: textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Make sure your Strata sensor is powered on\nand within Bluetooth range.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 2),

              // ── Central animated icon ─────────────────────────────────────
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _iconColor(isDark),
                    border: Border.all(
                        color: _iconBorderColor(), width: 2),
                  ),
                  child: Icon(_iconData(), color: _iconForeground(), size: 56),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _statusLabel(),
                style: textTheme.bodySmall?.copyWith(
                  color: _statusLabelColor(),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2),

              // ── Device list (shown in 'found' state) ─────────────────────
              if (_state == _ScanState.found && _foundDevices.isNotEmpty)
                _buildDeviceList(textTheme, colorScheme, isDark),

              // ── Error / retry ─────────────────────────────────────────────
              if (_state == _ScanState.error) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall
                        ?.copyWith(color: Colors.redAccent, height: 1.5),
                  ),
                ),
                StrataButton(
                  label: 'Retry Scan',
                  icon: Icons.refresh_rounded,
                  onPressed: _startScan,
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDeviceList(
      TextTheme textTheme, ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('  Strata devices found:',
            style: textTheme.labelSmall?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...(_foundDevices.map((r) {
          final isConnecting = _state == _ScanState.connecting &&
              _connectingDevice?.remoteId == r.device.remoteId;
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : 'Strata Device (${r.device.remoteId.str.substring(0, 8)})';

          return GestureDetector(
            onTap: isConnecting ? null : () => _connectTo(r.device),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isConnecting
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? AppColors.cardDark : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bluetooth_rounded,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text('RSSI: ${r.rssi} dBm',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  if (isConnecting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary),
                ],
              ),
            ),
          );
        })),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  String _statusLabel() {
    return switch (_state) {
      _ScanState.scanning => 'Scanning for Strata device…',
      _ScanState.found =>
        '${_foundDevices.length} device${_foundDevices.length == 1 ? '' : 's'} found — tap to connect',
      _ScanState.connecting =>
        'Connecting to ${_connectingDevice?.platformName ?? 'device'}…',
      _ScanState.error => 'Scan failed',
    };
  }

  Color _iconColor(bool isDark) {
    if (_state == _ScanState.error) {
      return Colors.redAccent.withValues(alpha: isDark ? 0.15 : 0.08);
    }
    if (_state == _ScanState.found) {
      return AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.12);
    }
    return AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08);
  }

  Color _iconBorderColor() {
    if (_state == _ScanState.error) {
      return Colors.redAccent.withValues(alpha: 0.35);
    }
    return AppColors.primary.withValues(alpha: 0.35);
  }

  Color _iconForeground() {
    return _state == _ScanState.error ? Colors.redAccent : AppColors.primary;
  }

  IconData _iconData() {
    return switch (_state) {
      _ScanState.scanning || _ScanState.connecting =>
        Icons.bluetooth_searching_rounded,
      _ScanState.found => Icons.bluetooth_connected_rounded,
      _ScanState.error => Icons.bluetooth_disabled_rounded,
    };
  }

  Color _statusLabelColor() {
    return _state == _ScanState.error
        ? Colors.redAccent
        : AppColors.primary;
  }
}
