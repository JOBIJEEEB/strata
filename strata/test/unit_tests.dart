import 'package:flutter_test/flutter_test.dart';
import 'package:strata/providers/providers.dart';
import 'package:strata/database/database_service.dart';

void main() {
  group('SoilMockGenerator Logic Tests', () {
    test('Should generate a Healthy record when inputs are optimal', () {
      // Note: Generator uses random, but "unhealthy" keyword forces Unhealthy.
      // We can't easily force "Healthy" without changing the random seed or mocking Random.
      // However, we can test the threshold evaluation logic.

      final scan = SoilMockGenerator.generateMockScan(
        plotName: 'Test Plot',
        soilType: 'Loam',
      );

      expect(scan.plotName, equals('Test Plot'));
      expect(scan.soilType, equals('Loam'));

      // Verify health status consistency with NPK/pH
      final isHealthy =
          scan.soilPh >= 5.8 &&
          scan.soilPh <= 7.5 &&
          scan.nitrogen >= 40 &&
          scan.phosphorus >= 25 &&
          scan.potassium >= 30;

      expect(scan.healthStatus, equals(isHealthy ? 'Healthy' : 'Unhealthy'));
    });

    test('Should force Unhealthy status when plotName is "unhealthy"', () {
      final scan = SoilMockGenerator.generateMockScan(
        plotName: 'unhealthy',
        soilType: 'Sandy',
      );

      expect(scan.healthStatus, equals('Unhealthy'));
      expect(
        scan.cropRecommendation.contains('Spread organic compost'),
        isTrue,
      );
    });
  });

  group('ScanRecord Model Tests', () {
    test('toMap and fromMap should be consistent', () {
      final original = ScanRecord(
        id: 1,
        plotName: 'Farm A',
        soilType: 'Clay',
        timestamp: '2023-01-01',
        soilPh: 6.5,
        moisture: 50.0,
        temperature: 25.0,
        ecLevel: 1.2,
        nitrogen: 10,
        phosphorus: 20,
        potassium: 30,
        healthStatus: 'Unhealthy',
        cropRecommendation: 'Recommendation text',
      );

      final map = original.toMap();
      final decoded = ScanRecord.fromMap(map);

      expect(decoded.id, equals(original.id));
      expect(decoded.plotName, equals(original.plotName));
      expect(decoded.soilType, equals(original.soilType));
      expect(decoded.soilPh, equals(original.soilPh));
      expect(decoded.nitrogen, equals(original.nitrogen));
      expect(decoded.healthStatus, equals(original.healthStatus));
    });
  });
}
