/// Builds a static Pix "BR Code" (EMVCo QR Code) payload — the same
/// string a bank app reads from a Pix QR or a pasted "copia e cola".
///
/// Montado 100% localmente (spec 002-seguranca-dados): nenhuma rede
/// envolvida, nenhuma dependência externa faz esse trabalho — é um builder
/// puro (string in, string out) fácil de auditar, já que lida com valor e
/// chave Pix do negócio.
library;

/// One TLV ("tag-length-value") field of the EMV QR Code format: 2-digit
/// tag + 2-digit length (of the UTF-8 byte length of [value]) + value.
String _tlv(String tag, String value) {
  final len = value.length.toString().padLeft(2, '0');
  return '$tag$len$value';
}

/// CRC16-CCITT (poly 0x1021, init 0xFFFF, no final XOR — the "CCITT-FALSE"
/// variant) over [data] — the checksum algorithm the EMV QR Code spec (and
/// so Pix) requires for its final "63" field. Exposed (not just used
/// internally) so it can be tested directly against the standard's known
/// vector without needing a live payload/device.
int crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}

/// Builds the full Pix payload string for a fixed-amount static charge.
///
/// - [merchantName]/[merchantCity]: the receiving business, ASCII only,
///   truncated to the field's max length per spec (25/15 chars) rather
///   than producing an invalid payload.
/// - [pixKey]: CPF/CNPJ/phone/e-mail/random key — just a string here, the
///   BR Code format doesn't encode which kind it is.
/// - [amountCents]: charge amount in whole cents, so there's no floating
///   point in the field that a bank app parses as money.
/// - [txid]: reference id shown back to the payer's bank app; defaults to
///   `***` (Pix's own placeholder for "no specific id").
String buildPixPayload({
  required String merchantName,
  required String merchantCity,
  required String pixKey,
  required int amountCents,
  String txid = '***',
}) {
  String ascii(String s, int maxLen) {
    final stripped = s.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
    return stripped.length > maxLen ? stripped.substring(0, maxLen) : stripped;
  }

  final amount = (amountCents / 100).toStringAsFixed(2);

  final merchantAccountInfo = _tlv('00', 'br.gov.bcb.pix') + _tlv('01', pixKey);
  final additionalData = _tlv('05', txid);

  final withoutCrc = [
    _tlv('00', '01'), // payload format indicator
    _tlv('01', '11'), // point of initiation method: static
    _tlv('26', merchantAccountInfo),
    _tlv('52', '0000'), // merchant category code: unspecified
    _tlv('53', '986'), // currency: BRL
    _tlv('54', amount),
    _tlv('58', 'BR'), // country code
    _tlv('59', ascii(merchantName, 25)),
    _tlv('60', ascii(merchantCity, 15)),
    _tlv('62', additionalData),
    '6304', // CRC tag+length, value appended after computing it
  ].join();

  final crc = crc16Ccitt(withoutCrc).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$withoutCrc$crc';
}
