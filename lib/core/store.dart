import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'text_utils.dart';

typedef Json = Map<String, dynamic>;

/// Dados, textos e idioma do app. Carrega os JSON de assets sob demanda.
class Store extends ChangeNotifier {
  Store._();

  static const List<String> langs = <String>['pt-BR', 'en', 'es'];
  static const Map<String, String> langNames = <String, String>{
    'pt-BR': 'Português',
    'en': 'English',
    'es': 'Español',
  };
  static const String _prefKey = 'idioma';

  final Map<String, Map<String, String>> _strings = <String, Map<String, String>>{};
  late Json menu;
  late Json tabelas;
  late Json paginas;
  String lang = 'pt-BR';

  final Map<String, Future<Json>> _contentF = <String, Future<Json>>{};
  final Map<String, Future<Json>> _dataF = <String, Future<Json>>{};
  final Map<String, Future<Map<String, Json>>> _manyF = <String, Future<Map<String, Json>>>{};

  static Future<Json> _loadJson(String path) async {
    final String raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Json;
  }

  static Future<Store> load() async {
    final Store s = Store._();
    for (final String l in langs) {
      final Json raw = await _loadJson('assets/strings/$l.json');
      final Map<String, String> m = <String, String>{};
      raw.forEach((String k, dynamic v) {
        if (v is String) m[k] = v;
      });
      s._strings[l] = m;
    }
    s.menu = await _loadJson('assets/app/menu.json');
    s.tabelas = await _loadJson('assets/app/tabelas.json');
    s.paginas = await _loadJson('assets/app/paginas.json');
    s.lang = await _initialLang();
    return s;
  }

  static Future<String> _initialLang() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final String? saved = p.getString(_prefKey);
      if (saved != null && langs.contains(saved)) return saved;
    } catch (_) {}
    final String code = ui.PlatformDispatcher.instance.locale.languageCode;
    if (code == 'es') return 'es';
    if (code == 'en') return 'en';
    return 'pt-BR';
  }

  Future<void> setLang(String l) async {
    if (!langs.contains(l) || l == lang) return;
    lang = l;
    notifyListeners();
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, l);
    } catch (_) {}
  }

  /// Texto de AppResources no idioma atual (com fallback pt-BR, en, chave).
  String t(String? key) {
    if (key == null) return '';
    final String? v = _strings[lang]?[key] ?? _strings['pt-BR']?[key] ?? _strings['en']?[key];
    return cleanText(v ?? key);
  }

  /// Texto de um mapa {idioma: texto} (usado em menu.json).
  String tm(dynamic m) {
    if (m is Map) {
      final dynamic v = m[lang] ?? m['pt-BR'] ?? m['en'];
      return v == null ? '' : cleanText(v.toString());
    }
    return '';
  }

  /// Numero formatado com virgula decimal fora do ingles.
  String fmtNum(dynamic v) {
    if (v == null) return '';
    if (v is int) return v.toString();
    if (v is double) {
      String s = v.toString();
      if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
      return lang == 'en' ? s : s.replaceAll('.', ',');
    }
    return cleanText(v.toString());
  }

  Future<Json> content(String target) =>
      _contentF.putIfAbsent(target, () => _loadJson('assets/content/$target.json'));

  Future<Json> data(String name) =>
      _dataF.putIfAbsent(name, () => _loadJson('assets/data/$name.json'));

  Future<Map<String, Json>> dataMany(List<String> names) {
    return _manyF.putIfAbsent(names.join('|'), () async {
      final Map<String, Json> out = <String, Json>{};
      for (final String n in names) {
        out[n] = await data(n);
      }
      return out;
    });
  }

  Json pageEntry(String page) {
    final dynamic e = paginas[page];
    if (e is Map<String, dynamic>) return e;
    return <String, dynamic>{'kind': 'texto', 'data': <dynamic>[]};
  }
}

/// Disponibiliza o Store na arvore de widgets e reconstroi ao trocar idioma.
class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child})
      : super(notifier: store);

  static Store of(BuildContext context) {
    final StoreScope? scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope nao encontrado');
    return scope!.notifier!;
  }
}
