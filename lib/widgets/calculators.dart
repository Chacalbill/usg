import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/store.dart';
import 'data_table_view.dart';

/// Chaves de interface das calculadoras (nao entram como conteudo da pagina).
const Set<String> calcUiKeys = <String>{
  'calcularMedidas',
  'idade',
  'sexo',
  'calcular',
  'faixaEtaria',
  'indiceVolumetrico',
  'anos',
  'meses',
  'semanas',
  'dias',
  'uteroDiametro',
  'uteroVolume',
  'dadosForaAlcance',
  'mm',
  'medidas',
  'tresDiametros',
  'diametro1',
  'diametro2',
  'diametro3',
  'dmsg',
};

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

Widget _cardWrap(BuildContext context, String? title, List<Widget> children) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ...children,
        ],
      ),
    ),
  );
}

Widget _errorText(BuildContext context, String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

// ---------------------------------------------------------------------------
// Calculadoras fetais
// ---------------------------------------------------------------------------

class FetalCalculator extends StatelessWidget {
  const FetalCalculator({super.key, required this.cfg});

  final Json cfg;

  List<Json> _sections() {
    final String mode = cfg['mode'] as String;
    if (mode == 'dbp') {
      return (cfg['sections'] as List<dynamic>).cast<Json>();
    }
    return <Json>[
      <String, dynamic>{
        'mode': mode,
        'data': cfg['data'],
        'field': cfg['field'],
        'sigla': cfg['sigla'],
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final List<Json> sections = _sections();
    final bool isDbp = cfg['mode'] == 'dbp';
    final List<String> names = sections.map((Json e) => e['data'] as String).toList();
    return FutureBuilder<Map<String, Json>>(
      future: s.dataMany(names),
      builder: (BuildContext ctx, AsyncSnapshot<Map<String, Json>> snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final Map<String, Json> data = snap.data!;
        return Column(
          children: <Widget>[
            for (final Json sec in sections)
              _FetalSection(
                key: ValueKey<String>('${sec['data']}'),
                mode: isDbp ? 'measure' : (sec['mode'] as String),
                dataName: sec['data'] as String,
                field: sec['field'] as String?,
                siglaKey: sec['sigla'] as String?,
                formula: sec['formula'] as String?,
                data: data[sec['data'] as String]!,
                showTitle: isDbp,
              ),
          ],
        );
      },
    );
  }
}

class _FetalSection extends StatefulWidget {
  const _FetalSection({
    super.key,
    required this.mode,
    required this.dataName,
    required this.field,
    required this.siglaKey,
    required this.formula,
    required this.data,
    required this.showTitle,
  });

  final String mode; // measure | ig | igsd | sg
  final String dataName;
  final String? field;
  final String? siglaKey;
  final String? formula;
  final Json data;
  final bool showTitle;

  @override
  State<_FetalSection> createState() => _FetalSectionState();
}

class _FetalSectionState extends State<_FetalSection> {
  final TextEditingController _a = TextEditingController();
  final TextEditingController _b = TextEditingController();
  final TextEditingController _c = TextEditingController();
  int _sgType = 0;
  String? _error;
  List<Map<String, dynamic>>? _result;
  String? _info;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _rows =>
      (widget.data['rows'] as List<dynamic>).cast<Map<String, dynamic>>();

  void _calculate(Store s) {
    String? err;
    List<Map<String, dynamic>> res = <Map<String, dynamic>>[];
    String? info;
    final String digiteO = s.t('digiteO');
    switch (widget.mode) {
      case 'ig':
        final double? wIg = parseNum(_a.text);
        if (wIg == null) {
          err = '${s.t('camposObrigatorios')}\n${s.t('digiteIG')}';
        } else {
          res = lookupExact(_rows, 'IGSemanas', wIg.floorToDouble());
        }
        break;
      case 'igsd':
        final double? wSd = parseNum(_a.text);
        final double dSd = parseNum(_b.text) ?? 0;
        if (wSd == null) {
          err = '${s.t('camposObrigatorios')}\n${s.t('digiteIG')}';
        } else {
          res = lookupExact(_rows, 'IGSemanas', wSd.floorToDouble());
          res = lookupExact(res, 'IGDias', dSd.floorToDouble());
        }
        break;
      case 'sg':
        double? vSg;
        if (_sgType == 0) {
          vSg = parseNum(_a.text);
          if (vSg == null) err = '${s.t('camposObrigatorios')}\n$digiteO ${s.t('dmsg')}';
        } else {
          final double? d1 = parseNum(_a.text);
          final double? d2 = parseNum(_b.text);
          final double? d3 = parseNum(_c.text);
          if (d1 == null) {
            err = '${s.t('camposObrigatorios')}\n$digiteO ${s.t('diametro1')}';
          } else if (d2 == null) {
            err = '${s.t('camposObrigatorios')}\n$digiteO ${s.t('diametro2')}';
          } else if (d3 == null) {
            err = '${s.t('camposObrigatorios')}\n$digiteO ${s.t('diametro3')}';
          } else {
            vSg = ((d1 + d2 + d3) / 3).roundToDouble();
          }
        }
        if (vSg != null) {
          info = '${s.t('dmsg')}: ${s.fmtNum(vSg)} ${s.t('mm')}';
          res = lookupNearest(_rows, widget.field ?? 'DMSG', vSg);
        }
        break;
      default:
        final double? vDef = parseNum(_a.text);
        final String sigla = s.t(widget.siglaKey);
        if (vDef == null) {
          err = '${s.t('camposObrigatorios')}\n$digiteO $sigla';
        } else {
          res = lookupNearest(_rows, widget.field ?? '', vDef);
          if (widget.formula == 'hadlockCC') {
            info = 'IG (s+d): ${hadlockCC(vDef)}';
          }
        }
    }
    setState(() {
      _error = err;
      _info = info;
      _result = err == null ? res : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final List<Widget> kids = <Widget>[];
    String? title;
    switch (widget.mode) {
      case 'ig':
        kids.add(_NumField(controller: _a, label: s.t('semanas')));
        break;
      case 'igsd':
        kids.add(_NumField(controller: _a, label: s.t('semanas')));
        kids.add(_NumField(controller: _b, label: s.t('dias')));
        break;
      case 'sg':
        kids.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButton<int>(
            value: _sgType,
            isExpanded: true,
            items: <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(value: 0, child: Text(s.t('dmsg'))),
              DropdownMenuItem<int>(value: 1, child: Text(s.t('tresDiametros'))),
            ],
            onChanged: (int? v) {
              setState(() {
                _sgType = v ?? 0;
                _result = null;
                _error = null;
              });
            },
          ),
        ));
        if (_sgType == 0) {
          kids.add(_NumField(controller: _a, label: '${s.t('dmsg')} (${s.t('mm')})'));
        } else {
          kids.add(_NumField(controller: _a, label: '${s.t('diametro1')} (${s.t('mm')})'));
          kids.add(_NumField(controller: _b, label: '${s.t('diametro2')} (${s.t('mm')})'));
          kids.add(_NumField(controller: _c, label: '${s.t('diametro3')} (${s.t('mm')})'));
        }
        break;
      default:
        final String sigla = s.t(widget.siglaKey);
        title = widget.showTitle ? sigla : null;
        kids.add(_NumField(controller: _a, label: '$sigla (${s.t('mm')})'));
    }
    kids.add(FilledButton(onPressed: () => _calculate(s), child: Text(s.t('calcular'))));
    if (_error != null) kids.add(_errorText(context, _error!));
    if (_info != null) {
      kids.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_info!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ));
    }
    if (_result != null) {
      if (_result!.isEmpty) {
        if (_info == null || widget.formula == null) {
          kids.add(_errorText(context, s.t('dadosForaAlcance')));
        }
      } else {
        kids.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DataTableView(spec: s.tabelas[widget.dataName] as Json, rows: _result!),
        ));
      }
    }
    return _cardWrap(context, title ?? s.t('calcularMedidas'), kids);
  }
}

