import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/store.dart';

/// Tabela de referencia dirigida por dados (cabecalho + linhas de um JSON).
class DataTableView extends StatelessWidget {
  const DataTableView({super.key, required this.spec, required this.rows});

  final Json spec;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Map<String, dynamic>> cols =
        (spec['cols'] as List<dynamic>).cast<Map<String, dynamic>>();
    final List<List<Map<String, dynamic>>> head = (spec['head'] as List<dynamic>)
        .map((dynamic r) => (r as List<dynamic>).cast<Map<String, dynamic>>())
        .toList();
    final int n = cols.length;
    final double minW = n * 78.0;

    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints bc) {
      final double w = bc.maxWidth.isFinite ? math.max(bc.maxWidth, minW) : minW;
      final List<Widget> lines = <Widget>[_header(s, cs, head, n)];
      for (int i = 0; i < rows.length; i++) {
        lines.add(_dataRow(s, cs, cols, rows[i], i));
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: w, child: Column(children: lines)),
      );
    });
  }

  Widget _headCell(Store s, ColorScheme cs, Map<String, dynamic> c) {
    final String text = c['k'] != null ? s.t(c['k'] as String) : (c['t'] as String? ?? '');
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
      ),
    );
  }

  int _span(Map<String, dynamic> c) => (c['span'] as num?)?.toInt() ?? 1;

  Widget _header(Store s, ColorScheme cs, List<List<Map<String, dynamic>>> head, int n) {
    if (head.isEmpty) {
      return const SizedBox.shrink();
    }
    // Cabecalho de dois niveis com a primeira celula ocupando as duas linhas.
    if (head.length == 2 &&
        head[0].isNotEmpty &&
        ((head[0][0]['rows'] as num?)?.toInt() ?? 1) == 2) {
      final Map<String, dynamic> first = head[0][0];
      final int firstSpan = _span(first);
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(flex: firstSpan, child: _headCell(s, cs, first)),
            Expanded(
              flex: math.max(1, n - firstSpan),
              child: Column(
                children: <Widget>[
                  Row(children: <Widget>[
                    for (final Map<String, dynamic> c in head[0].skip(1))
                      Expanded(flex: _span(c), child: _headCell(s, cs, c)),
                  ]),
                  Row(children: <Widget>[
                    for (final Map<String, dynamic> c in head[1])
                      Expanded(flex: _span(c), child: _headCell(s, cs, c)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final List<Map<String, dynamic>> r in head)
          if (r.isNotEmpty)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final Map<String, dynamic> c in r)
                    Expanded(flex: _span(c), child: _headCell(s, cs, c)),
                ],
              ),
            ),
      ],
    );
  }

  String _format(Store s, Map<String, dynamic> col, Map<String, dynamic> row) {
    final List<dynamic> f = col['f'] as List<dynamic>;
    final String fmt = (col['fmt'] as String?) ?? 'auto';
    final String field = f.first as String;
    switch (fmt) {
      case 'sd':
        final dynamic wk = row['IGSemanas'];
        final dynamic dy = row['IGDias'];
        if (wk == null) return '';
        return '${s.fmtNum(wk)}s+${s.fmtNum(dy ?? 0)}d';
      case 'range':
        final String raw = (row[field] ?? '').toString();
        final RegExpMatch? rm = RegExp(r'^(\d+)-(\d+)_([ma])$').firstMatch(raw);
        if (rm == null) return raw;
        final String unit = rm.group(3) == 'm' ? s.t('mesesTabelas2') : s.t('anosTabelas2');
        return '${rm.group(1)}-${rm.group(2)}$unit';
      case 'sex':
        final String sx = (row[field] ?? '').toString();
        if (sx == 'M') return s.t('masculino');
        if (sx == 'F') return s.t('feminino');
        return sx;
      case 'loc':
        final String suffix = s.lang == 'en' ? 'En' : (s.lang == 'es' ? 'Es' : '');
        final dynamic lv = suffix.isEmpty ? row[field] : (row['$field$suffix'] ?? row[field]);
        return s.fmtNum(lv);
      default:
        return s.fmtNum(row[field]);
    }
  }

  Widget _dataRow(Store s, ColorScheme cs, List<Map<String, dynamic>> cols,
      Map<String, dynamic> row, int index) {
    final Color bg = index.isEven ? cs.surface : cs.surfaceContainerHighest;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final Map<String, dynamic> c in cols)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: cs.outlineVariant, width: 0.5),
                ),
                child: Text(
                  _format(s, c, row),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tabela montada a partir de chaves de texto (grade LxCy do app original).
class GridTable extends StatelessWidget {
  const GridTable({super.key, required this.rows});

  final List<List<String?>> rows;

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    int cols = 0;
    for (final List<String?> r in rows) {
      cols = math.max(cols, r.length);
    }
    if (cols == 0) return const SizedBox.shrink();
    final double screenW = MediaQuery.of(context).size.width - 32;
    final double w = math.max(screenW, cols * 110.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: w,
        child: Table(
          border: TableBorder.all(color: cs.outlineVariant, width: 0.5),
          children: <TableRow>[
            for (int i = 0; i < rows.length; i++)
              TableRow(
                decoration: BoxDecoration(
                    color: i.isEven ? cs.surface : cs.surfaceContainerHighest),
                children: <Widget>[
                  for (int j = 0; j < cols; j++)
                    Padding(
                      padding: const EdgeInsets.all(7),
                      child: Text(
                        j < rows[i].length && rows[i][j] != null ? s.t(rows[i][j]) : '',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: j == 0 ? FontWeight.w600 : FontWeight.normal),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
