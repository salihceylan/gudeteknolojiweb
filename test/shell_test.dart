// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/brand/gude_logo.dart';
import 'package:gudeteknolojiweb/core/theme_controller.dart';
import 'package:gudeteknolojiweb/core/theme_store.dart';
import 'package:gudeteknolojiweb/main.dart';
import 'package:gudeteknolojiweb/pages/home_page.dart';
import 'package:gudeteknolojiweb/pages/menu_panel.dart';
import 'package:gudeteknolojiweb/pages/nav_model.dart';
import 'package:gudeteknolojiweb/pages/top_bar.dart';
import 'package:gudeteknolojiweb/scenes/hero_camera_block.dart';
import 'package:gudeteknolojiweb/scenes/references_scene.dart';
import 'package:gudeteknolojiweb/scenes/services_scene.dart';
import 'package:gudeteknolojiweb/scenes/teklif_band.dart';
import 'package:gudeteknolojiweb/theme.dart';
import 'package:gudeteknolojiweb/widgets/common.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'helpers/shot.dart';

/// Açılan bağlantıları ve pencere adlarını kaydeden sahte tarayıcı.
class _FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final calls = <(String url, String? window)>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls.add((url, options.webOnlyWindowName));
    return true;
  }
}

void main() {
  setUpAll(loadAppFonts);
  late _FakeLauncher launcher;
  setUp(() {
    ThemeStore.reset();
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  Future<void> boot(WidgetTester tester, Size size, {ThemeMode mode = ThemeMode.dark}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ThemeController(initial: mode);
    addTearDown(controller.dispose);
    await tester.pumpWidget(GudeApp(themeController: controller));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 800));
  }

  ScrollPosition pageScroll(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  double offsetOf(WidgetTester tester) => pageScroll(tester).pixels;

  /// Animasyonların ve mıknatısın oturması için süre tanır.
  Future<void> settle(WidgetTester tester, {int ms = 2500}) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder tapLabeled(String label) => find.byWidgetPredicate((w) => w is FocusableTap && w.label == label);

  /// [tap] düğmesine klavye odağı verir (Tab sırasını bilmeden).
  Future<void> focusOn(WidgetTester tester, Finder tap) async {
    final inner = find.descendant(of: tap, matching: find.byType(GestureDetector)).first;
    Focus.of(tester.element(inner)).requestFocus();
    await tester.pump();
  }

  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(tapLabeled('Menüyü aç veya kapat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  bool focusIn<T extends Widget>() => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<T>() != null;

  group('klavye ile sayfa kaydırma', () {
    testWidgets('PageDown / Boşluk / End / Home / Shift+Boşluk, hiçbir şeye tıklamadan çalışır', (tester) async {
      await boot(tester, const Size(1440, 900));
      final cam = HeroCameraBlock.transitionDistance(900);
      expect(offsetOf(tester), 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      expect(offsetOf(tester), closeTo(cam, 2), reason: 'sayfa adımı en yakın sahne başına yaslanır');

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await settle(tester);
      expect(offsetOf(tester), closeTo(0, 2));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await settle(tester);
      expect(offsetOf(tester), closeTo(cam, 2));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settle(tester);
      expect(offsetOf(tester), closeTo(0, 2), reason: 'Shift+Boşluk bir sayfa yukarı');

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await settle(tester);
      expect(offsetOf(tester), closeTo(pageScroll(tester).maxScrollExtent, 2));

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await settle(tester);
      expect(offsetOf(tester), closeTo(0, 2));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(offsetOf(tester), greaterThan(0), reason: 'ok tuşu da kaydırır');
      expect(tester.takeException(), isNull);
    });

    testWidgets('odak üst çubuktaki bir düğmedeyken de çalışır; Boşluk ise düğmeyi çalıştırır, sayfayı oynatmaz', (tester) async {
      await boot(tester, const Size(1440, 900));

      await focusOn(tester, tapLabeled('Açık temaya geç'));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      expect(offsetOf(tester), greaterThan(500), reason: 'üst çubuk kaydırma alanının kardeşi; yine de tuş sayfaya ulaşmalı');

      await focusOn(tester, tapLabeled('Menüyü aç veya kapat'));
      final before = offsetOf(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Kamera Sistemleri'), findsWidgets, reason: 'Boşluk odaktaki düğmeyi çalıştırır (panel açılır)');
      expect(offsetOf(tester), before);
    });

    testWidgets('boş bir yere tıklayınca odak sayfaya döner', (tester) async {
      await boot(tester, const Size(1440, 900));
      await focusOn(tester, tapLabeled('Açık temaya geç'));
      expect(focusIn<TopBar>(), isTrue);

      await tester.tapAt(const Offset(700, 450));
      await tester.pump();
      expect(focusIn<TopBar>(), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      expect(offsetOf(tester), greaterThan(500));
    });
  });

  group('sandviç panel: klavye ve odak', () {
    testWidgets('açılınca odak panele geçer; Tab arkadaki sayfaya kaçmaz; ok tuşları sayfayı oynatmaz', (tester) async {
      await boot(tester, const Size(1440, 900));
      await openPanel(tester);
      expect(focusIn<MenuPanel>(), isTrue, reason: 'açılışta odak panelde');

      for (var i = 0; i < 24; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focusIn<MenuPanel>() || focusIn<TopBar>(), isTrue, reason: 'Tab #$i: odak panel ya da üst çubuk dışına kaçtı');
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await settle(tester);
      expect(offsetOf(tester), 0, reason: 'panel açıkken sayfa kaymaz');
    });

    testWidgets('üst çubuktaki normal menü bağlantıları panel açıkken Tab ile ulaşılamaz', (tester) async {
      await boot(tester, const Size(1440, 900));
      await openPanel(tester);
      final nav = tester.element(find.descendant(of: find.byType(TopBar), matching: tapLabeled('Hizmetler')));
      expect(nav.findAncestorWidgetOfExactType<ExcludeFocus>()?.excluding, isTrue);
    });

    testWidgets('Esc, odak panel dışındayken de kapatır; kapanınca odak sandviç düğmesine döner', (tester) async {
      await boot(tester, const Size(1440, 900));
      await openPanel(tester);
      await focusOn(tester, tapLabeled('Açık temaya geç')); // odak panelden çıktı
      expect(focusIn<MenuPanel>(), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Kamera Sistemleri'), findsNothing);
      expect(focusIn<TopBar>(), isTrue, reason: 'odak sandviç düğmesine dönmeli');

      // Aynı akış panel içindeyken de.
      await openPanel(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Kamera Sistemleri'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('telefon / e-posta / WhatsApp satırları odaklanır, Enter ve Boşlukla açılır', (tester) async {
      await boot(tester, const Size(1440, 900));
      await openPanel(tester);

      final lines = {Contact.phoneDisplay: Contact.phoneUri, Contact.email: 'mailto:${Contact.email}', 'WhatsApp': Contact.whatsapp};
      var n = 0;
      for (final e in lines.entries) {
        await focusOn(tester, tapLabeled(e.key));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(launcher.calls.length, ++n, reason: '${e.key}: Enter');
        expect(launcher.calls.last.$1, e.value);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(launcher.calls.length, ++n, reason: '${e.key}: Boşluk');
      }
    });

    testWidgets('panel bağlantıları ve tema segmentleri Enter ile tetiklenir', (tester) async {
      await boot(tester, const Size(1440, 900));
      await openPanel(tester);

      await focusOn(tester, tapLabeled('Açık tema'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(Theme.of(tester.element(find.byType(MenuPanel))).brightness, Brightness.light);

      await focusOn(tester, tapLabeled('İletişim'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester, ms: 2000);
      expect(find.text('Kamera Sistemleri'), findsNothing, reason: 'bağlantı paneli kapatır');
      expect(offsetOf(tester), greaterThan(2000));
    });

    testWidgets('geri tuşu önce paneli kapatır, panel kapalıyken sayfadan çıkar', (tester) async {
      await boot(tester, const Size(390, 844));
      await openPanel(tester);
      expect(find.text('Kamera Sistemleri'), findsWidgets);

      expect(await tester.binding.handlePopRoute(), isTrue, reason: 'geri tuşu panele harcandı');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Kamera Sistemleri'), findsNothing);

      expect(await tester.binding.handlePopRoute(), isFalse, reason: 'panel kapalı: geri tuşu sayfaya bırakılır');
    });

    testWidgets('Teklif Pro paneli kapatıp bağlantıyı yeni sekmede açar', (tester) async {
      await boot(tester, const Size(1440, 900));
      await openPanel(tester);
      await tester.tap(find.descendant(of: find.byType(MenuPanel), matching: find.text('Teklif Pro')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(launcher.calls, [(Contact.teklifPro, '_blank')]);
      expect(find.text('Kamera Sistemleri'), findsNothing);
    });
  });

  group('panel görünümü', () {
    testWidgets('açılma bitince bütün öğeler tam opak ve yerinde (son grup dahil)', (tester) async {
      // Hata: son grubun aralığı 0.70-1.10 idi; ilerleme 1'de ~%90 opaklıkta ve 2.5 px kaymış kalıyordu.
      const count = 8;
      for (var i = 0; i < count; i++) {
        expect(panelStagger(1, i, count), 1, reason: 'öğe $i');
        expect(panelStagger(0, i, count), 0, reason: 'öğe $i başlangıçta görünmez');
      }
      for (var i = 1; i < count; i++) {
        expect(panelStagger(0.5, i, count), lessThanOrEqualTo(panelStagger(0.5, i - 1, count)), reason: 'sıra korunur');
      }

      await boot(tester, const Size(1440, 900));
      await openPanel(tester);
      await settle(tester, ms: 1000);
      final pill = find.descendant(of: find.byType(MenuPanel), matching: find.byType(PillButton));
      for (final o in tester.widgetList<Opacity>(find.ancestor(of: pill, matching: find.byType(Opacity)))) {
        expect(o.opacity, 1.0);
      }
      expect(tester.getTopLeft(pill).dx, 1440 - 400 + fluid(tester.element(pill), 28, 40), reason: 'yatay kayma kalmamalı');
    });

    for (final size in const [Size(1280, 720), Size(360, 640)]) {
      testWidgets('kısa ekranda ($size) tema seçici ulaşılabilir ve içerik üst çubuğun arkasından geçmez', (tester) async {
        await boot(tester, size);
        await openPanel(tester);
        await settle(tester, ms: 1000);

        final scroller = find.descendant(of: find.byType(MenuPanel), matching: find.byType(SingleChildScrollView));
        expect(tester.getTopLeft(scroller).dy, closeTo(topBarHeightFor(size.width), 0.01), reason: 'kaydırma alanı üst çubuğun altından başlar');

        final position = tester.state<ScrollableState>(find.descendant(of: scroller, matching: find.byType(Scrollable))).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        final theme = tester.getRect(find.text('TEMA'));
        expect(theme.top, greaterThanOrEqualTo(topBarHeightFor(size.width)));
        expect(theme.bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(tapLabeled('Sistem tema')).bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('üst çubuk', () {
    testWidgets('boş yerde ve düğmelerin üzerinde fare tekerleği sayfayı kaydırır', (tester) async {
      // Hata: tam genişlikli şerit tekerleği yutuyordu; üstteki çubuk alanı ölü bölgeydi.
      await boot(tester, const Size(1440, 900));
      final mouse = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(mouse.hover(const Offset(400, 30)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await settle(tester);
      expect(offsetOf(tester), greaterThan(0), reason: 'boş çubuk alanı');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await settle(tester);
      expect(offsetOf(tester), 0);

      await tester.sendEventToBinding(mouse.hover(tester.getCenter(find.text('İletişim'))));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await settle(tester);
      expect(offsetOf(tester), greaterThan(0), reason: 'menü bağlantısının üstü');
    });

    for (final size in const [Size(900, 700), Size(960, 700), Size(1024, 768), Size(1440, 900), Size(768, 1024), Size(390, 844), Size(320, 640)]) {
      testWidgets('büyük logo ($size) üst çubukta taşmaz, menü ve düğmelerle çakışmaz', (tester) async {
        await boot(tester, size);
        expect(tester.takeException(), isNull);
        final logo = tester.getRect(find.byType(GudeLogo));
        expect(logo.height, closeTo(logoHeightFor(size.width) - 4, 0.01));
        expect(logo.left, greaterThanOrEqualTo(0));
        expect(tester.getSize(find.byType(TopBar)).height, closeTo(topBarHeightFor(size.width), 0.01));
        // Sağdaki ilk öğe (geniş ekranda "Kamera" bağlantısı, dar ekranda sandviç düğmesi) logonun sağında kalmalı.
        final firstRight = size.width >= 900
            ? tester.getRect(find.descendant(of: tapLabeled('Kamera'), matching: find.text('Kamera'))).left
            : tester.getRect(find.byType(AnimatedIcon)).left;
        expect(firstRight, greaterThan(logo.right), reason: 'logo ile sağdaki öğeler çakışmamalı');
      });
    }

    testWidgets('menü yazıları çubuğun tam ortasında durur (alt çizgi akışı itmez)', (tester) async {
      await boot(tester, const Size(1440, 900));
      for (final item in kNavItems) {
        final text = find.descendant(of: tapLabeled(item.label), matching: find.text(item.label));
        expect(tester.getCenter(text).dy, closeTo(topBarHeightFor(1440) / 2, 0.6), reason: item.label);
      }
      // Teklif bandındaki aynı etiketli düğmeyle karışmasın: yalnızca üst çubuktakini ara.
      final button = find.descendant(
          of: find.descendant(of: find.byType(TopBar), matching: tapLabeled('Teklif Pro')), matching: find.text('Teklif Pro'));
      expect(tester.getCenter(button).dy, closeTo(topBarHeightFor(1440) / 2, 0.6));
    });

    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('klavye odağı menü bağlantısında belirgin halka ve alt çizgi çizer ($mode)', (tester) async {
        await boot(tester, const Size(1440, 900), mode: mode);
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        final accent = (mode == ThemeMode.dark ? AppColors.dark : AppColors.light).accent;

        Color? ring(String label) {
          final box = tester.widget<Container>(find.descendant(of: tapLabeled(label), matching: find.byType(Container)).first);
          return ((box.decoration! as BoxDecoration).border! as Border).top.color;
        }

        double underline(String label) =>
            tester.getSize(find.descendant(of: tapLabeled(label), matching: find.byType(AnimatedContainer))).width;

        expect(ring('Hizmetler'), isNot(accent));
        expect(underline('Hizmetler'), 0);
        await focusOn(tester, tapLabeled('Hizmetler'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(ring('Hizmetler'), accent, reason: 'odakta 2 px vurgu halkası');
        expect(underline('Hizmetler'), 18, reason: 'odakta alt çizgi uzar');
      });
    }

    testWidgets('boyut odakla değişmez', (tester) async {
      await boot(tester, const Size(1440, 900));
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final before = tester.getSize(tapLabeled('Hizmetler'));
      await focusOn(tester, tapLabeled('Hizmetler'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(tapLabeled('Hizmetler')), before);
    });
  });

  group('dokunma hedefleri', () {
    for (final size in const [Size(360, 640), Size(412, 915), Size(1440, 900)]) {
      testWidgets('bütün düğmeler en az 44x44 ($size, panel açık ve kapalı)', (tester) async {
        await boot(tester, size);

        void check(String when) {
          final taps = tester.widgetList<FocusableTap>(find.byType(FocusableTap)).toList();
          expect(taps, isNotEmpty);
          for (final t in find.byType(FocusableTap).evaluate()) {
            final box = t.renderObject! as RenderBox;
            if (!box.hasSize) continue;
            final label = (t.widget as FocusableTap).label;
            expect(box.size.width, greaterThanOrEqualTo(kMinTapTarget), reason: '$when: "$label" genişliği');
            expect(box.size.height, greaterThanOrEqualTo(kMinTapTarget), reason: '$when: "$label" yüksekliği');
          }
        }

        check('panel kapalı');
        await openPanel(tester);
        await settle(tester, ms: 1000);
        check('panel açık');
      });
    }
  });

  group('sahne durakları ve yeniden boyutlanma', () {
    testWidgets('Teklif Pro bandı durulabilir: Referanslar → Teklif → İletişim, aşağıda ve yukarıda', (tester) async {
      // Hata: bant çapa değildi; Referanslar ile İletişim arası tek sayfa sayılıp bant atlanıyordu.
      await boot(tester, const Size(412, 784));
      double top(Type t) => tester.getTopLeft(find.byType(t)).dy;
      pageScroll(tester).jumpTo(offsetOf(tester) + top(ReferencesScene));
      await tester.pump();
      expect(top(ReferencesScene), closeTo(0, 1));

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await settle(tester);
      expect(top(TeklifBand), closeTo(0, 2), reason: 'aşağı: bant başında durmalı');

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -300));
      await settle(tester);
      expect(offsetOf(tester), closeTo(pageScroll(tester).maxScrollExtent, 2), reason: 'sonra sayfa dibi (İletişim)');

      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 300));
      await settle(tester);
      expect(top(TeklifBand), closeTo(0, 2), reason: 'yukarı: Referanslar\'a kadar atlamadan bantta durmalı');
    });

    testWidgets('ekran boyutu değişince aynı sahne görünür kalır', (tester) async {
      // Hata: piksel ofseti korunuyor, sahne yükseklikleri değişince kullanıcı başka sahnede kalıyordu.
      await boot(tester, const Size(1440, 900));
      pageScroll(tester).jumpTo(offsetOf(tester) + tester.getTopLeft(find.byType(ServicesScene)).dy);
      await tester.pump();
      expect(tester.getTopLeft(find.byType(ServicesScene)).dy, closeTo(0, 1));

      for (final size in const [Size(1024, 768), Size(390, 844), Size(1440, 900)]) {
        tester.view.physicalSize = size;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(tester.getTopLeft(find.byType(ServicesScene)).dy, closeTo(0, 2), reason: 'boyut $size');
      }
      await settle(tester, ms: 1000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kullanıcı kaydırırken ekran boyutu değişirse sayfa parmağın altından kaçmaz', (tester) async {
      // Mobil tarayıcıda adres çubuğu kaydırma sırasında gizlenir ve ekran yüksekliği değişir.
      await boot(tester, const Size(412, 784));
      final gesture = await tester.startGesture(const Offset(200, 400));
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump();
      final before = offsetOf(tester);
      expect(before, greaterThan(200));

      tester.view.physicalSize = const Size(412, 700);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(offsetOf(tester), before, reason: 'parmak yerdeyken yeniden hizalama yapılmaz');
      await gesture.up();
      await settle(tester);
    });

    testWidgets('sahne ortasındaki oran da korunur', (tester) async {
      await boot(tester, const Size(1440, 900));
      final top = tester.getTopLeft(find.byType(ServicesScene)).dy;
      final h = tester.getSize(find.byType(ServicesScene)).height;
      pageScroll(tester).jumpTo(offsetOf(tester) + top + h * 0.25);
      await tester.pump();

      tester.view.physicalSize = const Size(1024, 768);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final h2 = tester.getSize(find.byType(ServicesScene)).height;
      final y = tester.getTopLeft(find.byType(ServicesScene)).dy;
      // Sahne içi oran, bir sonraki çapaya göre; sahne yüksekliğine yakın bir değerde kalır.
      expect(-y, greaterThan(0));
      expect(-y, lessThan(h2));
      await settle(tester, ms: 1000);
    });
  });

  group('bağlantılar', () {
    test('http(s) yeni sekmede, mailto: ve tel: aynı sekmede açılır', () async {
      // Hata: her şema için '_blank' kullanılıyordu; mailto:/tel: boş bir sekme/pop-up açıyordu.
      await openLink(Contact.teklifPro);
      await openLink(Contact.whatsapp);
      await openLink('mailto:${Contact.email}');
      await openLink(Contact.phoneUri);
      expect(launcher.calls, [
        (Contact.teklifPro, '_blank'),
        (Contact.whatsapp, '_blank'),
        ('mailto:${Contact.email}', '_self'),
        (Contact.phoneUri, '_self'),
      ]);
    });
  });

  group('dil', () {
    testWidgets('uygulama Türkçe yerel ayarla çalışır (html lang="tr")', (tester) async {
      await boot(tester, const Size(1440, 900));
      final context = tester.element(find.byType(HomePage));
      expect(Localizations.localeOf(context), const Locale('tr'));
      expect(MaterialLocalizations.of(context), isNotNull);
    });
  });

  group('web kabuğu', () {
    final index = File('web/index.html').readAsStringSync();

    test('yükleme zemini kayıtlı temayı ilk kareden uygular (açıkta koyu parlama yok)', () {
      expect(index, contains("localStorage.getItem('gude-theme')"), reason: 'ThemeStore ile aynı anahtar');
      expect(index, contains('prefers-color-scheme'), reason: 'sistem modu');
      expect(index, contains('data-theme'));
      String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      expect(index, contains(hex(AppColors.dark.bg)));
      expect(index, contains(hex(AppColors.light.bg)));
      expect(index, contains(hex(AppColors.dark.accent)));
      expect(index, contains(hex(AppColors.light.accent)));
      expect(RegExp(r'html,\s*body\s*\{[^}]*background:\s*#', caseSensitive: false).hasMatch(index), isFalse,
          reason: 'html/body zemini sabit renk değil, tema değişkeni olmalı');
    });

    test('yükleme uzarsa ya da kaynak yüklenemezse kullanıcıya iletilir', () {
      expect(index, contains('flutter-first-frame'));
      expect(index, contains('location.reload'));
      expect(index, contains('<noscript>'));
    });

    test('CanvasKit kendi alan adımızdan yüklenir (CDN\'e bağımlı değil)', () {
      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
      expect(bootstrap, contains('{{flutter_js}}'));
      expect(bootstrap, contains('{{flutter_build_config}}'));
      expect(bootstrap, contains('canvasKitBaseUrl'));
      expect(bootstrap, isNot(contains('gstatic')));
    });

    test('robots.txt ve sitemap.xml var ve birbirine bağlı', () {
      final robots = File('web/robots.txt').readAsStringSync();
      final sitemap = File('web/sitemap.xml').readAsStringSync();
      expect(robots, contains('Sitemap: https://gudeteknoloji.com/sitemap.xml'));
      expect(sitemap, contains('<loc>https://gudeteknoloji.com/</loc>'));
    });
  });
}
