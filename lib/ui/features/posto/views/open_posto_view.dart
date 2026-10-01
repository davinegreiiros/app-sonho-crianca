import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/auth_gate.dart';
import '../../../../widgets/toy_icon.dart';
import '../view_models/posto_session_cubit.dart';
import '../view_models/posto_session_state.dart';

/// 3a — "Escolha seu posto" (spec 023-posto-monitor-painel). Always the
/// app's first screen (`main.dart`, `PostoMode.none`): lists every toy as
/// a posto, livre ou ocupado (com quem) — tocar num posto ocupado retoma
/// o turno direto (cenário 2 do spec, sem pedir login de novo: a sessão
/// de quem abriu já está ativa no aparelho).
///
/// Login real por turno (spec 026-rental-via-backend): tocar num posto
/// **livre** não pede mais um nome digitado — leva direto ao login real
/// de operador (`ensureOperatorSession`); sucesso abre o turno com
/// `Turno.monitorName` = nome do operador logado.
class OpenPostoView extends StatefulWidget {
  const OpenPostoView({super.key});

  @override
  State<OpenPostoView> createState() => _OpenPostoViewState();
}

class _OpenPostoViewState extends State<OpenPostoView> {
  bool _entering = false;

  Future<void> _tapPosto(PostoSummary p) async {
    if (p.openTurno != null) {
      context.read<PostoSessionCubit>().openOrResume(p.toy.id);
      return;
    }
    if (_entering) return;
    setState(() => _entering = true);
    final loggedIn = await ensureOperatorSession(context);
    if (!mounted) return;
    setState(() => _entering = false);
    if (!loggedIn) return;
    final operatorName = context.read<AuthRepository>().currentOperator!.name;
    context.read<PostoSessionCubit>().openOrResume(p.toy.id, monitorName: operatorName);
  }

  @override
  Widget build(BuildContext context) {
    final postos = context.watch<PostoSessionCubit>().state.postos;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Text(
              'Quem é você hoje',
              style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: AppColors.accent700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Escolha seu posto',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.05),
            ),
            const SizedBox(height: 4),
            Text(
              'Tudo que você registrar fica no seu nome até o fechamento do turno.',
              style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 18),
            for (final p in postos) ...[
              _PostoRow(posto: p, onTap: () => _tapPosto(p)),
              const SizedBox(height: 10),
            ],
            if (_entering) ...[
              const SizedBox(height: 10),
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: TestKeys.enterAdminButton,
              onPressed: () => context.read<PostoSessionCubit>().enterAdmin(),
              icon: const Icon(Icons.shield_outlined, size: 17),
              label: const Text('Entrar como administrador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostoRow extends StatelessWidget {
  const _PostoRow({required this.posto, required this.onTap});
  final PostoSummary posto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final toy = posto.toy;
    final turno = posto.openTurno;
    final occupied = turno != null;

    return Material(
      color: occupied ? toy.ink.tint : AppColors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: TestKeys.postoRow(toy.id),
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              ToyIcon(imageKey: toy.imageKey, ink: toy.ink, size: 38, radius: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(toy.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(
                      occupied ? 'Com ${turno.monitorName}' : 'Livre',
                      style: TextStyle(fontSize: 12, color: occupied ? toy.ink.fg : AppColors.text.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              Text(
                occupied ? 'RETOMAR' : 'ABRIR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: occupied ? toy.ink.fg : AppColors.text.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
