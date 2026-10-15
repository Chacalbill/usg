import 'package:flutter/material.dart';

import '../core/store.dart';
import '../widgets/page_body.dart';

/// Subpagina aberta a partir de uma lista (ex.: Utero adulto > Pre-menopausa).
class SubPageScreen extends StatelessWidget {
  const SubPageScreen({super.key, required this.node});

  final Json node;

  @override
  Widget build(BuildContext context) {
    final Store s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle(s, node))),
      body: PageBody(node: node),
    );
  }
}
