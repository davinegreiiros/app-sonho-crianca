import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'data/repositories/business_settings_repository.dart';
import 'data/repositories/rental_repository.dart';
import 'data/repositories/toy_repository.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/features/business_settings/view_models/business_settings_cubit.dart';
import 'ui/features/catalog/view_models/toy_catalog_cubit.dart';
import 'ui/features/report/view_models/report_cubit.dart';

void main() {
  runApp(const SonhoDeCriancaApp());
}

class SonhoDeCriancaApp extends StatelessWidget {
  const SonhoDeCriancaApp({super.key});

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
          create: (_) => BusinessSettingsRepository(),
        ),
        ChangeNotifierProvider<ToyRepository>(
          create: (_) => ToyRepository(),
        ),
        ChangeNotifierProvider<RentalRepository>(
          create: (_) => RentalRepository(),
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
              BlocProvider<BusinessSettingsCubit>(
                create: (context) => BusinessSettingsCubit(context.read<BusinessSettingsRepository>()),
              ),
              BlocProvider<ToyCatalogCubit>(
                create: (context) => ToyCatalogCubit(context.read<ToyRepository>()),
              ),
              BlocProvider<ReportCubit>(
                create: (context) => ReportCubit(context.read<RentalRepository>(), context.read<ToyRepository>()),
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
