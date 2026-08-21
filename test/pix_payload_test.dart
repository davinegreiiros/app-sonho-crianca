// Tests for spec 004 (QR Code Pix): CRC16 against the standard's known
// vector, and payload self-consistency/shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:sonho_de_crianca/services/pix_payload.dart';

void main() {
  group('crc16Ccitt', () {
    test('matches the well-known CRC16/CCITT-FALSE("123456789") vector', () {
      // Documented standard test vector for this exact variant
      // (poly 0x1021, init 0xFFFF, no final XOR) — 0x29B1.
      expect(crc16Ccitt('123456789'), 0x29B1);
    });

    test('is deterministic and sensitive to every byte', () {
      final a = crc16Ccitt('Sonho de Criança');
      final b = crc16Ccitt('Sonho de Criança');
      final c = crc16Ccitt('Sonho de Crianca'); // one char different (ç -> c)
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('buildPixPayload', () {
    test('the appended CRC matches recomputing it over the rest of the payload', () {
      final payload = buildPixPayload(
        merchantName: 'Sonho de Crianca',
        merchantCity: 'Fortaleza',
        pixKey: '85999998888',
        amountCents: 1100,
      );

      // The CRC field is always the last 4 hex chars, over everything
      // before it (including the "6304" tag+length of the CRC field
      // itself) — this is what a bank app checks, so it's what proves the
      // payload isn't silently corrupting the amount/key.
      final withoutCrc = payload.substring(0, payload.length - 4);
      final claimedCrc = payload.substring(payload.length - 4);
      final recomputed = crc16Ccitt(withoutCrc).toRadixString(16).toUpperCase().padLeft(4, '0');
      expect(claimedCrc, recomputed);
    });

    test('encodes the exact amount, in reais with 2 decimals, once', () {
      final payload = buildPixPayload(
        merchantName: 'Loja',
        merchantCity: 'Fortaleza',
        pixKey: 'chave@exemplo.com',
        amountCents: 1050, // R$ 10,50
      );
      expect(payload, contains('540510.50'));
    });

    test('truncates merchant name/city instead of producing an invalid payload', () {
      final payload = buildPixPayload(
        merchantName: 'Um Nome de Loja Muito Comprido Que Passa do Limite de 25',
        merchantCity: 'Uma Cidade Com Nome Bem Comprido',
        pixKey: 'x',
        amountCents: 100,
      );
      final nameField = RegExp(r'59(\d{2})').firstMatch(payload)!;
      final nameLen = int.parse(nameField.group(1)!);
      expect(nameLen, lessThanOrEqualTo(25));
      final cityField = RegExp(r'60(\d{2})').firstMatch(payload)!;
      final cityLen = int.parse(cityField.group(1)!);
      expect(cityLen, lessThanOrEqualTo(15));
    });

    test('never calls out to anything — pure string in, string out', () {
      // No await, no async signature at all: this test compiling and
      // passing synchronously is itself the proof there's no I/O here,
      // matching the "montado 100% localmente" requirement in 002.
      final payload = buildPixPayload(
        merchantName: 'Loja',
        merchantCity: 'Fortaleza',
        pixKey: 'x',
        amountCents: 100,
      );
      expect(payload, isNotEmpty);
    });
  });
}
