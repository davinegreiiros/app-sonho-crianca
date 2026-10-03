import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import '../../domain/text_sharer.dart';

/// [TextSharer] real, via `share_plus` (spec 028-relatorio-dono-whatsapp).
/// Só texto — nenhum arquivo, nenhuma permissão nova.
class SharePlusTextSharer implements TextSharer {
  const SharePlusTextSharer();

  @override
  Future<void> share(String text, {Rect? origin}) async {
    await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
  }
}
