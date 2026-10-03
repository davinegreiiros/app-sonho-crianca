// Rig compartilhado pelos testes legados de locação (spec 017/018, prévios
// à migração pra Cubit) que testavam o fluxo inteiro direto em `AppState`.
// `AppState.submitNew`/`extendActive`/`cancelActive`/`confirmEnd` foram
// removidos na spec 026-rental-via-backend (viraram `Future` + exigem
// sessão real, incompatível com a forma síncrona que `AppState` sempre
// teve) — estes testes migraram pra acionar `NewRentalCubit`/
// `ActiveRentalsCubit` direto, os mesmos Cubits que a UI real usa desde as
// specs 017/018.

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/rental_repository.dart';
import 'package:sonho_de_crianca/data/repositories/toy_repository.dart';
import 'package:sonho_de_crianca/data/services/api_client.dart';
import 'package:sonho_de_crianca/data/services/rental_remote_service.dart';
import 'package:sonho_de_crianca/data/services/local_rental_notifier.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/domain/rental_notifier.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/active_rentals_cubit.dart';
import 'package:sonho_de_crianca/ui/features/rental/view_models/new_rental_cubit.dart';

import 'fake_business_settings.dart' show fakeTestOperator;
import 'fake_rental_backend.dart';
import 'fake_toy_backend.dart';

class RentalFlowRig {
  RentalFlowRig({RentalNotifier? notifications})
      : toyRepository = fakeToyRepository(initial: kInitialToys),
        rentalRepository = RentalRepository(
          service: RentalRemoteService(ApiClient(httpClient: fakeRentalBackend())),
          authRepository: AuthRepository.withSession(token: 'fake-token', operator: fakeTestOperator),
        ),
        _notifications = notifications ?? LocalRentalNotifier() {
    newRentalCubit = NewRentalCubit(toyRepository, rentalRepository, notifications: _notifications);
    activeRentalsCubit = ActiveRentalsCubit(toyRepository, rentalRepository, notifications: _notifications);
  }

  final ToyRepository toyRepository;
  final RentalRepository rentalRepository;
  final RentalNotifier _notifications;
  late final NewRentalCubit newRentalCubit;
  late final ActiveRentalsCubit activeRentalsCubit;

  void dispose() {
    newRentalCubit.close();
    activeRentalsCubit.close();
  }
}
