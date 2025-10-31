// Placeholder replacement for the corrupted `list_page.dart`.
// The real list UI lives in `list_page_clean.dart` and is wired in main.dart.

import 'package:flutter/material.dart';

class ListPageStub extends StatelessWidget {
  const ListPageStub({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('旧 list_page は置換済み (stub)。ListPageClean を使用しています。')),
    );
  }
}

