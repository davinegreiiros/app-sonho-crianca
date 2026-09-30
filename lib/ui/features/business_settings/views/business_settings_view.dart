import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../data/repositories/business_settings_repository.dart';
import '../../../../data/services/pix_payload.dart';
import '../../../../test_keys.dart';
import '../../../../theme/app_colors.dart';
import '../../../../widgets/animations/bounce.dart';
import '../../../../widgets/animations/print_strip.dart';
import '../../../../widgets/animations/pressable.dart';
import '../view_models/business_settings_cubit.dart';
import '../view_models/business_settings_state.dart';

/// Motivo de saída de [BusinessSettingsView] pro `Navigator.pop` — usado só
/// por `openBusinessSettingsScreen` (spec 024-sync-backend-fundacao) pra
/// decidir se mostra um aviso. `null` (voltar manual) não precisa de aviso.
enum BusinessSettingsExitReason { sessionExpired }

/// "Configurações do negócio" — name/city/Pix key used to generate the
/// Pix QR at the end of a locação (spec 004-pix-qrcode). A partir da spec
/// 024-sync-backend-fundacao, sincroniza com o backend (não mais só
/// `SharedPreferences`) — ver `BusinessSettingsRepository`. Só é alcançável
/// com sessão de operador válida (guarda em `openBusinessSettingsScreen`).
///
/// A full-page destination (`Navigator.push`), not a bottom sheet — spec
/// 007-revisao-design-v3, artboard 1d: "é destino de navegação, não
/// formulário de fluxo".
class BusinessSettingsView extends StatefulWidget {
  const BusinessSettingsView({super.key, this.hint});

  /// Optional message shown above the form — used when this screen opens
  /// because the operator picked "Pix" before configuring anything yet.
  final String? hint;

  @override
  State<BusinessSettingsView> createState() => _BusinessSettingsViewState();
}