// ---------------------------------------------------------------------------
// Calculadoras pediatricas
// ---------------------------------------------------------------------------

class PedCalculator extends StatelessWidget {
  const PedCalculator({super.key, required this.cfg});

  final Json cfg;

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final List<Json> sections = (cfg['sections'] as List<dynamic>).cast<Json>();
    final List<String> names = <String>[];
    for (final Json sec in sections) {
      if (sec['data'] != null) names.addAll((sec['data'] as List<dynamic>).cast<String>());
      if (sec['options'] != null) {
        for (final dynamic o in (sec['options'] as List<dynamic>)) {
          names.add((o as Map<String, dynamic>)['data'] as String);
        }
      }
    }
    return FutureBuilder<Map<String, Json>>(
      future: s.dataMany(names),
      builder: (BuildContext ctx, AsyncSnapshot<Map<String, Json>> snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          children: <Widget>[
            for (int i = 0; i < sections.length; i++)
              _PedSection(
                key: ValueKey<int>(i),
                sec: sections[i],
                data: snap.data!,
                single: sections.length == 1,
              ),
          ],
        );
      },
    );
  }
}

class _PedSection extends StatefulWidget {
  const _PedSection({super.key, required this.sec, required this.data, required this.single});

  final Json sec;
  final Map<String, Json> data;
  final bool single;

