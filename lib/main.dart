import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'data/repositories/business_settings_repository.dart';
import 'screens/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/features/business_settings/view_models/business_settings_cubit.dart';

void main() {
  runApp(const SonhoDeCriancaApp());
}

class SonhoDeCriancaApp extends StatelessWidget {
  const SonhoDeCriancaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Single shared instance (spec 011-migracao-configuracoes-negocio):
        // both AppState (old world, still read by end_rental_dialog.dart/
        // pix_qr_sheet.dart) and BusinessSettingsCubit (new world) must see
        // the exact same BusinessSettings — never construct a second one.
        // ChangeNotifierProvider (not plain Provider): BusinessSettingsRepository
        // is itself a ChangeNotifier and provider asserts against exposing a
        // Listenable through a provider type that won't propagate its updates.
        ChangeNotifierProvider<BusinessSettingsRepository>(
          create: (_) => BusinessSettingsRepository(),
        ),
        ChangeNotifierProvider<AppState>(
          create: (context) => AppState(businessSettingsRepository: context.read<BusinessSettingsRepository>()),
        ),
      ],
      child: Builder(
        builder: (context) {
          return BlocProvider<BusinessSettingsCubit>(
            create: (context) => BusinessSettingsCubit(context.read<BusinessSettingsRepository>()),
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
