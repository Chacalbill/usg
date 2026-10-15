import 'package:flutter/material.dart';

import '../core/store.dart';
import '../widgets/page_body.dart';

/// Pagina de um orgao/medida: abas Tabela, Calculadora, Exame, Tecnica...
class OrganScreen extends StatelessWidget {
  const OrganScreen({super.key, required this.item});

  final Json item;

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final String title = s.tm(item['title']);
    return FutureBuilder<Json>(
      future: s.content(item['target'] as String),
      builder: (BuildContext ctx, AsyncSnapshot<Json> snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: Center(child: Text('${snap.error}')),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final List<Json> tabs = (snap.data!['tabs'] as List<dynamic>).cast<Json>();
        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              bottom: TabBar(
                isScrollable: true,
                tabs: <Widget>[for (final Json t in tabs) Tab(text: pageTitle(s, t))],
              ),
            ),
            body: TabBarView(
              children: <Widget>[for (final Json t in tabs) PageBody(node: t)],
            ),
          ),
        );
      },
    );
  }
}