  @override
  State<_PedSection> createState() => _PedSectionState();
}

class _PedSectionState extends State<_PedSection> {
  final TextEditingController _age = TextEditingController();
  late String _unit;
  String _sex = 'M';
  int _option = 0;
  String? _error;
  List<Map<String, dynamic>>? _result;
  String? _resultData;

  @override
  void initState() {
    super.initState();
    _unit = (widget.sec['units'] as List<dynamic>).first as String;
  }

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  String _dataName() {
    if (widget.sec['options'] != null) {
      final List<dynamic> opts = widget.sec['options'] as List<dynamic>;
      return (opts[_option] as Map<String, dynamic>)['data'] as String;
    }
    return (widget.sec['data'] as List<dynamic>).first as String;
  }

  void _calculate(Store s) {
    final double? v = parseNum(_age.text);
    if (v == null || v < 0) {
      setState(() {
        _error = s.t('digiteIdade');
        _result = null;
      });
      return;
    }
    final String name = _dataName();
    final List<Map<String, dynamic>> rows =
        (widget.data[name]!['rows'] as List<dynamic>).cast<Map<String, dynamic>>();
    final bool useSex = widget.sec['sex'] == true;
    final List<Map<String, dynamic>> res =
        matchAge(rows, ageToMonths(v, _unit), sex: useSex ? _sex : null);
    setState(() {
      _error = null;
      _result = res;
      _resultData = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    final List<String> units = (widget.sec['units'] as List<dynamic>).cast<String>();
    final String? titleKey = widget.sec['title'] as String?;
    final List<Widget> kids = <Widget>[];

    if (widget.sec['options'] != null) {
      final List<dynamic> opts = widget.sec['options'] as List<dynamic>;
      kids.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButton<int>(
          value: _option,
          isExpanded: true,
          items: <DropdownMenuItem<int>>[
            for (int i = 0; i < opts.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(s.t((opts[i] as Map<String, dynamic>)['label'] as String)),
              ),
          ],
          onChanged: (int? v) {
            setState(() {
              _option = v ?? 0;
              _result = null;
            });
          },
        ),
      ));
    }
    if (widget.sec['sex'] == true) {
      kids.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButton<String>(
          value: _sex,
          isExpanded: true,
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'M', child: Text(s.t('masculino'))),
            DropdownMenuItem<String>(value: 'F', child: Text(s.t('feminino'))),
          ],
          onChanged: (String? v) {
            setState(() {
              _sex = v ?? 'M';
              _result = null;
            });
          },
        ),
      ));
    }
    kids.add(Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: _NumField(controller: _age, label: s.t('idade'))),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: units.length == 1
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(s.t(units.first), style: const TextStyle(fontSize: 16)),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DropdownButton<String>(
                    value: _unit,
                    isExpanded: true,
                    items: <DropdownMenuItem<String>>[
                      for (final String u in units)
                        DropdownMenuItem<String>(value: u, child: Text(s.t(u))),
                    ],
                    onChanged: (String? v) {
                      setState(() {
                        _unit = v ?? units.first;
                        _result = null;
                      });
                    },
                  ),
                ),
        ),
      ],
    ));
    kids.add(FilledButton(onPressed: () => _calculate(s), child: Text(s.t('calcular'))));
    if (_error != null) kids.add(_errorText(context, _error!));
    if (_result != null) {
      if (_result!.isEmpty) {
        kids.add(_errorText(context, s.t('dadosForaAlcance')));
      } else if (_resultData != null) {
        kids.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DataTableView(spec: s.tabelas[_resultData] as Json, rows: _result!),
        ));
      }
    }
    final String title = titleKey != null ? s.t(titleKey) : s.t('calcularMedidas');
    return _cardWrap(context, title, kids);
  }
}
