import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../ui/features/auth/views/login_view.dart';

/// Garante sessão do administrador antes de uma ação sensível — extraído
/// de `openBusinessSettingsScreen` (spec 024) pra ser reaproveitado por
/// qualquer escrita que exija identidade de verdade (spec 025: editar
/// catálogo). Sem sessão válida, empurra [LoginView]; devolve `true` só se
/// já estava logado ou acabou de logar com sucesso — `false` se o operador
/// cancelar (volta sem logar), e quem chamou não deve prosseguir com a ação.
Future<bool> ensureOperatorSession(BuildContext context) {
  return _ensure(Navigator.of(context), context.read<AuthRepository>());
}

/// Mesma guarda de [ensureOperatorSession], mas resolvendo `Navigator`/
/// `AuthRepository` **agora** e devolvendo o callback — pra ação "Entrar"
/// de SnackBar. A SnackBar sobrevive ao sheet/diálogo de onde o erro saiu;
/// usar o `BuildContext` dele no toque, depois de desmontado, lançava
/// "Looking up a deactivated widget's ancestor is unsafe" (spec 027,
/// cenário 9).
VoidCallback loginActionFor(BuildContext context) {
  final navigator = Navigator.of(context);
  final authRepository = context.read<AuthRepository>();
  return () => _ensure(navigator, authRepository);
}

Future<bool> _ensure(NavigatorState navigator, AuthRepository authRepository) async {
  if (authRepository.isLoggedIn) return true;
  if (!navigator.mounted) return false;

  final loggedIn = await navigator.push<bool>(
    MaterialPageRoute(builder: (context) => const LoginView()),
  );
  return loggedIn == true;
}
