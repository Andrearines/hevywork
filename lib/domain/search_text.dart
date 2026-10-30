/// Normalización del texto de búsqueda (RF-1 de la 003): minúsculas, sin
/// acentos (precompuestos o combinantes) y con los espacios colapsados.
///
/// El catálogo es ASCII (verificado al generar el asset), así que basta con
/// normalizar lo que escribe el usuario antes de compararlo con `LIKE`.
String normalizeSearchText(String input) {
  // Latin-1 y algunos latin-extendido a su base ASCII (formas ya en
  // minúscula; `toLowerCase` resuelve las mayúsculas antes).
  const diacritics = <int, int>{
    0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, 0x00E4: 0x61,
    0x00E5: 0x61, // à á â ã ä å → a
    0x00E7: 0x63, // ç → c
    0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65, // è é ê ë → e
    0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69, // ì í î ï → i
    0x00F1: 0x6E, // ñ → n
    0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F, 0x00F5: 0x6F, 0x00F6: 0x6F,
    0x00F8: 0x6F, // ò ó ô õ ö ø → o
    0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75, 0x00FC: 0x75, // ù ú û ü → u
    0x00FD: 0x79, 0x00FF: 0x79, // ý ÿ → y
    0x0153: 0x6F, // œ → o
  };

  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  var pendingSpace = false;
  for (final rune in lower.runes) {
    final isWhitespace =
        rune == 0x20 || rune == 0x9 || rune == 0xa || rune == 0xd;
    if (isWhitespace) {
      pendingSpace = buffer.isNotEmpty;
      continue;
    }
    // Marcas combinantes (secuencia descompuesta, p. ej. e + U+0301).
    if (rune >= 0x300 && rune <= 0x36f) {
      continue;
    }
    if (pendingSpace) {
      buffer.write(' ');
      pendingSpace = false;
    }
    buffer.writeCharCode(diacritics[rune] ?? rune);
  }
  return buffer.toString();
}