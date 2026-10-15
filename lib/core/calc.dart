import 'dart:math' as math;

typedef RowMap = Map<String, dynamic>;

/// Converte "12.5,3" / "12,5" em double; null se invalido.
double? parseNum(String text) {
  final String t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

double? _num(dynamic v) {
  if (v is num) return v.toDouble();
  return null;
}

/// Linhas cujo campo e igual ao valor (arredondado) informado.
List<RowMap> lookupExact(List<RowMap> rows, String field, double x) {
  return rows.where((RowMap r) {
    final double? v = _num(r[field]);
    return v != null && (v - x).abs() < 1e-9;
  }).toList();
}

/// Linha mais proxima do valor, desde que dentro de meio passo da tabela.
/// (As tabelas fetais tem um valor por mm/semana; o app original exigia
/// valor inteiro, aqui o valor e arredondado para a linha mais proxima.)
List<RowMap> lookupNearest(List<RowMap> rows, String field, double x) {
  final List<double> vals = <double>[];
  for (final RowMap r in rows) {
    final double? v = _num(r[field]);
    if (v != null && !vals.contains(v)) vals.add(v);
  }
  if (vals.isEmpty) return <RowMap>[];
  vals.sort();
  double step = double.infinity;
  for (int i = 1; i < vals.length; i++) {
    final double d = vals[i] - vals[i - 1];
    if (d > 1e-9 && d < step) step = d;
  }
  if (step == double.infinity) step = 1;
  double best = vals.first;
  double bestDist = double.infinity;
  for (final double v in vals) {
    final double d = (v - x).abs();
    if (d < bestDist) {
      bestDist = d;
      best = v;
    }
  }
  if (bestDist > step / 2 + 1e-9) return <RowMap>[];
  return lookupExact(rows, field, best);
}

/// Idade gestacional pelo CC (Hadlock): IG(sem) = 8,96 + 0,54*CC + 0,0003*CC^3,
/// com CC em cm. Recebe CC em mm e devolve "Xs+Yd".
String hadlockCC(double ccMm) {
  final double cm = ccMm / 10.0;
  final double ga = 8.96 + 0.54 * cm + 0.0003 * math.pow(cm, 3).toDouble();
  int weeks = ga.floor();
  int days = ((ga - weeks) * 7).round();
  if (days >= 7) {
    weeks += 1;
    days = 0;
  }
  return '${weeks}s+${days}d';
}

/// Idade em meses a partir do valor e da unidade (semanas/dias/meses/anos).
double ageToMonths(double value, String unit) {
  switch (unit) {
    case 'semanas':
      return value / 4.0;
    case 'dias':
      return value / 30.4375;
    case 'anos':
      return value * 12.0;
    default:
      return value;
  }
}

/// Linhas pediatricas cuja faixa [_lo, _hi) contem a idade (em meses).
List<RowMap> matchAge(List<RowMap> rows, double months, {String? sex}) {
  final List<RowMap> out = <RowMap>[];
  for (final RowMap r in rows) {
    final double? lo = _num(r['_lo']);
    final double? hi = _num(r['_hi']);
    if (lo == null || hi == null) continue;
    if (months < lo || months >= hi) continue;
    if (sex != null && r.containsKey('Sexo') && r['Sexo'] != sex) continue;
    out.add(r);
  }
  return out;
}
