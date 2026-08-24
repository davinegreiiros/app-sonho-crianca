import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

/// Único ponto de acesso ao banco SQLite físico do app (spec
/// 020-persistencia-local). `ToyLocalService`/`RentalLocalService` recebem
/// esta classe no construtor — nenhum outro lugar do app abre um banco.
///
/// Usa as funções globais `openDatabase`/`getDatabasesPath` do pacote
/// `sqflite`, que delegam pro `databaseFactory` ativo — o real em produção,
/// `databaseFactoryFfi` (`sqflite_common_ffi`) em teste, setado uma vez no
/// `setUpAll` de cada arquivo de teste que precisa de banco real.
///
/// `BusinessSettings` não usa isto: continua em `SharedPreferences`
/// (`BusinessSettingsLocalService`), fora de escopo desta spec.
class AppDatabase {
  /// [path] existe só pra teste — deixa passar `inMemoryDatabasePath`
  /// (`sqflite`) pra um banco isolado por instância, sem tocar disco. Em
  /// produção nunca é passado: usa o caminho real via `getDatabasesPath()`.
  AppDatabase({String? path}) : _path = path;

  static const _fileName = 'sonho_de_crianca.db';
  static const _version = 1;

  final String? _path;
  Database? _database;

  /// Abre o banco na primeira chamada e reusa a mesma instância depois —
  /// mesmo `Future` cacheado, sem reabrir a cada leitura/escrita.
  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path = _path ?? join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE toys (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        qty INTEGER NOT NULL,
        block_min INTEGER NOT NULL,
        price REAL NOT NULL,
        ink TEXT NOT NULL,
        image_key TEXT NOT NULL,
        category TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE rentals (
        id TEXT PRIMARY KEY,
        toy_id TEXT NOT NULL,
        child_name TEXT NOT NULL,
        guardian_name TEXT NOT NULL,
        guardian_phone TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        duration_min INTEGER,
        rate_per_minute REAL,
        price REAL NOT NULL,
        status TEXT NOT NULL,
        ended_at INTEGER,
        payment_method TEXT
      )
    ''');
  }

  /// Só usado em teste (fecha o banco entre casos quando necessário) —
  /// em produção o app nunca fecha o banco explicitamente.
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
