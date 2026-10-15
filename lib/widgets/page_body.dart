import 'package:flutter/material.dart';

import '../core/store.dart';
import '../screens/sub_page_screen.dart';
import 'blocks.dart';
import 'calculators.dart';

/// Titulo de uma aba/pagina (usa a chave de titulo do app original).
String pageTitle(Store s, Json node) {
  final String? key = node['title_key'] as String?;
  if (key != null) {
    final String t = s.t(key);
    if (t.isNotEmpty) return t;
  }
  final String page = (node['page'] as String?) ?? '';
  if (page.contains('Tabela')) return s.t('tabelas');
  if (page.endsWith('Calculadora') || page.endsWith('Principal')) return s.t('calcularMedidas');
  if (page.contains('Exame')) return s.t('exame');
  if (page.contains('Tecnica')) return s.t('tecnica');
  return page;
}

/// Conteudo de uma pagina do app original, conforme o tipo da pagina.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.node});

  final Json node;

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final String page = node['page'] as String;
    final Json entry = s.pageEntry(page);
    final String kind = (entry['kind'] as String?) ?? 'texto';

    if (kind == 'lista') {
      final List<Json> subs =
          ((node['subpages'] as List<dynamic>?) ?? <dynamic>[]).cast<Json>();
      return ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          for (final Json sub in subs)
            Card(
              child: ListTile(
                title: Text(pageTitle(s, sub)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (BuildContext c) => SubPageScreen(node: sub),
                  ));
                },
              ),
            ),
        ],
      );
    }

    final List<String> dataNames =
        ((entry['data'] as List<dynamic>?) ?? <dynamic>[]).cast<String>();
    final bool needsData = kind == 'tabela' && dataNames.isNotEmpty;

    if (!needsData) {
      return _scroll(_content(context, s, kind, entry, null));
    }
    return FutureBuilder<Map<String, Json>>(
      future: s.dataMany(dataNames),
      builder: (BuildContext ctx, AsyncSnapshot<Map<String, Json>> snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return _scroll(_content(ctx, s, kind, entry, snap.data));
      },
    );
  }

  Widget _scroll(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: children,
    );
  }

  List<Widget> _content(
      BuildContext context, Store s, String kind, Json entry, Map<String, Json>? data) {
    if (kind == 'calc') {
      return <Widget>[
        FetalCalculator(cfg: entry['cfg'] as Json),
        ...buildBlocks(context, s, node, entry, skip: calcUiKeys),
      ];
    }
    if (kind == 'ped') {
      return <Widget>[
        PedCalculator(cfg: entry['cfg'] as Json),
        ...buildBlocks(context, s, node, entry, skip: calcUiKeys),
      ];
    }
    return buildBlocks(context, s, node, entry, data: data);
  }
}
