# Tasks: Login do administrador na entrada + sessão única + logout

Referência: `spec.md` + `plan.md` nesta mesma pasta.

- [x] T1 — `AuthSessionLocalService` (SharedPreferences) + `AuthRepository` reescrito (sem sessão de dispositivo, expiração por `exp`, `clock` injetável).
- [x] T2 — `ToyRepository`/`RentalRepository`: `load()` com token do administrador, sem chamada sem token, logout em 401 (leitura e escrita).
- [x] T3 — `RentalRemoteService.finish` envia `finalPrice` (tempo corrido).
- [x] T4 — `main.dart`: carga no boot e a cada login novo.
- [x] T5 — `auth_gate.dart`: `loginActionFor`; SnackBars de `rental_action_error.dart`/`catalog_view.dart` migradas.
- [x] T6 — "Entrar como administrador" pede login só sem sessão válida (revisado: 1ª versão pedia sempre).
- [x] T7 — Menu do administrador no cabeçalho: "Voltar para os postos" / "Sair da conta" (com confirmação) + `TestKeys`.
- [x] T8 — Remove `flutter_secure_storage`, `secrets.example.json`, args do `launch.json`; `allowBackup="false"`.
- [x] T9 — Testes: `auth_repository_test.dart` (prefs, JWT vencido/válido, restore descarta vencida), `toy_repository_test.dart`/`rental_repository_test.dart` (token do admin, sem token não chama, 401 derruba sessão, `finalPrice`), `admin_session_test.dart` (cenários 1, 2, 4, 5, 9). Fake `fake_secure_storage.dart` → `fake_session_storage.dart`.
- [x] T10 — Docs: `specs/README.md`, notas na 025/026, contrato do backend#003.
- [x] T11 — `flutter analyze` limpo + `flutter test` completo verde.
