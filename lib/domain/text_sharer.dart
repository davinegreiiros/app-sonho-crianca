import 'dart:ui' show Rect;

/// Seam pra "mandar este texto pra fora do app pela folha de
/// compartilhamento do sistema" (spec 028-relatorio-dono-whatsapp). Mesmo
/// molde de [RentalNotifier]: teste injeta um fake que grava o texto, sem
/// platform channel.
abstract class TextSharer {
  /// Abre a folha de compartilhamento com [text]. Quem escolhe o destino
  /// (WhatsApp ou outro) é a pessoa; desistir não é erro.
  ///
  /// [origin]: retângulo (coordenadas globais) do botão que disparou —
  /// obrigatório no iPad, onde a folha abre como popover ancorado nele.
  Future<void> share(String text, {Rect? origin});
}
