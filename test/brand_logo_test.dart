import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/brand/gude_logo.dart';
import 'package:gudeteknolojiweb/brand/gude_logo_data.dart';
import 'package:gudeteknolojiweb/brand/logo_model.dart';
import 'package:gudeteknolojiweb/pages/nav_model.dart';
import 'package:gudeteknolojiweb/theme.dart';

import 'helpers/app.dart';
import 'helpers/shot.dart';

Iterable<LogoShape> get _all => [...kLogoShadow, ...kLogoLeaves, ...kLogoWordmark, ...kLogoTagline];

/// [GudeLogo]'yu şeffaf zeminde çizip RGBA baytlarını döndürür (alfa kanalı sınanabilsin diye).
Future<({Uint8List rgba, int width, int height})> _paintAlpha(WidgetTester tester, Brightness brightness, double height) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    testApp(
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: key, child: GudeLogo(height: height)),
      ),
      brightness: brightness,
    ),
  );
  // MaterialApp tema değişimini animasyonla yapar; bitmeden ölçülürse önceki temanın renkleri okunur.
  await tester.pump(const Duration(seconds: 1));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ui.Image image;
  late ByteData data;
  await tester.runAsync(() async {
    image = await boundary.toImage();
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  });
  return (rgba: data.buffer.asUint8List(), width: image.width, height: image.height);
}

void main() {
  setUpAll(loadAppFonts);

  group('vektör verisi', () {
    test('dört grup dolu ve zorunlu kimlikler var', () {
      expect(kLogoShadow, isNotEmpty);
      expect(kLogoLeaves, isNotEmpty);
      final ids = _all.map((s) => s.id).toSet();
      for (final id in ['wordmark-outline', 'wordmark-fill', 'tagline-outline', 'tagline-fill']) {
        expect(ids, contains(id));
      }
      final fill = kLogoWordmark.firstWhere((s) => s.id == 'wordmark-fill');
      expect(fill.fill, isA<LogoLinear>(), reason: 'harf yüzü gradyanı: yön SVG\'den, renkler temadan');
    });

    test('her yol çözülür ve çizim uzayının içinde kalır', () {
      expect(kLogoViewWidth, greaterThan(0));
      expect(kLogoViewHeight, greaterThan(0));
      // Gölge halkaları yumuşak kenarlı olduğundan çizim uzayının birkaç birim dışına taşabilir; diğer şekiller taşmamalı.
      Rect limit(double slack) => Rect.fromLTWH(-slack, -slack, kLogoViewWidth + 2 * slack, kLogoViewHeight + 2 * slack);
      for (final s in _all) {
        final b = parseLogoPath(s.d).getBounds();
        expect(b.isEmpty, isFalse, reason: s.id);
        final bounds = limit(kLogoShadow.contains(s) ? 24 : 4);
        expect(bounds.contains(b.topLeft) && bounds.contains(b.bottomRight), isTrue, reason: '${s.id} taşıyor: $b');
      }
    });

    test('desteklenmeyen yol komutu reddedilir', () {
      expect(() => parseLogoPath('M 0 0 Q 1 1 2 2'), throwsFormatException);
      expect(parseLogoPath('M 0 0 L 10 0 L 10 10 Z').getBounds(), const Rect.fromLTWH(0, 0, 10, 10));
    });
  });

  group('GudeLogo', () {
    testWidgets('boyut yalnızca yükseklikten gelir, oran SVG ile aynıdır', (tester) async {
      await tester.pumpWidget(testApp(const Align(alignment: Alignment.topLeft, child: GudeLogo(height: 84))));
      final size = tester.getSize(find.byType(GudeLogo));
      expect(size.height, 84);
      expect(size.width, closeTo(84 * kLogoViewWidth / kLogoViewHeight, 0.01));
    });

    testWidgets('anlamsal etiket yalnızca verilince okunur', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(testApp(const GudeLogo(height: 60, semanticLabel: 'Güde Teknoloji')));
      expect(find.bySemanticsLabel('Güde Teknoloji'), findsOneWidget);
      await tester.pumpWidget(testApp(const GudeLogo(height: 60)));
      expect(find.bySemanticsLabel('Güde Teknoloji'), findsNothing);
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('şeffaf zeminde çizilir: köşe boş, içerik dolu ($brightness)', (tester) async {
        final img = await _paintAlpha(tester, brightness, 84);
        int alphaAt(int x, int y) => img.rgba[(y * img.width + x) * 4 + 3];
        expect(alphaAt(0, 0), 0, reason: 'plaka/zemin çizilmemeli');
        expect(alphaAt(img.width - 1, 0), 0);
        var opaque = 0;
        for (var i = 3; i < img.rgba.length; i += 4) {
          if (img.rgba[i] == 255) opaque++;
        }
        expect(opaque, greaterThan(img.width * img.height * 0.08), reason: 'yapraklar ve yazı çizilmiş olmalı');
      });
    }

    testWidgets('gölge yalnızca açık temada çizilir (koyu zeminde halka olmaz)', (tester) async {
      int translucent(({Uint8List rgba, int width, int height}) img) {
        var n = 0;
        for (var i = 3; i < img.rgba.length; i += 4) {
          if (img.rgba[i] > 0 && img.rgba[i] < 255) n++;
        }
        return n;
      }

      final dark = await _paintAlpha(tester, Brightness.dark, 168);
      final light = await _paintAlpha(tester, Brightness.light, 168);
      expect(translucent(light), greaterThan(translucent(dark) * 1.5), reason: 'açık temada yumuşak gölge var');
    });

    testWidgets('tema geçişinde palet karışır ve logo hatasız çizilir', (tester) async {
      final mid = AppColors.dark.lerp(AppColors.light, 0.5);
      expect(mid.logo.shadow.a, greaterThan(0));
      expect(mid.logo.shadow.a, lessThan(AppColors.light.logo.shadow.a));
      expect(AppColors.dark.logo == AppColors.light.logo, isFalse);
      expect(AppColors.dark.copyWith(logo: AppColors.light.logo).logo, AppColors.light.logo);
    });
  });

  group('üst çubuk ölçüsü', () {
    test('logo 84 → 126 px, çubuk logo + 16 px', () {
      expect(logoHeightFor(360), 84);
      expect(logoHeightFor(1440), 126);
      expect(logoHeightFor(3000), 126);
      expect(topBarHeightFor(360), 100);
      expect(topBarHeightFor(1440), 142);
      expect(logoHeightFor(900), inInclusiveRange(84, 126));
    });
  });

  group('Görsel doğrulama (PNG üretir)', () {
    for (final brightness in Brightness.values) {
      for (final h in [84.0, 168.0]) {
        testWidgets('logo ${brightness.name} ${h.toInt()} px', (tester) async {
          final colors = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
          final path = await shot(
            tester,
            testApp(
              ColoredBox(color: colors.bg, child: Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.all(12), child: GudeLogo(height: h)))),
              brightness: brightness,
            ),
            size: Size(h * 1.52 + 24, h + 24),
            pixelRatio: 2,
            name: 'logo_${brightness.name}_${h.toInt()}',
          );
          // ignore: avoid_print
          print('SHOT: $path');
        });
      }
    }
  });
}
