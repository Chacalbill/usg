/// Remove acentos e converte para minusculas (usado na busca do Home).
String normalizeText(String input) {
  const String from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const String to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final StringBuffer out = StringBuffer();
  for (final int rune in input.runes) {
    final String ch = String.fromCharCode(rune);
    final int i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString().toLowerCase();
}

/// Converte CRLF/CR em LF para exibir textos de recursos do app original.
String cleanText(String input) {
  return input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