class _BusinessSettingsViewState extends State<BusinessSettingsView> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _pixKeyCtrl = TextEditingController();

  /// Só sincroniza os controllers com o valor do backend uma vez, na
  /// primeira resposta depois do `loading` inicial — evita sobrescrever o
  /// que o operador já digitou se o Cubit emitir de novo por outro motivo.
  bool _fieldsSynced = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nameCtrl, _cityCtrl, _pixKeyCtrl]) {
      c.addListener(() => setState(() {}));
    }
    // Busca o valor atual no backend ao entrar na tela — não no boot do
    // app (spec 024: evita rede em todo cold start por um dado que só
    // importa quando esta tela abre de verdade). Agendado pro fim do
    // frame atual: chamar direto aqui notificaria (`Repository.load()`
    // seta `status = loading` e notifica antes de qualquer `await`) no
    // meio do build desta própria tela, o que o framework não permite.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BusinessSettingsCubit>().refresh();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _pixKeyCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _nameCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty && _pixKeyCtrl.text.trim().isNotEmpty;

  Future<void> _save(BusinessSettingsCubit cubit) async {
    if (!_valid) return;
    await cubit.save(
      merchantName: _nameCtrl.text.trim(),
      merchantCity: _cityCtrl.text.trim(),
      pixKey: _pixKeyCtrl.text.trim(),
    );
    if (!mounted) return;
    // Só fecha em sucesso confirmado — erro de rede/sessão fica visível
    // no banner (spec 024, cenário 6: nunca finge que salvou).
    if (cubit.state.status == BusinessSettingsSyncStatus.loaded) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<BusinessSettingsCubit>();
    final state = cubit.state;

    return BlocListener<BusinessSettingsCubit, BusinessSettingsState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (!_fieldsSynced &&
            state.status != BusinessSettingsSyncStatus.loading &&
            state.status != BusinessSettingsSyncStatus.idle) {
          _nameCtrl.text = state.settings.merchantName;
          _cityCtrl.text = state.settings.merchantCity;
          _pixKeyCtrl.text = state.settings.pixKey;
          _fieldsSynced = true;
        }
        if (state.status == BusinessSettingsSyncStatus.unauthorized) {
          Navigator.of(context).pop(BusinessSettingsExitReason.sessionExpired);
        }
      },
      child: _buildScaffold(context, cubit, state),
    );
  }

  Widget _buildScaffold(BuildContext context, BusinessSettingsCubit cubit, BusinessSettingsState state) {
    final firstLoadPending = state.status == BusinessSettingsSyncStatus.loading && !_fieldsSynced;

    // Preview only — never persisted, never sent anywhere. Built from
    // whatever's typed so far, amount 0 (a placeholder charge amount is
    // fine for a QR that only exists to show the operator "this is what
    // your data looks like").
    final previewPayload = buildPixPayload(
      merchantName: _nameCtrl.text.trim(),
      merchantCity: _cityCtrl.text.trim(),
      pixKey: _pixKeyCtrl.text.trim(),
      amountCents: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20, bottom: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.accent200, AppColors.accent100, AppColors.bg],
                  stops: [0, 0.7, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pressable(
                        child: InkWell(
                          key: TestKeys.settingsScreenBackButton,
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.accent700),
                                SizedBox(width: 6),
                                Text(
                                  'Painel',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.accent700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Row(
                        children: [
                          Bouncy(phase: 0, child: _Dot(AppColors.accent)),
                          SizedBox(width: 4),
                          Bouncy(phase: 0.33, child: _Dot(AppColors.accent2)),
                          SizedBox(width: 4),
                          Bouncy(phase: 0.66, child: _Dot(AppColors.processYellow)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const PrintStrip(height: 3),
                  const Divider(height: 1, thickness: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  const Text('Configurações', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.05)),
                  const SizedBox(height: 4),
                  Text(
                    'Usados no QR de cobrança e no recibo.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.accent900.withValues(alpha: 0.68)),
                  ),
                ],
              ),
            ),
          ),
          if (firstLoadPending)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 22 + MediaQuery.of(context).viewInsets.bottom),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.hint != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.yellowTint, borderRadius: BorderRadius.circular(6)),
                        child: Text(widget.hint!, style: const TextStyle(fontSize: 12.5, color: AppColors.yellowFgDark)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.status == BusinessSettingsSyncStatus.networkError) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.yellowTint, borderRadius: BorderRadius.circular(6)),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.yellowFgDark),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sem conexão com o servidor — não foi possível carregar/salvar agora.',
                                style: TextStyle(fontSize: 12.5, color: AppColors.yellowFgDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _SectionHeader(icon: Icons.storefront_outlined, color: AppColors.accent700, label: 'Recebedor'),
                    const SizedBox(height: 12),
                    const _FieldLabel('Nome que aparece no Pix'),
                    _Field(key: TestKeys.businessNameField, controller: _nameCtrl, hint: 'Ex: Sonho de Criança'),
                    const SizedBox(height: 14),
                    const _FieldLabel('Cidade'),
                    _Field(key: TestKeys.businessCityField, controller: _cityCtrl, hint: 'Ex: Fortaleza'),
                    const SizedBox(height: 24),
                    _SectionHeader(icon: Icons.key_outlined, color: AppColors.accent2_700, label: 'Chave Pix'),
                    const SizedBox(height: 12),
                    const _FieldLabel('Telefone, CPF, e-mail ou aleatória'),
                    _Field(
                      key: TestKeys.businessPixKeyField,
                      controller: _pixKeyCtrl,
                      hint: 'CPF, CNPJ, telefone, e-mail ou chave aleatória',
                      monospace: true,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(3)),
                      child: Row(
                        children: [
                          QrImageView(
                            data: previewPayload,
                            size: 44,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(color: AppColors.accent2_700),
                            dataModuleStyle: const QrDataModuleStyle(color: AppColors.text),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Prévia do QR com os dados atuais. Ele é gerado no aparelho — nada sai do celular.',
                              style: TextStyle(fontSize: 11.5, height: 1.45, color: AppColors.text.withValues(alpha: 0.72)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Pressable(
                        child: ElevatedButton(
                          key: TestKeys.saveBusinessSettingsButton,
                          onPressed: _valid ? () => _save(cubit) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.bg,
                            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
                            disabledForegroundColor: AppColors.bg.withValues(alpha: 0.85),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Salvar configurações'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

/// Icon + kicker + hairline section divider — the design's "regra do
/// broadsheet": sections separated by this, never by a card.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 9),
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: AppColors.text.withValues(alpha: 0.12))),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.7))),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({super.key, required this.controller, this.hint, this.monospace = false});
  final TextEditingController controller;
  final String? hint;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: monospace ? 13.5 : 15, fontFamily: monospace ? 'monospace' : null, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.4)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
        ),
      ),
    );
  }
}
