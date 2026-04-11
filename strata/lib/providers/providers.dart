import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strata/database/database_service.dart';

// --- Theme Mode State ---
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void setDarkMode(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

// --- BLE Connection State ---
class BleConnectionState {
  final bool isConnected;
  final String deviceId;

  BleConnectionState({this.isConnected = false, this.deviceId = ''});
}

class BleConnectionNotifier extends StateNotifier<BleConnectionState> {
  BleConnectionNotifier()
    : super(BleConnectionState(isConnected: false, deviceId: ''));

  void connectToPi() {
    state = BleConnectionState(isConnected: true, deviceId: 'strata-rpc-pi');
  }

  void disconnect() {
    state = BleConnectionState(isConnected: false, deviceId: '');
  }

  void toggleConnection() {
    if (state.isConnected) {
      disconnect();
    } else {
      connectToPi();
    }
  }
}

final bleConnectionProvider =
    StateNotifierProvider<BleConnectionNotifier, BleConnectionState>((ref) {
      return BleConnectionNotifier();
    });

// --- Soil Evaluation & Mocking Provider ---
class SoilMockGenerator {
  static ScanRecord generateMockScan({
    required String plotName,
    required String soilType,
    int? overrideId,
  }) {
    final rand = Random();

    // Easter Egg for testing: if plotName is "unhealthy", force poor soil stats
    bool isPoor = rand.nextInt(100) < 40;
    if (plotName.toLowerCase() == 'unhealthy') {
      isPoor = true;
    }

    final phLevel =
        isPoor
            ? (rand.nextDouble() * 2 + 4.0)
            : (rand.nextDouble() * 1.5 + 6.0);
    final n = isPoor ? rand.nextInt(35) : 50 + rand.nextInt(50);
    final p = isPoor ? rand.nextInt(25) : 30 + rand.nextInt(40);
    final k = isPoor ? rand.nextInt(20) : 40 + rand.nextInt(40);

    // Evaluate based on realistic thresholds
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
      cropRecommendation:
          isHealthy
              ? 'Tomato, Maize, Onion, Pechay, Radish, Cabbage, Pepper, Beans'
              : 'Spread organic compost, Apply bio-fertilizers, Use mulching techniques, Practice crop rotation, Add agricultural lime, Integrate green manure, Deep soil aeration, Balanced organic NPK application',
    );
  }
}
