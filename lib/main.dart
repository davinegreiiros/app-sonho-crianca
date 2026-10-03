import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/business_settings_repository.dart';
import 'data/repositories/rental_repository.dart';
import 'data/repositories/toy_repository.dart';
import 'data/repositories/turno_repository.dart';
import 'data/services/api_client.dart';
import 'data/services/app_database.dart';
import 'data/services/business_settings_remote_service.dart';
import 'data/services/rental_remote_service.dart';
import 'data/services/toy_remote_service.dart';
import 'data/services/turno_local_service.dart';
import 'domain/text_sharer.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/features/admin_panel/view_models/admin_panel_cubit.dart';
import 'ui/features/app_shell/view_models/app_shell_cubit.dart';
import 'ui/features/business_settings/view_models/business_settings_cubit.dart';
import 'ui/features/catalog/view_models/toy_catalog_cubit.dart';
import 'ui/features/home/view_models/home_cubit.dart';
import 'ui/features/posto/view_models/posto_session_cubit.dart';
import 'ui/features/posto/view_models/posto_session_state.dart';
import 'ui/features/posto/views/monitor_posto_view.dart';
import 'ui/features/posto/views/open_posto_view.dart';
import 'ui/features/rental/view_models/active_rentals_cubit.dart';
import 'ui/features/rental/view_models/new_rental_cubit.dart';
import 'ui/features/report/view_models/report_cubit.dart';

/// Bootstrap assíncrono (spec 020-persistencia-local): abre o banco local e
/// espera os 4 `load()` resolverem **antes** do primeiro frame — sem isso o
/// boot mostraria Catálogo/Painel vazios por um instante até os dados
/// persistidos chegarem (`WidgetsFlutterBinding.ensureInitialized()` é
/// exigido pelo `sqflite` antes de abrir um banco fora da árvore de
/// widgets).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDatabase = AppDatabase();
  final authRepository = AuthRepository();
  final businessSettingsRepository = BusinessSettingsRepository(
    service: BusinessSettingsRemoteService(ApiClient()),
    authRepository: authRepository,
  );
  final toyRepository = ToyRepository(
    service: ToyRemoteService(ApiClient()),
    authRepository: authRepository,
  );
  final rentalRepository = RentalRepository(
    service: RentalRemoteService(ApiClient()),
    authRepository: authRepository,
  );
  final turnoRepository = TurnoRepository(localService: TurnoLocalService(appDatabase));
  await Future.wait([
    // Só lê sessão salva localmente (sem rede) — `BusinessSettings` busca
    // no backend sob demanda, quando a tela de Configurações abre de
    // verdade (spec 024-sync-backend-fundacao), não aqui no boot.
    authRepository.restoreSession(),
    turnoRepository.load(),
  ]);
  // Catálogo + locações em segundo plano (specs 025/026): são chamadas de
  // rede, não podem travar o boot (cenário 4/5 — sem internet, não pode
  // travar nem ficar em branco). O app nasce com o catálogo/histórico
  // seed/último bom e atualiza sozinho (`ChangeNotifier`) assim que
  // `load()` resolver. Uma sessão só, a do administrador (spec 027): sem
  // ela os `load()` não chamam nada, e cada login novo dispara a busca de
  // novo — o administrador que acabou de entrar já vê o dado do servidor.
  void loadRemoteData() => unawaited(Future.wait([toyRepository.load(), rentalRepository.load()]));
  var lastToken = authRepository.token;
  authRepository.addListener(() {
    final token = authRepository.token;
    if (token != null && token != lastToken) loadRemoteData();
    lastToken = token;
  });
  loadRemoteData();

  runApp(SonhoDeCriancaApp(
    authRepository: authRepository,
    businessSettingsRepository: businessSettingsRepository,
    toyRepository: toyRepository,
    rentalRepository: rentalRepository,
    turnoRepository: turnoRepository,
  ));
}

class SonhoDeCriancaApp extends StatelessWidget {
  /// Os 4 Repositories são opcionais só pra teste — `tester.pumpWidget(const
  /// SonhoDeCriancaApp())` continua funcionando sem banco/SharedPreferences
  /// real (cada um cai no seu próprio construtor default, síncrono, sem
  /// `_localService`). Em produção, `main()` sempre passa os 4 já
  /// carregados.
  ///
  /// [startInPostoAdminMode] (spec 023-posto-monitor-painel): só pra
  /// teste — nasce direto em modo administrador (`HomeShell`), pulando a
  /// tela de escolher posto (3a). Produção nunca passa isto (o app
  /// sempre começa em 3a); ver `plan.md`/"Riscos" da spec.
  const SonhoDeCriancaApp({
    super.key,
    this.authRepository,
    this.businessSettingsRepository,
    this.toyRepository,
    this.rentalRepository,
    this.turnoRepository,
    this.textSharer,
    this.startInPostoAdminMode = false,
  });

