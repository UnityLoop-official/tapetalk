// Genera le immagini dell'icona dell'app a partire dal logo (quadretto-bocca).
// Uso: flutter test test/icon_render_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saimon_musix/mouth_logo.dart';

Widget _icon({required double logoSize, required Color? bg}) {
  final purple = ThemeData.dark(useMaterial3: true).colorScheme.primary;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      child: Container(
        width: 1024,
        height: 1024,
        color: bg,
        alignment: Alignment.center,
        // Senza fumetto: a dimensione icona la scritta non si leggerebbe.
        child: MouthLogo(
          phrase: null,
          size: logoSize,
          color: Colors.black,
          background: purple,
        ),
      ),
    ),
  );
}

void main() {
  final purple = ThemeData.dark(useMaterial3: true).colorScheme.primary;

  Future<void> render(WidgetTester t, Widget w, String file) async {
    t.view.physicalSize = const Size(1024, 1024);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(w);
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile(file),
    );
  }

  testWidgets('icona completa', (t) async {
    await render(
      t,
      _icon(logoSize: 720, bg: purple),
      '../assets/icon/icon.png',
    );
  });

  testWidgets('primo piano icona adattiva', (t) async {
    // Le icone adattive mostrano solo il 66% centrale: logo più piccolo.
    await render(
      t,
      _icon(logoSize: 560, bg: Colors.transparent),
      '../assets/icon/foreground.png',
    );
  });

  test('colore', () => print('PURPLE=${purple.toARGB32().toRadixString(16)}'));
}
