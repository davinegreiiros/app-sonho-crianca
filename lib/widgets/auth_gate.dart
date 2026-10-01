import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/auth_repository.dart';
import '../ui/features/auth/views/login_view.dart';

/// Garante sessão de operador real antes de uma ação sensível — extraído
/// de `openBusinessSettingsScreen` (spec 024) pra ser reaproveitado por
/// qualquer escrita que exija identidade de verdade (spec 025: editar
/// catálogo). Sem sessão, empurra [LoginView]; devolve `true` só se já
/// estava logado ou acabou de logar com sucesso — `false` se o operador
/// cancelar (volta sem logar), e quem chamou não deve prosseguir com a ação.
Future<bool> ensureOperatorSession(BuildContext context) async {
  final authRepository = context.read<AuthRepository>();
  if (authRepository.isLoggedIn) return true;

  final loggedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (context) => const LoginView()),
  );
  return loggedIn == true;
}
