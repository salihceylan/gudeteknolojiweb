import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/core/theme_controller.dart';
import 'package:gudeteknolojiweb/core/theme_store.dart';
import 'package:gudeteknolojiweb/main.dart';
import 'package:gudeteknolojiweb/scenes/hero_camera_block.dart';
import 'package:gudeteknolojiweb/theme.dart';

import 'helpers/shot.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(ThemeStore.reset);

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  double offsetOf(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

  Future<void> boot(WidgetTester tester, {ThemeController? controller}) async {
    await tester.pumpWidget(GudeApp(themeController: controller));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('masaüstü: açılış başlığı, normal menü, Teklif Pro ve sandviç düğmesi birlikte görünür', (tester) async {
    setSize(tester, const Size(1440, 900));
    await boot(tester);

    expect(find.text('Gelecek sizin elinizde.'), findsOneWidget);
    for (final label in ['Kamera', 'Ürünler', 'Hizmetler', 'Süreç', 'Referanslar', 'İletişim']) {
      expect(find.text(label), findsOneWidget, reason: 'normal menüde "$label" bulunmalı');
    }
    // "Teklif Pro" hem üst çubukta hem sayfadaki Teklif bandında bulunur.
    expect(find.text('Teklif Pro'), findsWidgets);
    expect(find.bySemanticsLabel('Menüyü aç veya kapat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telefon: normal menü gizlenir, yalnızca sandviç kalır, taşma yok', (tester) async {
    setSize(tester, const Size(390, 844));
    await boot(tester);

    expect(find.text('Hizmetler'), findsNothing);
    expect(find.bySemanticsLabel('Menüyü aç veya kapat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sandviç panel açılır, bağlantıları gösterir; Esc ile kapanır', (tester) async {
    setSize(tester, const Size(1440, 900));
    await boot(tester);

    await tester.tap(find.bySemanticsLabel('Menüyü aç veya kapat'));
    await tester.pump(); // animasyon ilk karede başlar
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Kamera Sistemleri'), findsWidgets);
    expect(find.text('Çalışma Şekli'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Kamera Sistemleri'), findsNothing, reason: 'panel kapanınca ağaçtan kalkar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('menü bağlantısı sahneye yay eğrisiyle kaydırır ve paneli kapatır', (tester) async {
    setSize(tester, const Size(1440, 900));
    await boot(tester);
    expect(offsetOf(tester), 0);

    await tester.tap(find.text('İletişim'));
    await tester.pump();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(offsetOf(tester), greaterThan(2000), reason: 'iletişim sahnesi sayfanın aşağısında');
    expect(find.text('Projenizi konuşalım.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mıknatıs: açılışta yönde yeterli kaydırma bırakılınca kamera sahnesine yerleşir', (tester) async {
    setSize(tester, const Size(1440, 900));
    await boot(tester);
    final d = HeroCameraBlock.transitionDistance(900);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(offsetOf(tester), closeTo(d, 2), reason: 'kamera sahnesi başlangıcına yerleşmeli');
  });

  testWidgets('mıknatıs: çok küçük kaydırma bırakılınca açılışa geri döner', (tester) async {
    setSize(tester, const Size(1440, 900));
    await boot(tester);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(offsetOf(tester), closeTo(0, 2));
  });

  testWidgets('tema: denetleyici açığa çevirince zemin animasyonla açık palete geçer', (tester) async {
    setSize(tester, const Size(1440, 900));
    final controller = ThemeController(initial: ThemeMode.dark);
    addTearDown(controller.dispose);
    await boot(tester, controller: controller);

    Color scaffoldBg() => Theme.of(tester.element(find.byType(Scaffold).first)).scaffoldBackgroundColor;
    expect(scaffoldBg(), AppColors.dark.bg);

    controller.setMode(ThemeMode.light);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final mid = scaffoldBg();
    expect(mid, isNot(AppColors.dark.bg));
    expect(mid, isNot(AppColors.light.bg), reason: 'geçiş anlık değil, karışarak olur');
    await tester.pump(const Duration(milliseconds: 400));
    expect(scaffoldBg(), AppColors.light.bg);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iki temada da 1440 ve 390 genişlikte istisna/taşma yok', (tester) async {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      for (final size in const [Size(1440, 900), Size(390, 844), Size(1024, 768)]) {
        setSize(tester, size);
        final controller = ThemeController(initial: mode);
        await boot(tester, controller: controller);
        expect(tester.takeException(), isNull, reason: '$mode $size');
        controller.dispose();
        await tester.pumpWidget(const SizedBox());
      }
    }
  });
}
