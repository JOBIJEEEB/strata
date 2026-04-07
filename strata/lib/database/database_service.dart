import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:csv/csv.dart';

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
  final String cropRecommendation;

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
    this.cropRecommendation = 'Tomato, Onion, Maize, or Pechay',
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
      cropRecommendation: map['crop_recommendation'] ?? 'Tomato, Onion, Maize, or Pechay',
    );
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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Bumped for plot_name and soil_type inclusion
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        crop_recommendation TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Applying progressive DB migration patches safely
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE scans ADD COLUMN nitrogen INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE scans ADD COLUMN phosphorus INTEGER DEFAULT 0");
      await db.execute("ALTER TABLE scans ADD COLUMN potassium INTEGER DEFAULT 0");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE scans ADD COLUMN health_status TEXT DEFAULT 'Healthy'");
    }
    if (oldVersion < 5) {
      await db.execute("ALTER TABLE scans ADD COLUMN plot_name TEXT DEFAULT 'Unnamed Plot'");
      await db.execute("ALTER TABLE scans ADD COLUMN soil_type TEXT DEFAULT 'Unknown'");
    }
  }

  Future<int> insertScan(ScanRecord scan) async {
    final db = await instance.database;
    return await db.insert('scans', scan.toMap());
  }

  Future<int> updateScan(ScanRecord scan) async {
    final db = await instance.database;
    return await db.update('scans', scan.toMap(), where: 'id = ?', whereArgs: [scan.id]);
  }

  Future<int> deleteScan(int id) async {
    final db = await instance.database;
    return await db.delete('scans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScanRecord>> fetchScans() async {
    final db = await instance.database;
    final result = await db.query('scans', orderBy: 'timestamp DESC');
    return result.map((map) => ScanRecord.fromMap(map)).toList();
  }

  Future<void> wipeDatabase() async {
    final db = await instance.database;
    await db.delete('scans');
  }

  Future<String> exportToCsv() async {
    final scans = await fetchScans();
    List<List<dynamic>> rows = [];
    rows.add(["ID", "Plot Name", "Soil Type", "Timestamp", "pH", "Moisture (%)", "Temperature (C)", "EC (mS/cm)", "Nitrogen (N)", "Phosphorus (P)", "Potassium (K)", "Status", "Recommendation"]);
    for (var scan in scans) {
      rows.add([
        scan.id, scan.plotName, scan.soilType, scan.timestamp, scan.soilPh, scan.moisture, scan.temperature, scan.ecLevel, scan.nitrogen, scan.phosphorus, scan.potassium, scan.healthStatus, scan.cropRecommendation
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }
}
