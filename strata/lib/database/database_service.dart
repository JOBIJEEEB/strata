import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class ScanRecord {
  final int? id;
  final String plotName;
  final String soilType;
  final String timestamp;
  final double soilPh;
  final double moisture;
  final double temperature;
  final double ecLevel;
  final int nitrogen;
  final int phosphorus;
  final int potassium;
  final String healthStatus;
  final String cropRecommendation; // JSON string representing Top 5 crops
  final List<String> mlDeficiencies;
  final List<String> mlFlags;
  final String rehabRecommendations; // JSON-encoded list of rehab keys
  final String mlSubtext;            // Optional subtitle for the primary ml_flag

  ScanRecord({
    this.id,
    required this.plotName,
    required this.soilType,
    required this.timestamp,
    required this.soilPh,
    required this.moisture,
    required this.temperature,
    required this.ecLevel,
    this.nitrogen = 0,
    this.phosphorus = 0,
    this.potassium = 0,
    this.healthStatus = 'Healthy',
    this.cropRecommendation = '[]',
    this.mlDeficiencies = const [],
    this.mlFlags = const [],
    this.rehabRecommendations = '',
    this.mlSubtext = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plot_name': plotName,
      'soil_type': soilType,
      'timestamp': timestamp,
      'soil_ph': soilPh,
      'moisture': moisture,
      'temperature': temperature,
      'ec_level': ecLevel,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'health_status': healthStatus,
      'crop_recommendation': cropRecommendation,
      'ml_deficiencies': jsonEncode(mlDeficiencies),
      'ml_flags': jsonEncode(mlFlags),
      'rehab_recommendations': rehabRecommendations,
      'ml_subtext': mlSubtext,
    };
  }

  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      id: map['id'],
      plotName: map['plot_name'] ?? 'Unnamed Plot',
      soilType: map['soil_type'] ?? 'Unknown',
      timestamp: map['timestamp'],
      soilPh: map['soil_ph']?.toDouble() ?? 0.0,
      moisture: map['moisture']?.toDouble() ?? 0.0,
      temperature: map['temperature']?.toDouble() ?? 0.0,
      ecLevel: map['ec_level']?.toDouble() ?? 0.0,
      nitrogen: map['nitrogen']?.toInt() ?? 0,
      phosphorus: map['phosphorus']?.toInt() ?? 0,
      potassium: map['potassium']?.toInt() ?? 0,
      healthStatus: map['health_status'] ?? 'Healthy',
      cropRecommendation: map['crop_recommendation'] ?? '[]',
      mlDeficiencies: _parseStringList(map['ml_deficiencies']),
      mlFlags: _parseStringList(map['ml_flags']),
      rehabRecommendations: map['rehab_recommendations'] ?? '',
      mlSubtext: map['ml_subtext'] as String? ?? '',
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
      return [];
    } catch (_) {
      return [];
    }
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('strata_scans.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 7,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      debugPrint('Error initializing DB: $e');
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plot_name TEXT,
        soil_type TEXT,
        timestamp TEXT,
        soil_ph REAL,
        moisture REAL,
        temperature REAL,
        ec_level REAL,
        nitrogen INTEGER,
        phosphorus INTEGER,
        potassium INTEGER,
        health_status TEXT,
        crop_recommendation TEXT,
        ml_deficiencies TEXT,
        ml_flags TEXT,
        rehab_recommendations TEXT,
        ml_subtext TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE scans ADD COLUMN nitrogen INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE scans ADD COLUMN phosphorus INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE scans ADD COLUMN potassium INTEGER DEFAULT 0",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE scans ADD COLUMN health_status TEXT DEFAULT 'Healthy'",
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE scans ADD COLUMN plot_name TEXT DEFAULT 'Unnamed Plot'",
      );
      await db.execute(
        "ALTER TABLE scans ADD COLUMN soil_type TEXT DEFAULT 'Unknown'",
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE scans ADD COLUMN ml_deficiencies TEXT DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE scans ADD COLUMN ml_flags TEXT DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE scans ADD COLUMN rehab_recommendations TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE scans ADD COLUMN ml_subtext TEXT DEFAULT ''",
      );
    }
  }

  Future<int> insertScan(ScanRecord scan) async {
    try {
      final db = await instance.database;
      return await db.insert('scans', scan.toMap());
    } catch (e) {
      debugPrint('Error inserting scan: $e');
      return -1;
    }
  }

  Future<int> updateScan(ScanRecord scan) async {
    try {
      final db = await instance.database;
      return await db.update(
        'scans',
        scan.toMap(),
        where: 'id = ?',
        whereArgs: [scan.id],
      );
    } catch (e) {
      debugPrint('Error updating scan: $e');
      return -1;
    }
  }

  Future<int> deleteScan(int id) async {
    try {
      final db = await instance.database;
      return await db.delete('scans', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting scan: $e');
      return -1;
    }
  }

  Future<List<ScanRecord>> fetchScans() async {
    try {
      final db = await instance.database;
      final result = await db.query('scans', orderBy: 'timestamp DESC');
      return result.map((map) => ScanRecord.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error fetching scans: $e');
      return [];
    }
  }

  Future<bool> wipeDatabase() async {
    try {
      final db = await instance.database;
      await db.delete('scans');
      return true;
    } catch (e) {
      debugPrint('Error wiping database: $e');
      return false;
    }
  }

  Future<String> exportToCsv() async {
    final scans = await fetchScans();
    return await exportScansToCsv(scans);
  }

  Future<String> exportScansToCsv(List<ScanRecord> scans) async {
    try {
      if (scans.isEmpty) return '';

      List<List<dynamic>> rows = [];
      rows.add([
        "ID",
        "Plot Name",
        "Soil Type",
        "Timestamp",
        "pH",
        "Moisture (%)",
        "Temperature (C)",
        "EC (µS/cm)",
        "Nitrogen (N)",
        "Phosphorus (P)",
        "Potassium (K)",
        "Status",
        "Top Crops",
        "Deficiencies",
        "Physical Flags",
        "Rehab Methods",
      ]);
      for (var scan in scans) {
        rows.add([
          scan.id,
          scan.plotName,
          scan.soilType,
          scan.timestamp,
          scan.soilPh,
          scan.moisture,
          scan.temperature,
          scan.ecLevel,
          scan.nitrogen,
          scan.phosphorus,
          scan.potassium,
          scan.healthStatus,
          scan.cropRecommendation,
          scan.mlDeficiencies.join('; '),
          scan.mlFlags.join('; '),
          scan.rehabRecommendations,
        ]);
      }
      return const ListToCsvConverter().convert(rows);
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      return '';
    }
  }
}
