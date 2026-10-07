import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/core/theme_controller.dart';
import 'package:gudeteknolojiweb/core/theme_store.dart';
import 'package:gudeteknolojiweb/theme.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

/// WCAG kontrast oranı; yarı saydam renk [over] zemini üzerine harmanlanır.
double _contrast(Color fg, Color bg, {Color? over}) {
  final base = over == null ? bg : Color.alphaBlend(bg, over);
  final f = Color.alphaBlend(fg, base);
  final a = _lum(f), b = _lum(base);
  final hi = math.max(a, b), lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(ThemeStore.reset);

  for (final entry in {'koyu': AppColors.dark, 'açık': AppColors.light}.entries) {
    final c = entry.value;
    group('${entry.key} palet kontrastı', () {
      test('ana metin zeminde ≥ 7:1', () => expect(_contrast(c.text, c.bg), greaterThanOrEqualTo(7)));
      test('ikincil metin ≥ 4.5:1 (bg, bgAlt, surface)', () {
        for (final bg in [c.bg, c.bgAlt, c.surface]) {
          expect(_contrast(c.textDim, bg), greaterThanOrEqualTo(4.5), reason: 'textDim / $bg');
        }
      });
      test('vurgu metni (accentText) zeminde ≥ 4.5:1', () => expect(_contrast(c.accentText, c.bg), greaterThanOrEqualTo(4.5)));
      test('vurgu çizgisi (accent) ≥ 3:1', () => expect(_contrast(c.accent, c.bg), greaterThanOrEqualTo(3)));
      test('dolgulu düğme yazısı ≥ 7:1', () => expect(_contrast(c.filledFg, c.filledBg), greaterThanOrEqualTo(7)));
      test('başarı rengi ≥ 3:1', () => expect(_contrast(c.ok, c.bg), greaterThanOrEqualTo(3)));
    });
  }

  test('lerp uçlarda tam palet verir, ortada karışır', () {
    expect(AppColors.dark.lerp(AppColors.light, 0).bg, AppColors.dark.bg);
    expect(AppColors.dark.lerp(AppColors.light, 1).bg, AppColors.light.bg);
    final mid = AppColors.dark.lerp(AppColors.light, 0.5).bg;
    expect(mid, isNot(AppColors.dark.bg));
    expect(mid, isNot(AppColors.light.bg));
  });

  test('copyWith yalnızca verilen alanı değiştirir', () {
    final c = AppColors.dark.copyWith(accent: Colors.red);
    expect(c.accent, Colors.red);
    expect(c.bg, AppColors.dark.bg);
  });

  test('ThemeController varsayılanı kDefaultThemeMode, değişince bildirir ve kaydeder', () {
    final ctrl = ThemeController();
    expect(ctrl.mode, kDefaultThemeMode);
    var n = 0;
    ctrl.addListener(() => n++);
    ctrl.setMode(ThemeMode.light);
    ctrl.setMode(ThemeMode.light); // aynı değer: bildirim yok
    expect(n, 1);
    expect(ThemeStore.read(), ThemeMode.light);
    expect(ThemeController().mode, ThemeMode.light, reason: 'yeni oturum kayıtlı tercihi okur');
    ctrl.toggle(Brightness.light);
    expect(ctrl.mode, ThemeMode.dark);
    ctrl.toggle(Brightness.dark);
    expect(ctrl.mode, ThemeMode.light);
  });

  testWidgets('MaterialApp iki temayı yükler; context.colors görünür temayı verir', (tester) async {
    AppColors? seen;
    Widget app(ThemeMode mode) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Builder(builder: (context) {
            seen = context.colors;
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(app(ThemeMode.dark));
    expect(seen!.isDark, isTrue);
    await tester.pumpWidget(app(ThemeMode.light));
    await tester.pump(const Duration(milliseconds: 500));
    expect(seen!.isDark, isFalse);
    expect(seen!.bg, AppColors.light.bg);
  });

  testWidgets('uzantısız çıplak MaterialApp koyu palete düşer', (tester) async {
    AppColors? seen;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      seen = context.colors;
      return const SizedBox();
    })));
    expect(seen!.bg, AppColors.dark.bg);
  });
}
