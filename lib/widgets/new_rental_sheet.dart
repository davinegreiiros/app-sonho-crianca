import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../test_keys.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';
import 'animations/print_strip.dart';

/// The "Nova locação" bottom sheet: toy picker, child/guardian fields,
/// duration presets and price — ported from the design's `showNew` panel.
class NewRentalSheet extends StatelessWidget {
  const NewRentalSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final draft = state.draft;
    final presets = const [10, 15, 30, 60];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const ClipRRect(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                child: PrintStrip(height: 4),
              ),
              const SizedBox(height: 14),
              const Text('Nova locação', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const _FieldLabel('Brinquedo'),
              _Dropdown(state: state),
              const SizedBox(height: 12),
              const _FieldLabel('Nome da criança'),
              _TextInput(
                key: TestKeys.draftChildNameField,
                initial: draft.childName,
                hint: 'Ex: Sofia',
                onChanged: state.setDraftChild,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Responsável'),
                        _TextInput(
                          key: TestKeys.draftGuardianNameField,
                          initial: draft.guardianName,
                          hint: 'Nome do responsável',
                          onChanged: state.setDraftGuardian,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Telefone'),
                        _TextInput(
                          key: TestKeys.draftGuardianPhoneField,
                          initial: draft.guardianPhone,
                          hint: '(85) 9.....',
                          keyboardType: TextInputType.phone,
                          onChanged: state.setDraftPhone,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Cobrança'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Pressable(
                      child: _PresetButton(
                        key: TestKeys.rentalModeFixed,
                        label: 'Tempo fixo',
                        selected: !draft.openEnded,
                        onTap: () => state.setDraftOpenEnded(false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Pressable(
                      child: _PresetButton(
                        key: TestKeys.rentalModeOpenEnded,
                        label: 'Tempo corrido',
                        selected: draft.openEnded,
                        onTap: () => state.setDraftOpenEnded(true),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (draft.openEnded) ...[
                const _FieldLabel('Cobrado por minuto, no valor de:'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${state.fmtMoney(state.ratePerMinute(state.toyById(draft.toyId)))}/min · calculado ao finalizar',
                    style: const TextStyle(fontSize: 13, color: AppColors.text),
                  ),
                ),
              ] else ...[
                const _FieldLabel('Tempo (minutos)'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final m in presets) ...[
                      if (m != presets.first) const SizedBox(width: 8),
                      Expanded(
                        child: Pressable(
                          child: _PresetButton(
                            label: '${m}min',
                            selected: draft.durationMin == m,
                            onTap: () => state.applyDuration(m),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _TextInput(
                  key: ValueKey('duration-${draft.durationMin}'),
                  initial: '${draft.durationMin}',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) state.applyDuration(n);
                  },
                ),
                const SizedBox(height: 12),
                const _FieldLabel('Valor (R\$)'),
                _TextInput(
                  key: ValueKey('price-${draft.price}'),
                  initial: draft.price.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = double.tryParse(v);
                    if (n != null) state.setDraftPrice(n);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Pressable(
                      child: OutlinedButton(
                        key: TestKeys.cancelNewRentalButton,
                        onPressed: () {
                          state.closeNew();
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Pressable(
                      child: ElevatedButton(
                        key: TestKeys.submitNewRentalButton,
                        onPressed: draft.childName.trim().isEmpty
                            ? null
                            : () {
                                state.submitNew();
                                Navigator.of(context).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Iniciar locação'),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: TextStyle(fontSize: 12, color: AppColors.text.withValues(alpha: 0.7))),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    super.key,
    required this.initial,
    this.hint,
    this.keyboardType,
    required this.onChanged,
  });

  final String initial;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initial,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _Dropdown extends StatefulWidget {
  const _Dropdown({required this.state});
  final AppState state;

  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: _focused ? AppColors.accent : AppColors.text.withValues(alpha: 0.16), width: _focused ? 1.8 : 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          focusNode: _focus,
          value: state.draft.toyId,
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          items: [
            for (final t in state.toys)
              DropdownMenuItem(
                value: t.id,
                child: Text('${t.name} — ${state.toyAvailable(t)} livre(s)', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) state.setDraftToy(v);
          },
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.accent : Colors.transparent,
        foregroundColor: selected ? AppColors.bg : AppColors.text,
        side: BorderSide(color: selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.16)),
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
