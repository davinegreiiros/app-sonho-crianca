import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/auth_gate.dart';
import '../../../../widgets/toy_icon.dart';
import '../../../core/initials_avatar.dart';
import '../view_models/posto_session_cubit.dart';
import '../view_models/posto_session_state.dart';

/// 3a — "Escolha seu posto" (spec 023-posto-monitor-painel). Always the
/// app's first screen (`main.dart`, `PostoMode.none`): lists every toy as
/// a posto, livre ou ocupado (com quem), campo de nome só aparece depois
/// de tocar num posto livre — tocar num posto ocupado retoma o turno
/// direto (cenário 2 do spec, sem pedir nome de novo).
///
/// Nome livre, **sem conta** (spec 026-rental-via-backend: decisão
/// revisada — ver `spec.md`, "Correção — login fica só com o
/// administrador"). Monitores rotativos não têm Operator cadastrado;
/// `Turno.monitorName`/`createdByMonitorName` continuam um rótulo local,
/// nunca verificado. A sessão do administrador que o backend exige é
/// checada aqui, ao tocar "Entrar como administrador" (`_enterAdmin`, spec
/// 027-login-admin-sessao): sem sessão válida (aparelho novo, "Sair da
/// conta", token vencido) pede login; com sessão válida entra direto —
/// voltar pros postos e entrar de novo não obriga relogar. A mesma sessão
/// é usada pelo posto pra registrar locação (guarda `ensureOperatorSession`
/// em `new_rental_sheet_view.dart`/`modal_launchers.dart`).
class OpenPostoView extends StatefulWidget {
  const OpenPostoView({super.key});

  @override
  State<OpenPostoView> createState() => _OpenPostoViewState();
}

class _OpenPostoViewState extends State<OpenPostoView> {
  String? _selectedFreeToyId;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Faz o preview de iniciais e o rótulo do botão ("Entrar como
    // Gustavo") acompanharem o nome digitado em tempo real — design
    // source: artboard 3a mostra o avatar "GU" já no campo, não só
    // depois de confirmar.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _tapPosto(PostoSummary p) {
    if (p.openTurno != null) {
      context.read<PostoSessionCubit>().openOrResume(p.toy.id);
      return;
    }
    setState(() => _selectedFreeToyId = p.toy.id);
  }

  void _confirmEnter(String toyId) {
    if (_nameController.text.trim().isEmpty) return;
    context.read<PostoSessionCubit>().openOrResume(toyId, monitorName: _nameController.text);
    _nameController.clear();
    setState(() => _selectedFreeToyId = null);
  }

  /// Pede login só sem sessão válida (spec 027, cenário 1). O "login
  /// recente" (até 15 min) que o backend exige pra fechar turno
  /// (backend#003) não é checado aqui — quando o app consumir essa rota,
  /// o 403 dela é que deve pedir login de novo.
  Future<void> _enterAdmin() async {
    if (!await ensureOperatorSession(context)) return;
    if (!mounted) return;
    context.read<PostoSessionCubit>().enterAdmin();
  }

  @override
  Widget build(BuildContext context) {
    final postos = context.watch<PostoSessionCubit>().state.postos;
    final selectedToy = _selectedFreeToyId;
    final typedName = _nameController.text.trim();

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
              _PostoRow(
                posto: p,
                selected: p.toy.id == selectedToy,
                onTap: () => _tapPosto(p),
              ),
              const SizedBox(height: 10),
            ],
            if (selectedToy != null) ...[
              const SizedBox(height: 6),
              Builder(builder: (context) {
                final toy = postos.firstWhere((p) => p.toy.id == selectedToy).toy;
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Seu nome no posto · ${toy.name}',
                        style: TextStyle(fontSize: 11.5, color: AppColors.text.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: TestKeys.postoNameField,
                              controller: _nameController,
                              autofocus: true,
                              decoration: const InputDecoration(hintText: 'Ex: Gustavo'),
                              onSubmitted: (_) => _confirmEnter(selectedToy),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InitialsAvatar(text: initialsOf(typedName), background: toy.ink.dot, foreground: AppColors.bg),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        key: TestKeys.postoEnterButton,
                        onPressed: () => _confirmEnter(selectedToy),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        ),
                        child: Text(typedName.isEmpty ? 'Entrar no posto' : 'Entrar como $typedName'),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 8),
            const _OrDivider(),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: TestKeys.enterAdminButton,
              onPressed: _enterAdmin,
              icon: const Icon(Icons.business_center_outlined, size: 17),
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: AppColors.text.withValues(alpha: 0.18), height: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('ou', style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, color: AppColors.text.withValues(alpha: 0.5))),
        ),
        line,
      ],
    );
  }
}

class _PostoRow extends StatelessWidget {
  const _PostoRow({required this.posto, required this.selected, required this.onTap});
  final PostoSummary posto;

  /// Posto livre tocado, aguardando o nome — destaca a linha pra deixar
  /// claro em qual brinquedo o monitor vai entrar.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final toy = posto.toy;
    final turno = posto.openTurno;
    final occupied = turno != null;

    final String statusLabel;
    final String subLabel;
    if (occupied) {
      statusLabel = 'OCUPADO';
      final since = turno.openedAt;
      subLabel = '${turno.monitorName} · turno desde ${since.hour.toString().padLeft(2, '0')}:${since.minute.toString().padLeft(2, '0')}';
    } else if (selected) {
      statusLabel = 'VOCÊ';
      subLabel = 'Confirme seu nome abaixo';
    } else {
      statusLabel = 'LIVRE';
      subLabel = 'sem monitor · toque para assumir';
    }

    return Material(
      color: toy.ink.tint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: selected ? BorderSide(color: toy.ink.fg, width: 2) : BorderSide.none,
      ),
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
                      subLabel,
                      style: TextStyle(fontSize: 12, color: occupied || selected ? toy.ink.fg : AppColors.text.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: occupied || selected ? toy.ink.fg : AppColors.text.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
