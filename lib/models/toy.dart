import 'package:flutter/material.dart' show Color;

import '../theme/app_colors.dart';

/// Fixed set of toy categories — every toy (seed or user-added) declares
/// one, shown as a tag on its catalog card. Closed list decided in
/// `specs/003-catalogo-tickets-tipo/spec.md`.
enum ToyCategory { eletrico, inflavel, passeio, aquatico, radiocontrole, outro }

extension ToyCategoryLabel on ToyCategory {
  String get label => switch (this) {
        ToyCategory.eletrico => 'Elétrico',
        ToyCategory.inflavel => 'Inflavel',
        ToyCategory.passeio => 'Passeio',
        ToyCategory.aquatico => 'Aquático',
        ToyCategory.radiocontrole => 'Rádio-controle',
        ToyCategory.outro => 'Outro',
      };
}

/// Phosphor-duotone icon + fixed "tinta" per category (design source:
/// `specs/007-revisao-design-v3/`, artboard 1b) — one ink per category,
/// not to be confused with [ToyInk], which is a CMY color picked per
/// individual toy. Mapping: amarelo = energia, magenta = infla/rádio,
/// ciano = roda/água, neutro = Outro.
extension ToyCategoryIcon on ToyCategory {
  String get iconAsset => 'assets/icons/category/$name.svg';

  Color get iconFg => switch (this) {
        ToyCategory.eletrico => AppColors.yellowFg,
        ToyCategory.inflavel => AppColors.accent2_700,
        ToyCategory.radiocontrole => AppColors.accent2_700,
        ToyCategory.passeio => AppColors.accent700,
        ToyCategory.aquatico => AppColors.accent700,
        ToyCategory.outro => AppColors.neutralFg,
      };

  Color get iconTint => switch (this) {
        ToyCategory.eletrico => AppColors.yellowTint,
        ToyCategory.inflavel => AppColors.accent2_200,
        ToyCategory.radiocontrole => AppColors.accent2_200,
        ToyCategory.passeio => AppColors.accent200,
        ToyCategory.aquatico => AppColors.accent200,
        ToyCategory.outro => AppColors.surface,
      };
}

/// A rentable toy in the catalog.
class Toy {
  Toy({
    required this.id,
    required this.name,
    required this.qty,
    required this.blockMin,
    required this.price,
    required this.ink,
    required this.imageKey,
    required this.category,
  });

  final String id;
  final String name;
  final int qty;
  final int blockMin;
  final double price;
  final ToyInk ink;
  final ToyCategory category;

  /// Which illustration (`assets/images/toy-<imageKey>.png`) represents
  /// this toy — picked from [kToyIconOptions], independent of [id] so
  /// two custom toys can share the same picture.
  final String imageKey;

  Toy copyWith({int? blockMin, double? price}) => Toy(
        id: id,
        name: name,
        qty: qty,
        blockMin: blockMin ?? this.blockMin,
        price: price ?? this.price,
        ink: ink,
        imageKey: imageKey,
        category: category,
      );
}

/// Seed catalog, mirroring `TOYS_INIT` in the original design script.
final List<Toy> kInitialToys = [
  Toy(
      id: 'carrinho',
      name: 'Carrinho Elétrico c/ Controle',
      qty: 2,
      blockMin: 15,
      price: 10,
      ink: ToyInk.cyan,
      imageKey: 'carrinho',
      category: ToyCategory.eletrico),
  Toy(
      id: 'cama',
      name: 'Cama Elástica',
      qty: 1,
      blockMin: 30,
      price: 15,
      ink: ToyInk.magenta,
      imageKey: 'cama',
      category: ToyCategory.inflavel),
  Toy(
      id: 'pula',
      name: 'Pula-Pula',
      qty: 2,
      blockMin: 30,
      price: 12,
      ink: ToyInk.yellow,
      imageKey: 'pula',
      category: ToyCategory.inflavel),
  Toy(
      id: 'piscina',
      name: 'Piscina de Bolinha',
      qty: 1,
      blockMin: 20,
      price: 10,
      ink: ToyInk.cyan,
      imageKey: 'piscina',
      category: ToyCategory.aquatico),
  Toy(
      id: 'patinete',
      name: 'Patinete Elétrico',
      qty: 2,
      blockMin: 15,
      price: 12,
      ink: ToyInk.magenta,
      imageKey: 'patinete',
      category: ToyCategory.eletrico),
];

/// One illustration option offered in the "novo brinquedo" icon picker.
class ToyIconOption {
  const ToyIconOption(this.key, this.label);
  final String key;
  final String label;
  String get asset => 'assets/images/toy-$key.png';
}

const kToyIconOptions = <ToyIconOption>[
  ToyIconOption('carrinho', 'Carrinho'),
  ToyIconOption('cama', 'Cama elástica'),
  ToyIconOption('pula', 'Pula-pula'),
  ToyIconOption('piscina', 'Piscina'),
  ToyIconOption('patinete', 'Patinete'),
  ToyIconOption('kart', 'Kart'),
  ToyIconOption('cavalinho', 'Cavalinho'),
  ToyIconOption('quadriciclo', 'Quadriciclo'),
  ToyIconOption('tobogan', 'Tobogã'),
  ToyIconOption('touro', 'Touro mecânico'),
  ToyIconOption('trenzinho', 'Trenzinho'),
  ToyIconOption('outro', 'Outro'),
];
