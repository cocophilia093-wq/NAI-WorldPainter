import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:nai_huishi/core/constants/app_constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE generation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT UNIQUE NOT NULL,
        model TEXT NOT NULL,
        prompt TEXT NOT NULL,
        negative_prompt TEXT,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        scale REAL NOT NULL,
        cfg_rescale REAL NOT NULL,
        sampler TEXT NOT NULL,
        noise_schedule TEXT NOT NULL,
        seed INTEGER,
        characters TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        image_path TEXT,
        image_url TEXT,
        error_message TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE presets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        model TEXT NOT NULL,
        prompt TEXT NOT NULL,
        negative_prompt TEXT,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        scale REAL NOT NULL,
        cfg_rescale REAL NOT NULL,
        sampler TEXT NOT NULL,
        noise_schedule TEXT NOT NULL,
        seed INTEGER,
        characters TEXT,
        is_builtin INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE prompt_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        content TEXT NOT NULL,
        tags TEXT,
        use_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 索引
    await db.execute('CREATE INDEX idx_history_status ON generation_history(status)');
    await db.execute('CREATE INDEX idx_history_created ON generation_history(created_at)');
    await db.execute('CREATE INDEX idx_history_favorite ON generation_history(is_favorite)');
    await db.execute('CREATE INDEX idx_presets_category ON presets(category)');
    await db.execute('CREATE INDEX idx_templates_category ON prompt_templates(category)');

    await _createLlmTables(db);
  }

  Future<void> _createLlmTables(Database db) async {
    await db.execute('''
      CREATE TABLE llm_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE llm_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES llm_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_llm_messages_session ON llm_messages(session_id, created_at)');
    await db.execute('CREATE INDEX idx_llm_sessions_updated ON llm_sessions(updated_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE generation_history ADD COLUMN seed INTEGER');
      await db.execute('ALTER TABLE presets ADD COLUMN seed INTEGER');
    }
    if (oldVersion < 3) {
      // v3: 移除 batch_id 列和 batch_tasks 表（SQLite 不支持 DROP COLUMN，保留旧列忽略即可）
      await db.execute('DROP TABLE IF EXISTS batch_tasks');
    }
    if (oldVersion < 4) {
      await _createLlmTables(db);
    }
  }
}
