import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'data/repositories/business_settings_repository.dart';
import 'data/repositories/rental_repository.dart';
import 'data/repositories/toy_repository.dart';
import 'data/services/app_database.dart';
import 'data/services/rental_local_service.dart';
import 'data/services/toy_local_service.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/features/app_shell/view_models/app_shell_cubit.dart';
import 'ui/features/business_settings/view_models/business_settings_cubit.dart';
import 'ui/features/catalog/view_models/toy_catalog_cubit.dart';
import 'ui/features/home/view_models/home_cubit.dart';
import 'ui/features/rental/view_models/active_rentals_cubit.dart';
import 'ui/features/rental/view_models/new_rental_cubit.dart';
import 'ui/features/report/view_models/report_cubit.dart';

/// Bootstrap assíncrono (spec 020-persistencia-local): abre o banco local e
/// espera os 3 `load()` resolverem **antes** do primeiro frame — sem isso o
/// boot mostraria Catálogo/Painel vazios por um instante até os dados
/// persistidos chegarem (`WidgetsFlutterBinding.ensureInitialized()` é
/// exigido pelo `sqflite` antes de abrir um banco fora da árvore de
/// widgets).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDatabase = AppDatabase();
  final businessSettingsRepository = BusinessSettingsRepository();
  final toyRepository = ToyRepository(localService: ToyLocalService(appDatabase));
  final rentalRepository = RentalRepository(localService: RentalLocalService(appDatabase));
  await Future.wait([
    businessSettingsRepository.load(),
    toyRepository.load(),
    rentalRepository.load(),
  ]);

  runApp(SonhoDeCriancaApp(
    businessSettingsRepository: businessSettingsRepository,
    toyRepository: toyRepository,
    rentalRepository: rentalRepository,
  ));
}

class SonhoDeCriancaApp extends StatelessWidget {
  /// Os 3 Repositories são opcionais só pra teste — `tester.pumpWidget(const
  /// SonhoDeCriancaApp())` continua funcionando sem banco/SharedPreferences
  /// real (cada um cai no seu próprio construtor default, síncrono, sem
  /// `_localService`). Em produção, `main()` sempre passa os 3 já
  /// carregados.
  const SonhoDeCriancaApp({
    super.key,
    this.businessSettingsRepository,
    this.toyRepository,
    this.rentalRepository,
  });

  final BusinessSettingsRepository? businessSettingsRepository;
  final ToyRepository? toyRepository;
  final RentalRepository? rentalRepository;

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
        ChangeNotifierProvider<BusinessSettingsRepository>(
          create: (_) => businessSettingsRepository ?? BusinessSettingsRepository(),
        ),
        ChangeNotifierProvider<ToyRepository>(
          create: (_) => toyRepository ?? ToyRepository(),
        ),
        ChangeNotifierProvider<RentalRepository>(
          create: (_) => rentalRepository ?? RentalRepository(),
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
                create: (context) => ReportCubit(context.read<RentalRepository>(), context.read<ToyRepository>()),
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
            ],
            child: MaterialApp(
              title: 'Sonho de Criança',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: const HomeShell(),
            ),
          );
        },
      ),
    );
  }
}
