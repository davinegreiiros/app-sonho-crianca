import 'package:flutter/material.dart';

import '../data/services/api_exceptions.dart';
import 'auth_gate.dart';

/// Mensagem por tipo de erro pra uma ação de locação (spec
/// 026-rental-via-backend) — mesmo padrão de `_showToyActionError`
/// (`catalog_view.dart`, spec 025), compartilhado entre as views que
/// criam/estendem/cancelam/finalizam locação: sessão de operador real
/// ausente ganha ação "Entrar"; o resto mostra a mensagem do próprio erro
/// (um 409/400 do backend já vem com o texto de negócio pronto).
void showRentalActionError(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  if (error is ApiUnauthorizedException) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Faça login para continuar.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Entrar', onPressed: () => ensureOperatorSession(context)),
      ),
    );
    return;
  }
  final message = error is ApiNetworkException || error is ApiException ? error.toString() : 'Não foi possível salvar. Tenta de novo.';
  messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}
