import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/text_utils.dart';
import 'organ_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _q = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  int _rank(String audience) {
    switch (audience) {
      case 'fetal':
        return 0;
      case 'pediatrico':
        return 1;
      default:
        return 2;
    }
  }

  bool _matches(Store s, Json it, String query) {
    if (normalizeText(s.tm(it['title'])).contains(query)) return true;
    final String? nk = it['noaccents_key'] as String?;
    if (nk != null && normalizeText(s.t(nk)).contains(query)) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String query = normalizeText(_q.text.trim());

    final List<Json> groups = (s.menu['groups'] as List<dynamic>).cast<Json>();
    final List<String> order = (s.menu['order'] as List<dynamic>).cast<String>();

    final List<Widget> children = <Widget>[];
    bool fetalHeaderShown = false;
    for (final String method in order) {
      final Json? g = groups.cast<Json?>().firstWhere(
            (Json? x) => x != null && x['method'] == method,
            orElse: () => null,
          );
      if (g == null) continue;
      final List<Json> filtered = (g['items'] as List<dynamic>)
          .cast<Json>()
          .where((Json it) => query.isEmpty || _matches(s, it, query))
          .toList();
      // Ordem estavel: fetal, pediatrico, adulto (mantem a ordem do app original).
      final List<Json> items = <Json>[];
      for (int r = 0; r <= 2; r++) {
        for (final Json it in filtered) {
          if (_rank(it['audience'] as String) == r) items.add(it);
        }
      }
      if (items.isEmpty) continue;

      final bool isFetal = items.first['audience'] == 'fetal';
      if (isFetal && !fetalHeaderShown) {
        fetalHeaderShown = true;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
          child: Text(s.t('fetal').toUpperCase(),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: cs.primary)),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(s.tm(g['group_title']),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ));
      String? lastAud;
      for (final Json it in items) {
        final String aud = it['audience'] as String;
        if (aud != 'fetal' && _rank(aud) != (lastAud == null ? -1 : _rank(lastAud))) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(aud == 'pediatrico' ? s.t('Pediatria') : s.t('Adultos'),
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          ));
        }
        lastAud = aud;
        children.add(_tile(context, s, it));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _q,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: s.t('busca'),
                  border: InputBorder.none,
                ),
                onChanged: (String _) => setState(() {}),
              )
            : const Text('MedUltra'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_searching) _q.clear();
                _searching = !_searching;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            tooltip: s.t('idioma'),
            onSelected: (String l) => s.setLang(l),
            itemBuilder: (BuildContext c) => <PopupMenuEntry<String>>[
              for (final String l in Store.langs)
                CheckedPopupMenuItem<String>(
                  value: l,
                  checked: s.lang == l,
                  child: Text(Store.langNames[l] ?? l),
                ),
            ],
          ),
        ],
      ),
      body: children.isEmpty
          ? Center(child: Text(s.t('dadosForaAlcance')))
          : ListView(padding: const EdgeInsets.only(bottom: 24), children: children),
    );
  }

  Widget _tile(BuildContext context, Store s, Json it) {
    final String? icon = it['icon'] as String?;
    return ListTile(
      leading: icon == null
          ? const SizedBox(width: 40)
          : Image.asset(
              'assets/icons/$icon',
              width: 40,
              height: 40,
              errorBuilder: (BuildContext c, Object e, StackTrace? st) =>
                  const SizedBox(width: 40, height: 40),
            ),
      title: Text(s.tm(it['title'])),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (BuildContext c) => OrganScreen(item: it),
        ));
      },
    );
  }
}
