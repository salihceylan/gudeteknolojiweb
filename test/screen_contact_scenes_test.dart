import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/core/core.dart';
import 'package:gudeteknolojiweb/scenes/contact_scene.dart';
import 'package:gudeteknolojiweb/scenes/line_icons.dart';
import 'package:gudeteknolojiweb/scenes/screen_door_scene.dart';
import 'package:gudeteknolojiweb/scenes/teklif_band.dart';
import 'package:gudeteknolojiweb/theme.dart';
import 'package:gudeteknolojiweb/widgets/ahbu_device.dart';
import 'package:gudeteknolojiweb/widgets/common.dart';

import 'helpers/app.dart';
import 'helpers/shot.dart';

/// Sahneyi gerçek sayfadaki gibi kaydırılabilir bir alanda, istenen tema, metin ölçeği ve hareket tercihiyle kurar.
Widget host(
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool reduceMotion = false,
  ScrollController? controller,
  Key? boundaryKey,
}) {
  final app = testApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
        child: Scaffold(body: SingleChildScrollView(controller: controller, child: child)),
      ),
    ),
    brightness: brightness,
  );
  return boundaryKey == null ? app : RepaintBoundary(key: boundaryKey, child: app);
}

void setView(WidgetTester tester, double width, [double height = 1000]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Giriş animasyonlarının (Reveal) bitmesi için yeterince ilerletir.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 800));
}

/// Ağaçtaki cihazın periyodik zamanlayıcısı testin sonunda sızmasın diye ağacı söker.
Future<void> teardownTree(WidgetTester tester) => tester.pumpWidget(const SizedBox());

/// [finder]'ın ekranda gerçekten görünen opaklığı: üstündeki bütün giriş animasyonlarının ([FadeTransition]) ve
/// [Opacity]'lerin çarpımı. Animasyon henüz başlamadıysa 0, bittiyse 1 döner.
double effectiveOpacity(WidgetTester tester, Finder finder) {
  var result = 1.0;
  for (final e in find.ancestor(of: finder, matching: find.byType(FadeTransition)).evaluate()) {
    result *= (e.widget as FadeTransition).opacity.value;
  }
  for (final e in find.ancestor(of: finder, matching: find.byType(Opacity)).evaluate()) {
    result *= (e.widget as Opacity).opacity;
  }
  return result;
}

/// Cihazın butonuna dokunur. Buton, cihazın üstünden 1.42 genişlik aşağıda, yatayda ortadadır (AhbuDevice yerleşimi).
Future<void> pressDeviceButton(WidgetTester tester) async {
  final rect = tester.getRect(find.byType(AhbuDevice));
  await tester.tapAt(rect.topLeft + Offset(rect.width / 2, rect.width * 1.42));
  await tester.pump(const Duration(milliseconds: 400));
}

/// [key]'in sınırladığı çizimi ham RGBA piksellerine çevirir.
Future<ByteData> rawPixels(WidgetTester tester, GlobalKey key) async {
  late ByteData data;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  return data;
}

/// (x, y) pikselinin 0-255 arası parlaklığı (kanalların ortalaması).
double lumaAt(ByteData data, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return (data.getUint8(i) + data.getUint8(i + 1) + data.getUint8(i + 2)) / 3;
}

AppColors paletteOf(Brightness b) => b == Brightness.dark ? AppColors.dark : AppColors.light;

/// Ağaçtaki [CustomPaint]'lerden çizici türü adı [typeName] olanları döndürür (özel çizicilere türüyle erişilemez).
List<CustomPainter> paintersOf(WidgetTester tester, String typeName) {
  return [
    for (final e in find.byType(CustomPaint).evaluate())
      if ((e.widget as CustomPaint).painter?.runtimeType.toString() == typeName) (e.widget as CustomPaint).painter!,
  ];
}

