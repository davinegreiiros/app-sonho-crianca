import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/toy.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'animations/pressable.dart';

/// "Novo brinquedo" bottom sheet: name, a scrollable grid of illustrated
/// icon options, quantity/price/duration and an ink color pick.
class AddToySheet extends StatefulWidget {
  const AddToySheet({super.key});

  @override
  State<AddToySheet> createState() => _AddToySheetState();
}

class _AddToySheetState extends State<AddToySheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController(text: '10');
  final _minutesCtrl = TextEditingController(text: '15');
  ToyInk _ink = ToyInk.cyan;
  String _imageKey = kToyIconOptions.first.key;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  bool get _valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      (int.tryParse(_qtyCtrl.text) ?? 0) > 0 &&
      (int.tryParse(_minutesCtrl.text) ?? 0) > 0 &&
      (double.tryParse(_priceCtrl.text) ?? -1) >= 0;

  void _submit(AppState state) {
    if (!_valid) return;
    state.addToy(
      name: _nameCtrl.text.trim(),
      price: double.parse(_priceCtrl.text),
      blockMin: int.parse(_minutesCtrl.text),
      ink: _ink,
      imageKey: _imageKey,
      qty: int.parse(_qtyCtrl.text),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Novo brinquedo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Nome'),
              _Field(
                controller: _nameCtrl,
                hint: 'Ex: Touro Mecânico',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Ícone'),
              const SizedBox(height: 6),
              _IconGrid(
                selected: _imageKey,
                onSelected: (key) => setState(() => _imageKey = key),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Quantidade'),
                        _Field(
                          controller: _qtyCtrl,
                          numeric: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Preço R\$'),
                        _Field(
                          controller: _priceCtrl,
                          numeric: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Minutos'),
                        _Field(
                          controller: _minutesCtrl,
                          numeric: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Cor do brinquedo'),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final ink in ToyInk.values) ...[
                    if (ink != ToyInk.values.first) const SizedBox(width: 10),
                    Expanded(
                      child: _ColorOption(
                        ink: ink,
                        selected: _ink == ink,
                        onTap: () => setState(() => _ink = ink),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Pressable(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(
                            color: AppColors.text.withValues(alpha: 0.16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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
                        onPressed: _valid ? () => _submit(state) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          disabledBackgroundColor: AppColors.accent.withValues(
                            alpha: 0.45,
                          ),
                          disabledForegroundColor: AppColors.bg.withValues(
                            alpha: 0.85,
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Salvar brinquedo'),
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
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.text.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hint,
    this.numeric = false,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final bool numeric;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(fontSize: 15, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.text.withValues(alpha: 0.4)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.8),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _IconGrid extends StatefulWidget {
  const _IconGrid({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<_IconGrid> createState() => _IconGridState();
}

class _IconGridState extends State<_IconGrid> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 264,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(right: 10),
          itemCount: kToyIconOptions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemBuilder: (context, i) {
            final option = kToyIconOptions[i];
            final isSelected = option.key == widget.selected;
            return Pressable(
              child: GestureDetector(
                onTap: () => widget.onSelected(option.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.text.withValues(alpha: 0.12),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.asset(
                            option.asset,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: AppColors.accent100,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.toys_rounded,
                                    color: AppColors.accent700,
                                    size: 20,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.ink,
    required this.selected,
    required this.onTap,
  });
  final ToyInk ink;
  final bool selected;
  final VoidCallback onTap;

  String get _label => switch (ink) {
    ToyInk.cyan => 'Ciano',
    ToyInk.magenta => 'Magenta',
    ToyInk.yellow => 'Amarelo',
  };

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? ink.tint : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? ink.dot
                  : AppColors.text.withValues(alpha: 0.14),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ink.dot,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? ink.fg : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
