import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/business_settings.dart';
import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';

/// "Configurações do negócio" bottom sheet: name/city/Pix key used to
/// generate the Pix QR at the end of a locação (spec 004-pix-qrcode).
/// Persisted locally only — see `AppState.updateBusinessSettings` and
/// `specs/002-seguranca-dados/spec.md` (never hardcoded, never in git).
class BusinessSettingsSheet extends StatefulWidget {
  const BusinessSettingsSheet({super.key, this.hint});

  /// Optional message shown above the form — used when this sheet opens
  /// because the operator picked "Pix" before configuring anything yet.
  final String? hint;

  @override
  State<BusinessSettingsSheet> createState() => _BusinessSettingsSheetState();
}

class _BusinessSettingsSheetState extends State<BusinessSettingsSheet> {
  late final _nameCtrl = TextEditingController(text: _settings.merchantName);
  late final _cityCtrl = TextEditingController(text: _settings.merchantCity);
  late final _pixKeyCtrl = TextEditingController(text: _settings.pixKey);

  BusinessSettings get _settings => context.read<AppState>().businessSettings;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _pixKeyCtrl.dispose();
    super.dispose();
  }

  bool get _valid => _nameCtrl.text.trim().isNotEmpty && _cityCtrl.text.trim().isNotEmpty && _pixKeyCtrl.text.trim().isNotEmpty;

  void _save(AppState state) {
    if (!_valid) return;
    state.updateBusinessSettings(
      merchantName: _nameCtrl.text.trim(),
      merchantCity: _cityCtrl.text.trim(),
      pixKey: _pixKeyCtrl.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Configurações do negócio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Usado só pra gerar o QR Code Pix na hora de finalizar uma locação. Fica salvo neste aparelho.',
                style: TextStyle(fontSize: 12.5, color: AppColors.text.withValues(alpha: 0.65)),
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.yellowTint, borderRadius: BorderRadius.circular(6)),
                  child: Text(widget.hint!, style: const TextStyle(fontSize: 12.5, color: AppColors.yellowFgDark)),
                ),
              ],
              const SizedBox(height: 16),
              const _FieldLabel('Nome do recebedor'),
              _Field(key: TestKeys.businessNameField, controller: _nameCtrl, hint: 'Ex: Sonho de Criança', onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              const _FieldLabel('Cidade'),
              _Field(key: TestKeys.businessCityField, controller: _cityCtrl, hint: 'Ex: Fortaleza', onChanged: (_) => setState(() {})),
              const SizedBox(height: 14),
              const _FieldLabel('Chave Pix'),
              _Field(key: TestKeys.businessPixKeyField, controller: _pixKeyCtrl, hint: 'CPF, CNPJ, telefone, e-mail ou chave aleatória', onChanged: (_) => setState(() {})),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Pressable(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Pressable(
                      child: ElevatedButton(
                        key: TestKeys.saveBusinessSettingsButton,
                        onPressed: _valid ? () => _save(state) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Salvar'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      child: Text(text, style: TextStyle(fontSize: 13, color: AppColors.text.withValues(alpha: 0.7))),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({super.key, required this.controller, this.hint, required this.onChanged});
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.4)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