void main() {
  setUpAll(loadAppFonts);

  final scenes = <String, Widget Function()>{
    'ScreenDoorScene': () => ScreenDoorScene(onContact: () {}),
    'TeklifBand': () => const TeklifBand(),
    'ContactScene': () => const ContactScene(),
  };

  for (final brightness in Brightness.values) {
    final palette = paletteOf(brightness);

    group('${brightness.name} tema', () {
      group('taşma', () {
        for (final entry in scenes.entries) {
          for (final width in [320.0, 360.0, 390.0, 600.0, 768.0, 1024.0, 1440.0]) {
            for (final scale in [1.0, 1.5, 2.0]) {
              testWidgets('${entry.key} $width px, yazı ölçeği $scale', (tester) async {
                setView(tester, width);
                await tester.pumpWidget(host(entry.value(), brightness: brightness, textScale: scale));
                await settle(tester);
                // Taşma, çizim sırasında istisna olarak bildirilir.
                expect(tester.takeException(), isNull);
                expect(tester.getSize(find.byType(SingleChildScrollView)).width, width);
                final sceneSize = tester.getSize(find.byWidgetPredicate((w) => w.runtimeType.toString() == entry.key));
                expect(sceneSize.width, lessThanOrEqualTo(width));
                await teardownTree(tester);
              });
            }
          }
        }

        testWidgets('WhatsApp düğmesi 2.0 yazı ölçeğinde 360 px\'te ekrana sığar (ölçek 1.5\'ta kenetlenir)', (tester) async {
          setView(tester, 360);
          await tester.pumpWidget(host(const ContactScene(), brightness: brightness, textScale: 2));
          await settle(tester);
          expect(tester.takeException(), isNull);
          final button = tester.getRect(find.widgetWithText(PillButton, 'WhatsApp\'tan Ulaşın'));
          expect(button.left, greaterThanOrEqualTo(0));
          expect(button.right, lessThanOrEqualTo(360 - 24), reason: 'bölümün yatay boşluğunu aşmaz');
          // Kenetleme: 1.5 ölçekteki düğme ile 2.0 ölçekteki düğme aynı genişliktedir.
          final label2 = tester.getSize(find.text('WhatsApp\'tan Ulaşın')).width;
          await tester.pumpWidget(host(const ContactScene(), brightness: brightness, textScale: 1.5));
          await settle(tester);
          expect(tester.getSize(find.text('WhatsApp\'tan Ulaşın')).width, closeTo(label2, 0.5));
        });
      });

      group('zemin ve çerçeve tema renginden gelir', () {
        Color sectionColor(WidgetTester tester) {
          final container = find.descendant(of: find.byType(Section), matching: find.byType(Container)).first;
          return tester.widget<Container>(container).color!;
        }

        testWidgets('ScreenDoorScene ve ContactScene zemini c.bg', (tester) async {
          setView(tester, 1440);
          await tester.pumpWidget(host(ScreenDoorScene(onContact: () {}), brightness: brightness));
          await settle(tester);
          expect(sectionColor(tester), palette.bg);
          await teardownTree(tester);

          await tester.pumpWidget(host(const ContactScene(), brightness: brightness));
          await settle(tester);
          expect(sectionColor(tester), palette.bg);
        });

        testWidgets('TeklifBand yüzeyi c.surface, üst/alt çizgisi c.line', (tester) async {
          setView(tester, 1440);
          await tester.pumpWidget(host(const TeklifBand(), brightness: brightness));
          await settle(tester);
          final box = find.descendant(of: find.byType(TeklifBand), matching: find.byType(DecoratedBox)).first;
          final decoration = tester.widget<DecoratedBox>(box).decoration as BoxDecoration;
          expect(decoration.color, palette.surface);
          final border = decoration.border! as Border;
          expect(border.top.color, palette.line);
          expect(border.bottom.color, palette.line);
        });

        testWidgets('metin renkleri temadan: başlık c.text, gövde c.textDim', (tester) async {
          setView(tester, 1440);
          await tester.pumpWidget(host(const ContactScene(), brightness: brightness));
          await settle(tester);
          expect(tester.widget<Text>(find.text('Projenizi konuşalım.')).style!.color, palette.text);
          expect(tester.widget<Text>(find.textContaining('Yeni sistem kurulumu')).style!.color, palette.textDim);
          expect(tester.widget<Text>(find.text(Contact.email)).style!.color, palette.text);
        });
      });

      group('spot parıltısı', () {
        // Cihazın solunda, merkez yüksekliğinde bir nokta ile sahnenin köşesi karşılaştırılır.
        testWidgets('cihazın çevresinde görünür, şartname sınırını aşmaz', (tester) async {
          setView(tester, 1440, 900);
          final key = GlobalKey();
          await tester.pumpWidget(host(ScreenDoorScene(onContact: () {}), brightness: brightness, boundaryKey: key));
          await settle(tester);
          final device = tester.getRect(find.byType(AhbuDevice));
          final data = await rawPixels(tester, key);
          final corner = lumaAt(data, 1440, 8, 8);
          final nearDevice = lumaAt(data, 1440, (device.left - 30).round(), device.center.dy.round());
          if (brightness == Brightness.dark) {
            // Koyu zeminde beyaz %4-6 + vurgu ≤ %8: görünür (≥ 8 seviye) ama parlak bir leke değil (≤ 60).
            expect(nearDevice - corner, inInclusiveRange(8, 60));
          } else {
            // Açık zeminde stüdyo vurgusu: cihazın çevresi köşeden belirgin biçimde daha parlak.
            expect(nearDevice - corner, greaterThanOrEqualTo(3));
          }
          await teardownTree(tester);
        });

        testWidgets('cihazın altında zemin gölgesi (c.shadow) var: gölge yokken olduğundan daha koyu', (tester) async {
          setView(tester, 1440, 900);
          final key = GlobalKey();
          await tester.pumpWidget(host(ScreenDoorScene(onContact: () {}), brightness: brightness, boundaryKey: key));
          await settle(tester);
          final device = tester.getRect(find.byType(AhbuDevice));
          final data = await rawPixels(tester, key);
          // Cihaz tabanının biraz altında, cihaz eksenine uzak (gölge elipsinin kenarına yakın) iki nokta.
          final y = (device.bottom + 18).round();
          final under = lumaAt(data, 1440, (device.center.dx + device.width * 0.55).round(), y);
          final aside = lumaAt(data, 1440, (device.center.dx + device.width * 1.35).round(), y);
          if (brightness == Brightness.light) {
            expect(under, lessThan(aside), reason: 'açık zeminde gölge belirgin biçimde koyudur');
          } else {
            expect(under, lessThanOrEqualTo(aside + 1), reason: 'koyu zeminde gölge parıltıdan daha koyu ya da eşit');
          }
          await teardownTree(tester);
        });
      });
    });
  }

  group('tema değişimi', () {
    testWidgets('çizicilerin renkleri değişince shouldRepaint true döner (tema geçişinde yeniden boyanır)', (tester) async {
      setView(tester, 1440, 900);
      await tester.pumpWidget(host(Column(children: [ScreenDoorScene(onContact: () {}), const ContactScene()])));
      await settle(tester);
      final before = {
        for (final name in ['_SpotPainter', '_FloorShadowPainter', 'LineIconPainter']) name: paintersOf(tester, name),
      };
      for (final e in before.entries) {
        expect(e.value, isNotEmpty, reason: '${e.key} ağaçta bulunmalı');
      }

      await tester.pumpWidget(host(Column(children: [ScreenDoorScene(onContact: () {}), const ContactScene()]), brightness: Brightness.light));
      await tester.pump(const Duration(seconds: 1));
      for (final e in before.entries) {
        final after = paintersOf(tester, e.key);
        expect(after.length, e.value.length, reason: e.key);
        for (var i = 0; i < after.length; i++) {
          expect(after[i].shouldRepaint(e.value[i]), isTrue, reason: '${e.key}[$i] tema değişince yeniden boyanmalı');
        }
      }
      // Çizgi ikonların rengi gerçekten açık temanın vurgusuna geçti.
      final icon = paintersOf(tester, 'LineIconPainter').cast<LineIconPainter>().firstWhere((p) => p.glyph == LineGlyph.qr);
      expect(icon.color.a, closeTo(0.9, 0.01));
      expect(icon.color.withValues(alpha: 1), AppColors.light.accentText);
      await teardownTree(tester);
    });
  });

  group('çizgi ikonlar', () {
    test('LineIconPainter: şekil, renk ya da kalınlık değişince yeniden boyar; aynıysa boyamaz', () {
      const a = LineIconPainter(LineGlyph.qr, Color(0xFF112233), 1.5);
      expect(a.shouldRepaint(const LineIconPainter(LineGlyph.qr, Color(0xFF112233), 1.5)), isFalse);
      expect(a.shouldRepaint(const LineIconPainter(LineGlyph.pin, Color(0xFF112233), 1.5)), isTrue);
      expect(a.shouldRepaint(const LineIconPainter(LineGlyph.qr, Color(0xFF445566), 1.5)), isTrue);
      expect(a.shouldRepaint(const LineIconPainter(LineGlyph.qr, Color(0xFF112233), 2)), isTrue);
    });

    for (final glyph in LineGlyph.values) {
      testWidgets('LineGlyph.${glyph.name} boş değil, 24 px kutunun içinde kalır', (tester) async {
        final key = GlobalKey();
        const size = 40.0;
        tester.view.physicalSize = const Size(size * 3, size * 3);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(child: LineIcon(glyph, color: const Color(0xFFFF0000), size: 24)),
            ),
          ),
        );
        final data = await rawPixels(tester, key);
        const total = size * 3;
        var inside = 0;
        var outside = 0;
        const lo = (total - 24) / 2;
        const hi = lo + 24;
        for (var y = 0; y < total; y++) {
          for (var x = 0; x < total; x++) {
            final alpha = data.getUint8((y * total.toInt() + x) * 4 + 3);
            if (alpha == 0) continue;
            if (x >= lo - 1 && x <= hi && y >= lo - 1 && y <= hi) {
              inside++;
            } else {
              outside++;
            }
          }
        }
        expect(inside, greaterThan(20), reason: 'ikon bir şey çizmeli');
        expect(outside, 0, reason: 'çizim 24 px kutunun dışına taşmamalı');
      });
    }
  });

  group('metinler', () {
    testWidgets('ScreenDoorScene şartnamedeki metinleri birebir gösterir', (tester) async {
      setView(tester, 1440);
      await tester.pumpWidget(host(ScreenDoorScene(onContact: () {})));
      await settle(tester);
      for (final t in [
        'YENİ NESİL',
        'AHBU Akıllı Kapı Kontrol',
        'Site ve apartman girişleri için geliştirdiğimiz, ekranlı kapı kontrol cihazı. Şifre ve kart taşımadan, telefonla güvenli giriş.',
        'Dinamik karekod',
        'Ekrandaki karekod 30 saniyede bir yenilenir; kopyalanan kod işe yaramaz.',
        'Mobil uygulama',
        'Kapı telefondan uzaktan açılır; misafirlere süreli bağlantı gönderilir.',
        'İnternet kesilse de çalışır',
        'Yerel ağ üzerinden açma ve çevrimdışı kayıtların sonradan eşitlenmesi.',
        'Uzaktan güncelleme',
        'Cihaz yazılımı sahaya gitmeden, güvenli şekilde güncellenir.',
        'Butona basarak deneyin',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await teardownTree(tester);
    });

    testWidgets('TeklifBand şartnamedeki metinleri birebir gösterir', (tester) async {
      setView(tester, 1440);
      await tester.pumpWidget(host(const TeklifBand()));
      await settle(tester);
      for (final t in [
        'TEKLİF PRO',
        'Teklif süreçlerini hızlı ve düzenli yönetin.',
        'Teklif hazırlama, ürün yönetimi, revizyon takibi ve proje süreçlerini daha hızlı ve düzenli yönetmek için geliştirdiğimiz sistem.',
        'Teklif Pro',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('ContactScene şartnamedeki metinleri birebir gösterir; başlık 56 px\'i aşmaz', (tester) async {
      setView(tester, 1440);
      await tester.pumpWidget(host(const ContactScene()));
      await settle(tester);
      for (final t in [
        'İLETİŞİM',
        'Projenizi konuşalım.',
        'Yeni sistem kurulumu, mevcut sistemlerin yenilenmesi veya teknik servis ihtiyaçlarınız için bizimle iletişime geçebilirsiniz.',
        'WhatsApp\'tan Ulaşın',
        'TELEFON',
        'E-POSTA',
        'ADRES',
        Contact.phoneDisplay,
        Contact.email,
        Contact.address,
        '© 2026 Güde Teknoloji. Tüm hakları saklıdır.',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      final title = tester.widget<Text>(find.text('Projenizi konuşalım.'));
      expect(title.style!.fontSize, lessThanOrEqualTo(56));
    });
  });

  group('bağlantılar', () {
    Future<List<String>> pumpContact(WidgetTester tester, {double width = 1440, Brightness brightness = Brightness.dark}) async {
      setView(tester, width);
      final opened = <String>[];
      await tester.pumpWidget(host(ContactScene(onOpenLink: (url) async => opened.add(url)), brightness: brightness));
      await settle(tester);
      return opened;
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      final f = find.text(text);
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump();
    }

    for (final brightness in Brightness.values) {
      for (final width in [390.0, 1440.0]) {
        testWidgets('ContactScene (${brightness.name}, $width px): telefon, e-posta ve WhatsApp doğru bağlantıyı açar', (tester) async {
          final opened = await pumpContact(tester, width: width, brightness: brightness);

          await tapText(tester, Contact.phoneDisplay);
          expect(opened, [Contact.phoneUri]);

          await tapText(tester, Contact.email);
          expect(opened, [Contact.phoneUri, 'mailto:${Contact.email}']);

          await tapText(tester, 'WhatsApp\'tan Ulaşın');
          expect(opened, [Contact.phoneUri, 'mailto:${Contact.email}', Contact.whatsapp]);
        });
      }
    }

    testWidgets('ContactScene: adres satırı tıklanabilir değildir', (tester) async {
      final opened = await pumpContact(tester);
      await tapText(tester, Contact.address);
      expect(opened, isEmpty);
    });

    testWidgets('ContactScene: WhatsApp, telefon ve e-posta klavye ile (Tab + Enter) etkinleşir', (tester) async {
      final opened = await pumpContact(tester);
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      }
      expect(opened.toSet(), {Contact.whatsapp, Contact.phoneUri, 'mailto:${Contact.email}'});
    });

    for (final brightness in Brightness.values) {
      testWidgets('ContactScene (${brightness.name}): üzerine gelince ok vurgu rengine geçer, ayrılınca soluk renge döner', (tester) async {
        await pumpContact(tester, brightness: brightness);
        final palette = paletteOf(brightness);
        Color arrowColor() => paintersOf(tester, 'LineIconPainter')
            .cast<LineIconPainter>()
            .where((p) => p.glyph == LineGlyph.arrowUpRight)
            .first
            .color;
        expect(arrowColor(), palette.textDim);

        // Hover vurgusu yalnızca "geleneksel" (fare/klavye) odak kipinde gösterilir; test platformu dokunmatiktir.
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        // Satır ekranın içinde olmalı: fare, görünen alanın dışındaki bir noktada hover üretmez.
        await tester.ensureVisible(find.text(Contact.phoneDisplay));
        await tester.pump();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: const Offset(5, 5));
        await mouse.moveTo(tester.getCenter(find.text(Contact.phoneDisplay)));
        await tester.pump(const Duration(milliseconds: 300));
        expect(arrowColor(), palette.accentText);

        await mouse.moveTo(const Offset(5, 5));
        await tester.pump(const Duration(milliseconds: 300));
        expect(arrowColor(), palette.textDim);
      });
    }

    testWidgets('TeklifBand: "Teklif Pro" düğmesi Contact.teklifPro bağlantısını açar (dokunma)', (tester) async {
      setView(tester, 390);
      final opened = <String>[];
      await tester.pumpWidget(host(TeklifBand(onOpenLink: (url) async => opened.add(url))));
      await settle(tester);
      await tester.tap(find.text('Teklif Pro'));
      await tester.pump();
      expect(opened, [Contact.teklifPro]);
    });

    testWidgets('TeklifBand: "Teklif Pro" düğmesi klavye ile (Tab + Enter / Boşluk) etkinleşir', (tester) async {
      setView(tester, 1440);
      final opened = <String>[];
      await tester.pumpWidget(host(TeklifBand(onOpenLink: (url) async => opened.add(url))));
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(opened, [Contact.teklifPro, Contact.teklifPro]);
    });

    for (final brightness in Brightness.values) {
      testWidgets('TeklifBand (${brightness.name}): klavye odağı düğmeye vurgu çerçevesi çizer', (tester) async {
        setView(tester, 1440);
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        await tester.pumpWidget(host(TeklifBand(onOpenLink: (_) async {}), brightness: brightness));
        await settle(tester);
        Color borderColor() {
          final box = find.descendant(of: find.byType(AnimatedContainer), matching: find.byType(DecoratedBox)).first;
          return ((tester.widget<DecoratedBox>(box).decoration as BoxDecoration).border! as Border).top.color;
        }

        expect(borderColor(), Colors.transparent);
        // Çerçeve rengi 180 ms'de animasyonla değişir; animasyon ilk karede başlar, ikinci karede biter.
        Future<void> animate() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await animate();
        expect(borderColor(), paletteOf(brightness).accent);
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('TeklifBand (${brightness.name}): dışa gitme oku etiketin SAĞINDA, düğme rengiyle çizilir', (tester) async {
        setView(tester, 1440);
        await tester.pumpWidget(host(const TeklifBand(), brightness: brightness));
        await settle(tester);
        final label = tester.getRect(find.text('Teklif Pro'));
        final arrowFinder = find.descendant(
          of: find.byType(TeklifBand),
          matching: find.byWidgetPredicate((w) => w is LineIcon && w.glyph == LineGlyph.arrowUpRight),
        );
        expect(arrowFinder, findsOneWidget);
        final arrow = tester.getRect(arrowFinder);
        expect(arrow.left, greaterThanOrEqualTo(label.right), reason: 'ok etiketin sağında');
        expect((arrow.center.dy - label.center.dy).abs(), lessThan(3), reason: 'ok etiketle aynı hizada');
        expect(tester.widget<LineIcon>(arrowFinder).color, paletteOf(brightness).filledFg);
      });
    }
  });

  group('ScreenDoorScene etkileşim', () {
    testWidgets('onContact, "Teklif İsteyin" düğmesiyle çağrılır', (tester) async {
      setView(tester, 1440);
      var calls = 0;
      await tester.pumpWidget(host(ScreenDoorScene(onContact: () => calls++)));
      await settle(tester);
      await tester.tap(find.text('Teklif İsteyin'));
      await tester.pump();
      expect(calls, 1);
      await teardownTree(tester);
    });

    testWidgets('onContact verilmezse düğme gösterilmez', (tester) async {
      setView(tester, 1440);
      await tester.pumpWidget(host(const ScreenDoorScene()));
      await settle(tester);
      expect(find.text('Teklif İsteyin'), findsNothing);
      await teardownTree(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets('cihazın butonuna basmak ekranı "KAPI AÇILDI" yapar (${brightness.name}; sahne dokunmayı engellemez)', (tester) async {
        setView(tester, 1440);
        await tester.pumpWidget(host(const ScreenDoorScene(), brightness: brightness));
        await settle(tester);
        expect(find.text('KAPI AÇILDI'), findsNothing);

        await pressDeviceButton(tester);
        expect(find.text('KAPI AÇILDI'), findsOneWidget);

        // Cihaz kendiliğinden eski haline döner; bekleyen zamanlayıcı kalmaz.
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('KAPI AÇILDI'), findsNothing);
        await teardownTree(tester);
      });
    }

    Text countdown(WidgetTester tester) => tester.widget<Text>(find.textContaining('Kalan Süre', skipOffstage: false));
    AhbuDevice device(WidgetTester tester) => tester.widget<AhbuDevice>(find.byType(AhbuDevice, skipOffstage: false));

    for (final brightness in Brightness.values) {
      testWidgets('hareketi azalt açıkken cihaz ANINDA görünür, etkileşimlidir ve durağandır (${brightness.name})', (tester) async {
        setView(tester, 1440);
        await tester.pumpWidget(host(const ScreenDoorScene(), brightness: brightness, reduceMotion: true));
        // Hiçbir kare ilerletilmeden: giriş animasyonu yok, cihaz ve ipucu tam opaklıkta.
        expect(effectiveOpacity(tester, find.byType(AhbuDevice)), 1.0);
        expect(find.text('Butona basarak deneyin'), findsOneWidget);
        expect(effectiveOpacity(tester, find.text('Butona basarak deneyin')), 1.0);
        expect(effectiveOpacity(tester, find.text('AHBU Akıllı Kapı Kontrol')), 1.0, reason: 'başlık da anında görünür');

        // Yüzme döngüsü ve karekod sayacı durmuştur.
        expect(device(tester).paused, isTrue);
        final before = countdown(tester).data;
        await settle(tester);
        await tester.pump(const Duration(seconds: 3));
        expect(countdown(tester).data, before, reason: 'sayaç ilerlemez');
        expect(tester.binding.transientCallbackCount, 0, reason: 'yüzme animasyonu kare istemez');

        // Cihaz yine de çalışır: butona basınca ekran "KAPI AÇILDI" olur.
        await pressDeviceButton(tester);
        expect(find.text('KAPI AÇILDI'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pump(const Duration(milliseconds: 500));
      });
    }

    testWidgets('hareket serbestken giriş animasyonu oynar (ilk karede görünmez), sonra cihaz canlıdır', (tester) async {
      setView(tester, 1440);
      await tester.pumpWidget(host(const ScreenDoorScene()));
      // Test sahte değil: aynı ölçüt, hareket serbestken ilk karede cihazın henüz görünmediğini gösterir.
      expect(effectiveOpacity(tester, find.byType(AhbuDevice)), lessThan(1.0));
      await settle(tester);
      expect(effectiveOpacity(tester, find.byType(AhbuDevice)), 1.0);
      expect(device(tester).paused, isFalse);
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'yüzme animasyonu çalışıyor');
      final before = countdown(tester).data;
      await tester.pump(const Duration(seconds: 3));
      expect(countdown(tester).data, isNot(before), reason: 'karekod sayacı ilerler');
      await teardownTree(tester);
    });

    testWidgets('cihaza verilen zemin gölgesi temanın c.shadow rengidir', (tester) async {
      setView(tester, 1440);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(host(const ScreenDoorScene(), brightness: brightness));
        await settle(tester);
        expect(device(tester).shadowColor, paletteOf(brightness).shadow);
        await teardownTree(tester);
      }
    });

    testWidgets('sahne ekran dışındayken cihaz durur (yüzme + sayaç), görününce yeniden canlanır', (tester) async {
      setView(tester, 1440);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(const Column(children: [SizedBox(height: 4000), ScreenDoorScene()]), controller: controller));
      await settle(tester);
      expect(controller.offset, 0);
      expect(device(tester).paused, isTrue, reason: 'sahne 4000 px aşağıda, ekran dışında');
      expect(tester.binding.transientCallbackCount, 0, reason: 'ekran dışında yüzme animasyonu kare istemez');
      final offscreen = countdown(tester).data;
      await tester.pump(const Duration(seconds: 3));
      expect(countdown(tester).data, offscreen, reason: 'ekran dışında sayaç ilerlemez');

      controller.jumpTo(3800);
      await settle(tester);
      expect(device(tester).paused, isFalse);
      expect(effectiveOpacity(tester, find.byType(AhbuDevice)), 1.0, reason: 'görününce giriş animasyonu tamamlanır');
      final visible = countdown(tester).data;
      await tester.pump(const Duration(seconds: 3));
      expect(countdown(tester).data, isNot(visible), reason: 'görününce sayaç ilerler');

      controller.jumpTo(0);
      await settle(tester);
      expect(device(tester).paused, isTrue);
      await tester.pump(const Duration(seconds: 1));
      // Duraklatılmış cihaz bekleyen zamanlayıcı bırakmaz: ağaç sökülmeden test hata vermeden biter.
    });

    testWidgets('sahne ekranın üstünden ya da altından taşmışken cihaz durur (pay yok), kesişince canlanır', (tester) async {
      // AN-03: Hizmetler'e yerleşince cihaz alt kenarı ekranın ~140 px üstündeyken hâlâ canlı sayılıyordu.
      const viewportHeight = 1000.0;
      setView(tester, 412, viewportHeight);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(host(const Column(children: [SizedBox(height: 4000), ScreenDoorScene(), SizedBox(height: 4000)]), controller: controller));
      await settle(tester);
      final stage = find.byType(VisibilityProbe, skipOffstage: false);
      Rect stageRect() => tester.getRect(stage);
      final stageTop = stageRect().top; // kaydırma 0 iken belge konumu
      final stageHeight = stageRect().height;

      Future<void> scrollSo(double stageTopOnScreen) async {
        controller.jumpTo(stageTop - stageTopOnScreen);
        await settle(tester);
      }

      await scrollSo(100); // tam görünür
      expect(device(tester).paused, isFalse);

      await scrollSo(-stageHeight + 1); // 1 px kesişiyor
      expect(device(tester).paused, isFalse, reason: 'gerçek kesişim varken canlı');

      for (final gap in [1.0, 60.0, 140.0, 159.0]) {
        await scrollSo(-stageHeight - gap); // sahne ekranın üstünde, boşluk kadar dışarıda
        expect(stageRect().bottom, lessThan(0));
        expect(device(tester).paused, isTrue, reason: 'sahne ekranın $gap px üstünde: durmalı');
        expect(tester.binding.transientCallbackCount, 0);
      }

      await scrollSo(viewportHeight + 40); // sahne ekranın altında, 40 px dışarıda
      expect(device(tester).paused, isTrue, reason: 'ekranın altındaki sahne de durur');

      await scrollSo(viewportHeight - 1); // alttan 1 px kesişiyor
      expect(device(tester).paused, isFalse);
      await teardownTree(tester);
    });

    testWidgets('yerleşim: masaüstü ve tablette cihaz solda, metin sağda; dar tablette araya; telefonda altta', (tester) async {
      Future<(Rect, Rect, Rect)> rects(double width) async {
        setView(tester, width, 1200);
        await tester.pumpWidget(host(ScreenDoorScene(onContact: () {})));
        await settle(tester);
        final device = tester.getRect(find.byType(AhbuDevice));
        final title = tester.getRect(find.text('AHBU Akıllı Kapı Kontrol'));
        final firstFeature = tester.getRect(find.text('Dinamik karekod'));
        await teardownTree(tester);
        return (device, title, firstFeature);
      }

      for (final width in [1440.0, 1024.0, 768.0, ScreenDoorScene.sideBySideFrom]) {
        final (device, title, _) = await rects(width);
        expect(device.right, lessThan(title.left), reason: '$width px: cihaz metnin solunda');
        expect(device.center.dx, lessThan(width / 2), reason: '$width px');
        expect(device.top, lessThan(900), reason: '$width px: cihaz ilk ekranda görünür');
        expect(device.bottom, lessThan(900), reason: '$width px: cihaz ilk ekrana tam sığar');
      }

      // Dar tablet: cihaz başlık ile maddeler arasında, ortalı.
      for (final width in [600.0, 650.0, 719.0]) {
        final (device, title, firstFeature) = await rects(width);
        expect(device.top, greaterThan(title.bottom), reason: '$width px: cihaz başlığın altında');
        expect(device.bottom, lessThan(firstFeature.top), reason: '$width px: cihaz ilk maddenin üstünde');
        expect(device.center.dx, closeTo(width / 2, 1), reason: '$width px: cihaz ortalı');
      }

      // Telefon: metin üstte, cihaz en altta.
      for (final width in [390.0, 360.0]) {
        final (device, title, firstFeature) = await rects(width);
        expect(device.top, greaterThan(firstFeature.bottom), reason: '$width px: telefonda cihaz maddelerin altında');
        expect(device.top, greaterThan(title.bottom));
        expect(device.center.dx, closeTo(width / 2, 1), reason: '$width px: telefonda cihaz ortalı');
      }
    });
  });
}
