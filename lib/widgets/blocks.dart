import 'package:flutter/material.dart';

import '../core/store.dart';
import 'data_table_view.dart';

/// Chaves que no app original eram botoes/navegacao e nao fazem parte do conteudo.
const Set<String> _chrome = <String>{
  'voltar',
  'inicio',
  'ok',
  'fechar',
  'erro',
  'calcular',
};

const Set<String> _headingKeys = <String>{
  'preparo',
  'posicionamento',
  'tecnica',
  'exame',
  'medidas',
  'tabelas',
  'referencias',
  'legendas',
};

final RegExp _cellRe = RegExp(r'^(.*?)L(\d+)C(\d+)$');

bool _isBodyPrefix(String k) {
  return k.startsWith('preparo') ||
      k.startsWith('posicionamento') ||
      k.startsWith('tecnica') ||
      k.startsWith('texto');
}

/// Monta os widgets de uma pagina a partir dos blocos extraidos do app original.
///
/// - [data]: tabelas de dados (para paginas "tabela" dirigidas por XML).
/// - [skip]: chaves de interface a ignorar (campos/botoes de calculadoras).
List<Widget> buildBlocks(
  BuildContext context,
  Store s,
  Json node,
  Json entry, {
  Map<String, Json>? data,
  Set<String> skip = const <String>{},
}) {
  final List<Map<String, dynamic>> blocks =
      (node['blocks'] as List<dynamic>).cast<Map<String, dynamic>>();
  final String kind = (entry['kind'] as String?) ?? 'texto';
  final List<String> dataNames =
      ((entry['data'] as List<dynamic>?) ?? <dynamic>[]).cast<String>();
  final bool dataDriven = kind == 'tabela' && dataNames.isNotEmpty && data != null;
  final bool skipGrids = dataDriven || kind == 'calc';

  final Map<String, List<List<String?>>> grids = <String, List<List<String?>>>{};
  for (final dynamic t in (node['tables'] as List<dynamic>)) {
    final Map<String, dynamic> tm = t as Map<String, dynamic>;
    grids[tm['prefix'] as String] = (tm['rows'] as List<dynamic>)
        .map((dynamic r) => (r as List<dynamic>).map((dynamic c) => c as String?).toList())
        .toList();
  }

  final List<Widget> pre = <Widget>[];
  final List<Widget> asts = <Widget>[];
  final List<Widget> refs = <Widget>[];
  final Set<String> renderedGrids = <String>{};

  for (final Map<String, dynamic> b in blocks) {
    if (b.containsKey('img')) {
      final String file = b['img'] as String;
      // Icones de navegacao do app original (setas, home) nao sao conteudo.
      if (file.startsWith('ic_')) continue;
      pre.add(_ImageBlock(file: file));
      continue;
    }
    final String? k = b['k'] as String?;
    if (k == null || skip.contains(k) || _chrome.contains(k)) continue;

    final RegExpMatch? m = _cellRe.firstMatch(k);
    if (m != null) {
      if (skipGrids) continue;
      final String p = m.group(1)!;
      if (renderedGrids.add(p) && grids.containsKey(p)) {
        pre.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GridTable(rows: grids[p]!),
        ));
      }
      continue;
    }

    final String text = s.t(k).trim();
    if (text.isEmpty) continue;
    if (k.startsWith('ref')) {
      refs.add(_note(context, text, italic: true));
    } else if (k.startsWith('ast')) {
      asts.add(_note(context, text));
    } else {
      pre.add(_textBlock(context, k, text));
    }
  }

  final List<Widget> out = <Widget>[...pre];
  if (dataDriven) {
    for (final String name in dataNames) {
      final Json? d = data?[name];
      final dynamic spec = s.tabelas[name];
      if (d == null || spec == null) continue;
      if (dataNames.length > 1) {
        final String label =
            name.endsWith('Menina') ? s.t('feminino') : (name.endsWith('Menino') ? s.t('masculino') : '');
        if (label.isNotEmpty) {
          out.add(Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ));
        }
      }
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DataTableView(
          spec: spec as Json,
          rows: (d['rows'] as List<dynamic>).cast<Map<String, dynamic>>(),
        ),
      ));
    }
  }
  out.addAll(asts);
  out.addAll(refs);
  return out;
}

Widget _note(BuildContext context, String text, {bool italic = false}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

Widget _textBlock(BuildContext context, String k, String text) {
  final ThemeData th = Theme.of(context);
  if (k.startsWith('legenda') || k.endsWith('Legenda')) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12, fontStyle: FontStyle.italic, color: th.colorScheme.onSurfaceVariant)),
    );
  }
  final bool heading = _headingKeys.contains(k) || k.startsWith('header') || k.startsWith('planoCorte');
  if (heading) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(text,
          style: th.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: th.colorScheme.primary)),
    );
  }
  if (text.length > 70 || text.contains('\n') || _isBodyPrefix(k)) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
    );
  }
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 2),
    child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
  );
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.file});

  final String file;

  @override
  Widget build(BuildContext context) {
    final String path = 'assets/images/$file';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (BuildContext ctx) => Dialog(
              insetPadding: const EdgeInsets.all(8),
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.asset(path, fit: BoxFit.contain),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (BuildContext c, Object e, StackTrace? st) => Container(
              height: 80,
              alignment: Alignment.center,
              color: Theme.of(c).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
