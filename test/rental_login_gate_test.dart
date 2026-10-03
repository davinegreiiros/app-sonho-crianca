// Widget test for spec 026-rental-via-backend, cenário 7: sem sessão do
// administrador (aparelho novo, "Sair da conta" ou token vencido — spec
// 027), criar uma locação leva ao login antes — mesma guarda que
// Configurações/Catálogo já usam (`ensureOperatorSession`). Entrada no
// modo administrador também pede login (cenário 1 da 027 — mais casos em
// `admin_session_test.dart`).

import 'package:flutter_test/flutter_test.dart';

import 'package:sonho_de_crianca/data/repositories/auth_repository.dart';
import 'package:sonho_de_crianca/data/repositories/turno_repository.dart';
import 'package:sonho_de_crianca/domain/models/toy.dart';
import 'package:sonho_de_crianca/main.dart';
import 'package:sonho_de_crianca/test_keys.dart';

import 'fakes/fake_rental_backend.dart';
import 'fakes/fake_session_storage.dart';
import 'fakes/fake_toy_backend.dart';

void main() {
  setUp(setUpFakeSessionStorage);

  testWidgets('"Entrar como administrador" sem sessão real leva ao login antes de entrar', (tester) async {
    final authRepository = AuthRepository(); // sem sessão nenhuma
    await tester.pumpWidget(SonhoDeCriancaApp(
      authRepository: authRepository,
      toyRepository: fakeToyRepository(initial: kInitialToys, authRepository: authRepository),
      rentalRepository: fakeRentalRepository(authRepository: authRepository),
      turnoRepository: TurnoRepository(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // 3a — ainda não entrou em modo administrador.
    expect(find.byKey(TestKeys.enterAdminButton), findsOneWidget);

    await tester.tap(find.byKey(TestKeys.enterAdminButton));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Levado ao login na hora — não entrou direto no painel (spec 026:
    // antes só pedia na primeira locação, tarde demais).
    expect(find.byKey(TestKeys.loginUsernameField), findsOneWidget);
    expect(find.byKey(TestKeys.fabNewRental), findsNothing);
  });

  testWidgets('modo administrador sem sessão real: "Iniciar locação" leva ao login antes de criar', (tester) async {
    final authRepository = AuthRepository(); // sem sessão nenhuma
    await tester.pumpWidget(SonhoDeCriancaApp(
      authRepository: authRepository,
      toyRepository: fakeToyRepository(initial: kInitialToys, authRepository: authRepository),
      rentalRepository: fakeRentalRepository(authRepository: authRepository),
      startInPostoAdminMode: true,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(TestKeys.fabNewRental));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(find.byKey(TestKeys.draftChildNameField), 'Sem Login');
    await tester.pump();
    // O botão "Iniciar locação" fica fora da viewport de teste depois de
    // digitar — mesmo ajuste que outros testes desta sheet já precisam.
    await tester.ensureVisible(find.byKey(TestKeys.submitNewRentalButton));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(TestKeys.submitNewRentalButton));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Levado ao login — a sheet de nova locação não chegou a fechar/criar.
    expect(find.byKey(TestKeys.loginUsernameField), findsOneWidget);
  });
}