  final AuthRepository? authRepository;
  final BusinessSettingsRepository? businessSettingsRepository;
  final ToyRepository? toyRepository;
  final RentalRepository? rentalRepository;
  final TurnoRepository? turnoRepository;

  /// Saída do "Enviar resumo" do relatório (spec 028). `null` = folha de
  /// compartilhamento real; teste passa um fake.
  final TextSharer? textSharer;
  final bool startInPostoAdminMode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Single shared instances (specs 011/012-migracao-*): AppState (old
        // world, still read by widgets not migrated yet) and the matching
        // Cubit (new world) must see the exact same Repository — never
        // construct a second one of either.
        // ChangeNotifierProvider (not plain Provider): both Repositories are
        // themselves ChangeNotifiers and provider asserts against exposing a
        // Listenable through a provider type that won't propagate updates.
        ChangeNotifierProvider<AuthRepository>(
          create: (_) => authRepository ?? AuthRepository(),
        ),
        ChangeNotifierProvider<BusinessSettingsRepository>(
          create: (context) => businessSettingsRepository ??
              BusinessSettingsRepository(
                service: BusinessSettingsRemoteService(ApiClient()),
                authRepository: context.read<AuthRepository>(),
              ),
        ),
        ChangeNotifierProvider<ToyRepository>(
          create: (context) => toyRepository ??
              ToyRepository(
                service: ToyRemoteService(ApiClient()),
                authRepository: context.read<AuthRepository>(),
              ),
        ),
        ChangeNotifierProvider<RentalRepository>(
          create: (context) => rentalRepository ??
              RentalRepository(
                service: RentalRemoteService(ApiClient()),
                authRepository: context.read<AuthRepository>(),
              ),
        ),
        ChangeNotifierProvider<TurnoRepository>(
          create: (_) => turnoRepository ?? TurnoRepository(),
        ),
        ChangeNotifierProvider<AppState>(
          create: (context) => AppState(
            businessSettingsRepository: context.read<BusinessSettingsRepository>(),
            toyRepository: context.read<ToyRepository>(),
            rentalRepository: context.read<RentalRepository>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<AppShellCubit>(
                create: (context) => AppShellCubit(),
              ),
              BlocProvider<BusinessSettingsCubit>(
                create: (context) => BusinessSettingsCubit(context.read<BusinessSettingsRepository>()),
              ),
              BlocProvider<ToyCatalogCubit>(
                create: (context) => ToyCatalogCubit(context.read<ToyRepository>(), context.read<RentalRepository>()),
              ),
              BlocProvider<ReportCubit>(
                create: (context) => ReportCubit(
                  context.read<RentalRepository>(),
                  context.read<ToyRepository>(),
                  turnoRepository: context.read<TurnoRepository>(),
                  textSharer: textSharer,
                ),
              ),
              BlocProvider<NewRentalCubit>(
                create: (context) => NewRentalCubit(context.read<ToyRepository>(), context.read<RentalRepository>()),
              ),
              BlocProvider<ActiveRentalsCubit>(
                create: (context) => ActiveRentalsCubit(context.read<ToyRepository>(), context.read<RentalRepository>()),
              ),
              BlocProvider<HomeCubit>(
                create: (context) => HomeCubit(context.read<ToyRepository>(), context.read<RentalRepository>()),
              ),
              BlocProvider<PostoSessionCubit>(
                create: (context) => PostoSessionCubit(
                  context.read<ToyRepository>(),
                  context.read<RentalRepository>(),
                  context.read<TurnoRepository>(),
                  startInAdminMode: startInPostoAdminMode,
                ),
              ),
              BlocProvider<AdminPanelCubit>(
                create: (context) => AdminPanelCubit(
                  context.read<RentalRepository>(),
                  context.read<ToyRepository>(),
                  context.read<TurnoRepository>(),
                ),
              ),
            ],
            child: MaterialApp(
              title: 'Sonho de Criança',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              // Sessão de posto (spec 023-posto-monitor-painel): a raiz da
              // navegação alterna entre 3a (nenhum posto), 3b (dentro de um
              // posto) e o `HomeShell` de sempre (administrador) — nenhuma
              // rota nomeada nova, mesmo racional de `MaterialPageRoute`
              // que `openBusinessSettingsScreen`/`openAdminPanelScreen` já
              // usam por cima desta árvore.
              home: BlocBuilder<PostoSessionCubit, PostoSessionState>(
                builder: (context, state) => switch (state.mode) {
                  PostoMode.none => const OpenPostoView(),
                  PostoMode.monitor => const MonitorPostoView(),
                  PostoMode.admin => const HomeShell(),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
