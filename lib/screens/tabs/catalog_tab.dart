import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/toy.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/animations/cascade.dart';
import '../../widgets/animations/pressable.dart';
import '../../widgets/modal_launchers.dart';
import '../../widgets/toy_icon.dart';

class CatalogTab extends StatefulWidget {
  const CatalogTab({super.key});

  @override
  State<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<CatalogTab> with TickerProviderStateMixin {
  // Text/tag/inputs block below the image is a fixed height regardless of
  // column width, so the card's aspect ratio has to be derived from the
  // actual column width rather than guessed — otherwise it overflows on
  // narrower screens (see _ToyCard for what this height covers).
  static const double _contentHeight = 150;

  CascadeController? _cascade;
  int _lastCount = -1;

  CascadeController _cascadeFor(int count) {
    if (_cascade == null || _lastCount != count) {
      _cascade?.dispose();
      _cascade = CascadeController(this, itemCount: count);
      _lastCount = count;
    }
    return _cascade!;
  }

  @override
  void dispose() {
    _cascade?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cascade = _cascadeFor(state.toys.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - 40 - 14) / 2;
        final imageHeight = columnWidth * 3 / 4;
        final aspectRatio = columnWidth / (imageHeight + _contentHeight);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  width: double.infinity,
                  child: Pressable(
                    child: ElevatedButton.icon(
                      onPressed: () => showAddToySheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Adicionar brinquedo'),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: aspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => cascade.item(i, pop: true, child: _ToyCard(state: state, toy: state.toys[i])),
                  childCount: state.toys.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ToyCard extends StatelessWidget {
  const _ToyCard({required this.state, required this.toy});
  final AppState state;
  final Toy toy;

  @override
  Widget build(BuildContext context) {
    final avail = state.toyAvailable(toy);
    return Container(
      decoration: BoxDecoration(
        color: toy.ink.tint,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Color(0x242D2B2B), offset: Offset(0, 1), blurRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Pressable(
                    rotateOnHover: true,
                    child: ToyIcon(imageKey: toy.imageKey, ink: toy.ink, size: 46, radius: 3, fill: true),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Pressable(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _confirmRemove(context, state, toy),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.bg.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.accent2_700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toy.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    avail > 0 ? '$avail livre${avail != 1 ? 's' : ''}' : 'todos em uso',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: avail > 0 ? toy.ink.fg : AppColors.accent2_700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniField(
                        label: 'PREÇO R\$',
                        color: toy.ink.fg,
                        initial: toy.price.toStringAsFixed(0),
                        onChanged: (v) {
                          final n = double.tryParse(v);
                          if (n != null) state.updateToyPrice(toy.id, n);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniField(
                        label: 'MINUTOS',
                        color: toy.ink.fg,
                        initial: '${toy.blockMin}',
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) state.updateToyBlock(toy.id, n);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _confirmRemove(BuildContext context, AppState state, Toy toy) {
  final removed = state.removeToy(toy.id);
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        removed
            ? '${toy.name} removido do catálogo.'
            : '${toy.name} tem locações registradas — não dá pra remover.',
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

class _MiniField extends StatefulWidget {
  const _MiniField({
    required this.label,
    required this.color,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_MiniField> createState() => _MiniFieldState();
}

class _MiniFieldState extends State<_MiniField> {
  late final _controller = TextEditingController(text: widget.initial);
  late final _focus = FocusNode()..addListener(_onFocusChange);
  bool _focused = false;

  void _onFocusChange() {
    setState(() => _focused = _focus.hasFocus);
    if (!_focus.hasFocus) widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(fontSize: 9.5, letterSpacing: 0.4, fontWeight: FontWeight.w600, color: widget.color)),
        const SizedBox(height: 3),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border.all(color: _focused ? AppColors.accent : AppColors.text.withValues(alpha: 0.14), width: _focused ? 1.6 : 1),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 13, color: AppColors.text),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            onSubmitted: widget.onChanged,
          ),
        ),
      ],
    );
  }
}
