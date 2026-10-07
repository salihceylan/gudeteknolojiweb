import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/scenes/process_scene.dart';
import 'package:gudeteknolojiweb/scenes/references_scene.dart';
import 'package:gudeteknolojiweb/scenes/services_scene.dart';
import 'package:gudeteknolojiweb/theme.dart';
import 'package:gudeteknolojiweb/widgets/common.dart';

import 'helpers/app.dart';
import 'helpers/shot.dart';

const _widths = <double>[360, 390, 768, 1024, 1440];

/// Sahneyi gerçek sayfadaki gibi kaydırılabilir bir alanda, iki temalı uygulamada kurar.
Widget _host(
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool disableAnimations = false,
  ScrollController? controller,
}) {
  return testApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: disableAnimations),
        child: Scaffold(body: SingleChildScrollView(controller: controller, child: child)),
      ),
    ),
    brightness: brightness,
  );
}

/// Pencere boyutunu ayarlar ve animasyonların bitmesini bekler.
Future<void> _pump(WidgetTester tester, Widget app, {required double width, double height = 1800}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  // Reveal gecikmeleri bir Timer ile çalışır (kare istemez); önce onları tüket, sonra animasyonları bitir.
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

AppColors _tokens(Brightness b) => b == Brightness.dark ? AppColors.dark : AppColors.light;

/// WCAG göreli parlaklık ve kontrast oranı (test/theme_test.dart ile aynı formül).
double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color fg, Color bg) {
  final f = Color.alphaBlend(fg, bg);
  final a = _lum(f), b = _lum(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void _expectInside(Rect inner, Rect outer, String reason) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.5), reason: '$reason (sol)');
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.5), reason: '$reason (üst)');
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.5), reason: '$reason (sağ)');
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.5), reason: '$reason (alt)');
}

/// Bölümün içerik alanı (kMaxContent ile sınırlı, yan boşlukları düşülmüş).
Rect _content(WidgetTester tester) => tester.getRect(
      find.descendant(
        of: find.byType(Section),
        matching: find.byWidgetPredicate((w) => w is ConstrainedBox && w.constraints.maxWidth == kMaxContent),
      ),
    );

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

ProcessRailPainter _rail(WidgetTester tester, int i) => tester.widget<CustomPaint>(find.byKey(ValueKey('process-rail-$i'))).painter! as ProcessRailPainter;

double _progressOf(WidgetTester tester, [int rail = 0]) => _rail(tester, rail).progress.value;

Rect _card(WidgetTester tester, int i) => tester.getRect(find.byKey(ValueKey('service-card-$i')));

DecoratedBox _cardBox(WidgetTester tester, int i) =>
    tester.widget<DecoratedBox>(find.descendant(of: find.byKey(ValueKey('service-card-$i')), matching: find.byType(DecoratedBox)).first);

void main() {
  setUpAll(loadAppFonts);

  for (final brightness in Brightness.values) {
    final c = _tokens(brightness);
    Widget host(Widget child, {double textScale = 1, bool disableAnimations = false, ScrollController? controller}) =>
        _host(child, brightness: brightness, textScale: textScale, disableAnimations: disableAnimations, controller: controller);

    group('${brightness.name} tema', () {
      group('metinler şartnameyle birebir', () {
        testWidgets('ServicesScene', (tester) async {
          await _pump(tester, host(const ServicesScene()), width: 1440);
          for (final t in const [
            'HİZMETLERİMİZ',
            'Teknolojiyi projenin ihtiyacına göre uygularız.',
            'İnterkom Sistemleri',
            'IP ve iki telli görüntülü interkom sistemleri, güvenlik ve daire iletişim çözümleri',
            'Geçiş Kontrol',
            'Kartlı geçiş, kapı kontrolü, personel erişimi ve merkezi yönetim sistemleri',
            'Turnike ve Bariyer',
            'Personel ve araç geçişlerinin kontrolü için turnike ve bariyer çözümleri',
            'Yangın Algılama',
            'Yangın algılama, ihbar ve projeye uygun güvenlik sistemleri',
            'Akıllı Ev Sistemleri',
            'Aydınlatma, kontrol, güvenlik ve otomasyon sistemlerinin entegre çözümleri',
            '01',
            '02',
            '03',
            '04',
            '05',
          ]) {
            expect(find.text(t), findsOneWidget, reason: t);
          }
        });

        testWidgets('ProcessScene', (tester) async {
          await _pump(tester, host(const ProcessScene()), width: 1440);
          for (final t in const [
            'ÇALIŞMA ŞEKLİMİZ',
            'Projeden sahaya tek noktadan çözüm.',
            'Sadece ürün temin eden değil, doğru sistemi tasarlayan ve sahada çalışır hale getiren bir teknik çözüm yaklaşımıyla çalışıyoruz.',
            'Keşif',
            'Saha ve ihtiyaç analizi',
            'Projelendirme',
            'Doğru ürün ve altyapı seçimi',
            'Uygulama',
            'Kurulum ve devreye alma',
            'Servis',
            'Bakım ve teknik destek',
          ]) {
            expect(find.text(t), findsOneWidget, reason: t);
          }
        });

        testWidgets('ReferencesScene', (tester) async {
          await _pump(tester, host(const ReferencesScene()), width: 1440);
          for (final t in const ['REFERANSLAR', 'Bazı projelerimiz.', 'Folkart Life', 'Folkart Time', 'Sinpaş Aqua City', 'Manisa Meydan Projesi', 'TÜPRAŞ Teknik Yapı']) {
            expect(find.text(t), findsOneWidget, reason: t);
          }
        });
      });

      group('taşma yok; metinler kartların / içerik alanının içinde kalır', () {
        final scenes = <String, Widget>{'services': const ServicesScene(), 'process': const ProcessScene(), 'references': const ReferencesScene()};
        for (final entry in scenes.entries) {
          for (final w in _widths) {
            for (final scale in const [1.0, 1.5]) {
              testWidgets('${entry.key} $w px, yazı ölçeği $scale', (tester) async {
                await _pump(tester, host(entry.value, textScale: scale), width: w, height: 3000);
                expect(tester.takeException(), isNull);
                // Sahne bütün genişliği kaplar; içerik yatayda taşmaz.
                final box = tester.getRect(find.byType(Section));
                expect(box.left, 0);
                expect(box.right, w);
                final content = _content(tester);
                for (final text in tester.widgetList<Text>(find.byType(Text))) {
                  final rect = tester.getRect(find.byWidget(text));
                  expect(rect.right, lessThanOrEqualTo(w + 0.5), reason: '"${text.data}" ekran dışına taşıyor');
                  _expectInside(rect, content, '"${text.data}" içerik alanı dışında');
                }
                // Kart/hücre bazlı: her metin ve ikon kendi kutusunun içinde kalmalı.
                final boxes = {'services': 'service-card-', 'references': 'reference-cell-'}[entry.key];
                if (boxes != null) {
                  for (var i = 0; i < 5; i++) {
                    final key = find.byKey(ValueKey('$boxes$i'));
                    final outer = tester.getRect(key);
                    for (final inner in [...tester.widgetList<Text>(find.descendant(of: key, matching: find.byType(Text)))]) {
                      _expectInside(tester.getRect(find.byWidget(inner)), outer, '"${inner.data}" kutusunun dışına taştı');
                    }
                    for (final icon in tester.widgetList<Icon>(find.descendant(of: key, matching: find.byType(Icon)))) {
                      _expectInside(tester.getRect(find.byWidget(icon)), outer, 'ikon kutusunun dışına taştı');
                    }
                  }
                }
              });
            }
          }
        }
      });

      group('bölüm iskeleti', () {
        final scenes = <String, ({Widget scene, Color Function() bg, String title})>{
          'services': (scene: const ServicesScene(), bg: () => c.bgAlt, title: 'Teknolojiyi projenin ihtiyacına göre uygularız.'),
          'process': (scene: const ProcessScene(), bg: () => c.bg, title: 'Projeden sahaya tek noktadan çözüm.'),
          'references': (scene: const ReferencesScene(), bg: () => c.bgAlt, title: 'Bazı projelerimiz.'),
        };
        for (final entry in scenes.entries) {
          testWidgets('${entry.key}: zemin temadan, üstte ince ayraç, dikey boşluk fluid(64, 112)', (tester) async {
            for (final w in [360.0, 768.0, 1440.0]) {
              await _pump(tester, host(entry.value.scene), width: w);
              expect(tester.widget<Section>(find.byType(Section)).color, entry.value.bg());
              expect(find.byType(HairlineDivider), findsOneWidget);
              final top = tester.getTopLeft(find.byType(Eyebrow)).dy - tester.getTopLeft(find.byType(Section)).dy;
              expect(top, closeTo(64 + 48 * ((w - 360) / 1080).clamp(0.0, 1.0), 0.5), reason: '$w px');
            }
          });

          testWidgets('${entry.key}: başlık Semantics(header) olarak işaretli', (tester) async {
            final handle = tester.ensureSemantics();
            await _pump(tester, host(entry.value.scene), width: 1024);
            final data = tester.getSemantics(find.text(entry.value.title)).getSemanticsData();
            expect(data.flagsCollection.isHeader, isTrue);
            expect(data.label, entry.value.title);
            handle.dispose();
          });
        }

        testWidgets('zeminler dönüşümlü: Hizmetler bgAlt, Süreç bg, Referanslar bgAlt', (tester) async {
          Future<Color?> bgOf(Widget scene) async {
            await _pump(tester, host(scene), width: 1024);
            return tester.widget<Section>(find.byType(Section)).color;
          }

          expect(await bgOf(const ServicesScene()), c.bgAlt);
          expect(await bgOf(const ProcessScene()), c.bg);
          expect(await bgOf(const ReferencesScene()), c.bgAlt);
          expect(c.bg, isNot(c.bgAlt));
        });
      });

      group('ServicesScene yerleşimi', () {
        testWidgets('masaüstü: sabit 3 sütun, son satır sola hizalı, kart genişlikleri eşit', (tester) async {
          for (final w in [1024.0, 1440.0]) {
            await _pump(tester, host(const ServicesScene()), width: w);
            final r = [for (var i = 0; i < 5; i++) _card(tester, i)];
            // Aynı satırda aynı üst kenar ve eşit yükseklik.
            expect(r[0].top, r[1].top);
            expect(r[1].top, r[2].top);
            expect(r[0].height, r[1].height);
            expect(r[1].height, r[2].height);
            expect(r[3].top, r[4].top);
            expect(r[3].height, r[4].height);
            expect(r[3].top, greaterThan(r[0].bottom));
            // Sütun hizaları satırlar arasında tutar; 5 kartın hepsi aynı genişlikte.
            expect(r[3].left, r[0].left);
            expect(r[4].left, r[1].left);
            for (final card in r) {
              expect(card.width, closeTo(r[0].width, 0.01), reason: '$w px');
            }
            // Üçüncü sütun son satırda boş kalır.
            expect(r[4].right, lessThan(r[2].left));
          }
        });

        testWidgets('tablet: 2 sütun; 5. kart tek başına genişlemez, sola hizalı kalır', (tester) async {
          await _pump(tester, host(const ServicesScene()), width: 768);
          final r = [for (var i = 0; i < 5; i++) _card(tester, i)];
          expect(r[0].top, r[1].top);
          expect(r[2].top, r[3].top);
          expect(r[2].top, greaterThan(r[0].bottom));
          expect(r[4].top, greaterThan(r[2].bottom));
          expect(r[4].left, r[0].left);
          expect(r[2].left, r[0].left);
          expect(r[3].left, r[1].left);
          for (final card in r) {
            expect(card.width, closeTo(r[0].width, 0.01));
          }
          expect(r[4].right, lessThan(r[1].left));
        });

        testWidgets('telefon: tek sütun, hepsi aynı hizada ve tam genişlikte', (tester) async {
          for (final w in [360.0, 390.0]) {
            await _pump(tester, host(const ServicesScene()), width: w);
            final r = [for (var i = 0; i < 5; i++) _card(tester, i)];
            for (var i = 0; i < 5; i++) {
              expect(r[i].left, r[0].left);
              expect(r[i].width, closeTo(_content(tester).width, 0.01));
              if (i > 0) expect(r[i].top, greaterThan(r[i - 1].bottom));
            }
          }
        });
      });

      group('kontrast', () {
        testWidgets('Hizmetler: "01-05" numaraları textDim, kart yüzeyinde ≥ 4.5:1', (tester) async {
          await _pump(tester, host(const ServicesScene()), width: 1440);
          for (var i = 1; i <= 5; i++) {
            final style = tester.widget<Text>(find.text('0$i')).style!;
            expect(style.color, c.textDim, reason: 'numara 0$i textFaint değil textDim olmalı');
            expect(_contrast(style.color!, c.surface), greaterThanOrEqualTo(4.5), reason: '0$i');
          }
        });

        testWidgets('Süreç: adım numaraları textDim, bölüm zemininde ≥ 4.5:1', (tester) async {
          await _pump(tester, host(const ProcessScene()), width: 1440);
          for (var i = 1; i <= 4; i++) {
            final style = tester.widget<Text>(find.text('0$i')).style!;
            expect(style.color, c.textDim);
            expect(_contrast(style.color!, c.bg), greaterThanOrEqualTo(4.5), reason: '0$i');
          }
        });
      });

      group('ServicesScene vurgusu', () {
        testWidgets('üzerine gelince ikon açılır, alt çizgi turkuaz uzar, kart yükselir; ayrılınca geri döner', (tester) async {
          await _pump(tester, host(const ServicesScene()), width: 1440);
          Color? iconColor(IconData d) => tester.widget<Icon>(find.byIcon(d)).color;
          double line(int i) => tester.widget<FractionallySizedBox>(find.byKey(ValueKey('service-line-$i'))).widthFactor!;
          Color? number(String t) => tester.widget<Text>(find.text(t)).style!.color;
          final cardTop = tester.getTopLeft(find.text('Geçiş Kontrol')).dy;

          expect(iconColor(Icons.badge_outlined), c.textDim);
          expect(line(1), 0);

          final mouse = await _mouse(tester);
          await mouse.moveTo(tester.getCenter(find.text('Geçiş Kontrol')));
          await tester.pumpAndSettle();

          expect(iconColor(Icons.badge_outlined), c.text);
          expect(line(1), 1);
          final lineBox = find.descendant(of: find.byKey(const ValueKey('service-line-1')), matching: find.byType(ColoredBox));
          expect(tester.widget<ColoredBox>(lineBox).color, c.accent);
          expect(number('02'), c.accentText);
          expect(tester.getTopLeft(find.text('Geçiş Kontrol')).dy, lessThan(cardTop), reason: 'kart yukarı kaymalı');
          // Yalnızca üzerine gelinen kart vurgulanır.
          expect(iconColor(Icons.doorbell_outlined), c.textDim);
          expect(line(0), 0);
          expect(number('01'), c.textDim);

          await mouse.moveTo(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(iconColor(Icons.badge_outlined), c.textDim);
          expect(line(1), 0);
          expect(number('02'), c.textDim);
          expect(tester.getTopLeft(find.text('Geçiş Kontrol')).dy, cardTop);
        });

        testWidgets('kart RepaintBoundary içinde; dinlenmede gradyan ve gölge kurulmaz, vurguda kurulur', (tester) async {
          await _pump(tester, host(const ServicesScene()), width: 1440);
          for (var i = 0; i < 5; i++) {
            expect(tester.widget(find.byKey(ValueKey('service-card-$i'))), isA<RepaintBoundary>());
          }
          var d = _cardBox(tester, 1).decoration as BoxDecoration;
          expect(d.gradient, isNull, reason: 'dinlenmede gradyan yok');
          expect(d.boxShadow, isNull);
          expect(d.color, c.surface);
          expect(d.border, isNotNull);

          final mouse = await _mouse(tester);
          await mouse.moveTo(tester.getCenter(find.text('Geçiş Kontrol')));
          await tester.pumpAndSettle();
          d = _cardBox(tester, 1).decoration as BoxDecoration;
          expect(d.gradient, isNotNull);
          expect(d.boxShadow, isNotEmpty);
          // Vurgusuz kartlar dinlenme halinde kalır.
          expect((_cardBox(tester, 0).decoration as BoxDecoration).gradient, isNull);

          await mouse.moveTo(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect((_cardBox(tester, 1).decoration as BoxDecoration).gradient, isNull);
        });

        testWidgets('vurgulu kartta yazılar okunaklı: başlık ≥ 7:1, gövde ve numara ≥ 4.5:1 (yüzey ve gradyan uçlarında)', (tester) async {
          await _pump(tester, host(const ServicesScene()), width: 1440);
          final mouse = await _mouse(tester);
          await mouse.moveTo(tester.getCenter(find.text('Geçiş Kontrol')));
          await tester.pumpAndSettle();
          final d = _cardBox(tester, 1).decoration as BoxDecoration;
          final surfaces = <Color>[d.color!, ...(d.gradient! as RadialGradient).colors];
          for (final s in surfaces) {
            expect(_contrast(c.text, s), greaterThanOrEqualTo(7), reason: 'başlık / $s');
            expect(_contrast(c.textDim, s), greaterThanOrEqualTo(4.5), reason: 'gövde / $s');
            expect(_contrast(c.accentText, s), greaterThanOrEqualTo(4.5), reason: 'numara / $s');
          }
        });

        testWidgets('hareketi azalt: kart kaymaz, yalnızca renk değişir', (tester) async {
          await _pump(tester, host(const ServicesScene(), disableAnimations: true), width: 1440);
          final top = tester.getTopLeft(find.text('Geçiş Kontrol')).dy;
          final mouse = await _mouse(tester);
          await mouse.moveTo(tester.getCenter(find.text('Geçiş Kontrol')));
          await tester.pump();
          await tester.pump();
          expect(tester.getTopLeft(find.text('Geçiş Kontrol')).dy, top);
          expect(tester.widget<Icon>(find.byIcon(Icons.badge_outlined)).color, c.text);
        });
      });

      group('ProcessScene çizgisi', () {
        testWidgets('masaüstü: çizgi birim birim sırayla uzar (adım adım, tek yay değil), son sütunun sonuna kadar gider ve yerinde durur', (tester) async {
          tester.view.physicalSize = const Size(1440, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(host(const ProcessScene()));
          expect(tester.widget<Section>(find.byType(Section)).color, c.bg);

          // 4 düğüm + 1 kuyruk birimi = 5 birim, her biri ≥ 600 ms. İlerleme asla "geçen süre / 600 ms" birimini aşamaz:
          // tek bir global yay olsaydı ilk 700 ms'de 2.5 birime ulaşırdı.
          var last = 0.0;
          var t = 0;
          while (t < 5000) {
            await tester.pump(const Duration(milliseconds: 16));
            t += 16;
            final p = _progressOf(tester);
            expect(p, greaterThanOrEqualTo(last), reason: 'ilerleme geri gitmez ($t ms)');
            expect(p, lessThanOrEqualTo((t / 600).ceil() + 1e-9), reason: 'sıralı birimler ($t ms)');
            last = p;
          }
          expect(last, 5, reason: '4 düğüm + kuyruk');
          // Kuyruk dahil bütün parçalar aynı ilerlemeyi dinler.
          for (var i = 1; i < 4; i++) {
            expect(_rail(tester, i).progress, same(_rail(tester, 0).progress));
          }
          // Tek seferlik: bitince hiçbir kare istenmez (sonsuz döngü yok).
          await tester.pumpAndSettle();
          expect(tester.binding.hasScheduledFrame, isFalse);
          expect(_progressOf(tester), 5);
        });

        testWidgets('masaüstü: çizgi son sütunun sonuna (içerik alanının sağ kenarına) kadar uzanır; diğer parçalar sütunda biter', (tester) async {
          await _pump(tester, host(const ProcessScene()), width: 1440);
          final content = _content(tester);
          final lastRect = tester.getRect(find.byKey(const ValueKey('process-rail-3')));
          expect(lastRect.right, closeTo(content.right, 0.01));
          final lastWidth = lastRect.width;
          expect(tester.renderObject(find.byKey(const ValueKey('process-rail-3'))), paints..line(p2: Offset(lastWidth, 8)));
          // İlk parça bir sonraki düğümden önce biter.
          final firstWidth = tester.getSize(find.byKey(const ValueKey('process-rail-0'))).width;
          expect(tester.renderObject(find.byKey(const ValueKey('process-rail-0'))), isNot(paints..line(p2: Offset(firstWidth, 8))));
        });

        testWidgets('painter temanın renklerini kurucudan alır', (tester) async {
          await _pump(tester, host(const ProcessScene()), width: 1440);
          final p = _rail(tester, 1);
          expect(p.track, c.lineStrong);
          expect(p.active, c.accent);
          expect(p.background, c.bg);
          await _pump(tester, host(const ProcessScene()), width: 390);
          expect(_rail(tester, 1).active, c.accent);
        });

        testWidgets('sahne ekran dışındayken çizgi beklemede kalır', (tester) async {
          tester.view.physicalSize = const Size(1440, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(host(const Column(children: [SizedBox(height: 3000), ProcessScene()]), controller: controller));
          await tester.pump(const Duration(seconds: 2));
          expect(_progressOf(tester), 0, reason: 'sahne henüz görünmüyor');

          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(_progressOf(tester), greaterThan(0));
          await tester.pumpAndSettle();
          expect(_progressOf(tester), 5);
        });

        testWidgets('mobil: çizgi adım-bazlı; yavaş kaydıran kullanıcı henüz görmediği segmentin uzadığını kaçırmaz', (tester) async {
          tester.view.physicalSize = const Size(390, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(host(const Column(children: [SizedBox(height: 3000), ProcessScene()]), controller: controller));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(_progressOf(tester), 0, reason: 'sahne ekran dışında');

          /// Başlığı [name] olan adımın metnini ekranda [y] hizasına getirir (adımın üst kenarı bunun ~22 px üstündedir).
          Future<void> scrollTitleTo(String name, double y) async {
            controller.jumpTo(controller.offset + tester.getTopLeft(find.text(name)).dy - y);
            await tester.pump();
            await tester.pumpAndSettle();
          }

          // Yalnızca ilk adım ekrana girdi (ikinci adım ekranın %86'sının altında): yalnızca ilk düğüm yanar.
          await scrollTitleTo('Keşif', 672);
          expect(tester.getTopLeft(find.text('Projelendirme')).dy, greaterThan(800 * 0.86 + 22));
          expect(_progressOf(tester), 1);

          // Üçüncü adıma kadar görüldü, dördüncü ekranın hemen altında: çizgi 3. düğüme kadar gelir, 4. segment beklemede.
          await scrollTitleTo('Servis', 790);
          expect(_progressOf(tester), 3, reason: 'Servis adımı henüz görünmüyor');

          // Dördüncü adım görününce son segment uzar ve son düğüm yanar.
          await scrollTitleTo('Servis', 600);
          expect(_progressOf(tester), 4);

          // Geri kaydırınca çizgi geri çekilmez.
          controller.jumpTo(0);
          await tester.pumpAndSettle();
          expect(_progressOf(tester), 4);
          expect(tester.binding.hasScheduledFrame, isFalse);
        });

        testWidgets('mobil: bir kerede aşağı sıçrayınca birimler yine sırayla oynar (çizgi düğümlerden önce uzamaz)', (tester) async {
          tester.view.physicalSize = const Size(390, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(host(const Column(children: [SizedBox(height: 3000), ProcessScene()]), controller: controller));
          await tester.pump(const Duration(seconds: 1));
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pump();
          var t = 0;
          while (t < 3000) {
            await tester.pump(const Duration(milliseconds: 16));
            t += 16;
            expect(_progressOf(tester), lessThanOrEqualTo((t / 600).ceil() + 1e-9), reason: '$t ms');
          }
          await tester.pumpAndSettle();
          expect(_progressOf(tester), 4);
        });

        for (final (name, width, units) in [('masaüstü', 1440.0, 5.0), ('mobil', 390.0, 4.0)]) {
          testWidgets('hareketi azalt ($name): çizgi anında tamamlanır', (tester) async {
            tester.view.physicalSize = Size(width, 1800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(host(const ProcessScene(), disableAnimations: true));
            await tester.pump();
            await tester.pump();
            expect(_progressOf(tester), units);
            // Reveal gecikme zamanlayıcılarını tüket.
            await tester.pump(const Duration(seconds: 1));
            await tester.pumpAndSettle();
            expect(_progressOf(tester), units);
          });
        }

        testWidgets('masaüstünde adımlar yatay, telefonda dikey dizilir', (tester) async {
          Offset at(String t) => tester.getTopLeft(find.text(t));

          await _pump(tester, host(const ProcessScene()), width: 1440);
          expect(at('Keşif').dy, at('Servis').dy);
          expect(at('Servis').dx, greaterThan(at('Uygulama').dx));

          await _pump(tester, host(const ProcessScene()), width: 390);
          expect(at('Keşif').dx, at('Servis').dx);
          expect(at('Servis').dy, greaterThan(at('Keşif').dy));
        });
      });

      group('ReferencesScene', () {
        testWidgets('akan yazı yok: bekleyen kare yok, görsel yok', (tester) async {
          await _pump(tester, host(const ReferencesScene()), width: 1440);
          expect(tester.binding.hasScheduledFrame, isFalse);
          expect(find.byType(Image), findsNothing);
        });

        testWidgets('sütunlar satırlar arasında hizalı: 3+2 / 2+2+1 / 1', (tester) async {
          double y(String t) => tester.getTopLeft(find.text(t)).dy;
          double x(String t) => tester.getTopLeft(find.text(t)).dx;

          await _pump(tester, host(const ReferencesScene()), width: 1440);
          expect(y('Folkart Life'), y('Sinpaş Aqua City'));
          expect(y('Manisa Meydan Projesi'), greaterThan(y('Folkart Life')));
          expect(y('Manisa Meydan Projesi'), y('TÜPRAŞ Teknik Yapı'));
          expect(x('Manisa Meydan Projesi'), x('Folkart Life'));
          expect(x('TÜPRAŞ Teknik Yapı'), x('Folkart Time'));

          await _pump(tester, host(const ReferencesScene()), width: 768);
          expect(y('Folkart Life'), y('Folkart Time'));
          expect(x('TÜPRAŞ Teknik Yapı'), x('Folkart Life'));

          await _pump(tester, host(const ReferencesScene()), width: 390);
          expect(x('Folkart Life'), x('TÜPRAŞ Teknik Yapı'));
        });

        testWidgets('çizgiler temadan: üst çizgi lineStrong, son satır alt çizgiyle kapanır', (tester) async {
          await _pump(tester, host(const ReferencesScene()), width: 1440);
          int strongLines(int i) => tester
              .widgetList<ColoredBox>(find.descendant(of: find.byKey(ValueKey('reference-cell-$i')), matching: find.byType(ColoredBox)))
              .where((b) => b.color == c.lineStrong)
              .length;
          // 3 sütun: 0-2 yalnız üst çizgi, 3-4 üst + alt.
          expect([for (var i = 0; i < 5; i++) strongLines(i)], [1, 1, 1, 2, 2]);
          await _pump(tester, host(const ReferencesScene()), width: 390);
          expect([for (var i = 0; i < 5; i++) strongLines(i)], [1, 1, 1, 1, 2]);
        });

        testWidgets('üzerine gelince yalnızca o hücrenin çizgisi turkuaz olur ve isim hafifçe kayar', (tester) async {
          await _pump(tester, host(const ReferencesScene()), width: 1440);
          double line(int i) => tester.widget<FractionallySizedBox>(find.byKey(ValueKey('reference-line-$i'))).widthFactor!;
          final x0 = tester.getTopLeft(find.text('Folkart Time')).dx;
          expect(line(1), 0);

          final mouse = await _mouse(tester);
          await mouse.moveTo(tester.getCenter(find.text('Folkart Time')));
          await tester.pumpAndSettle();
          expect(line(1), 1);
          expect(line(0), 0);
          final lineBox = find.descendant(of: find.byKey(const ValueKey('reference-line-1')), matching: find.byType(ColoredBox));
          expect(tester.widget<ColoredBox>(lineBox).color, c.accent);
          expect(tester.getTopLeft(find.text('Folkart Time')).dx, greaterThan(x0));
          // İsim vurguda da okunaklı kalır.
          expect(_contrast(c.text, c.bgAlt), greaterThanOrEqualTo(7));

          await mouse.moveTo(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(line(1), 0);
          expect(tester.getTopLeft(find.text('Folkart Time')).dx, x0);
        });
      });
    });
  }

  group('ProcessRailPainter.shouldRepaint', () {
    final progress = ValueNotifier<double>(0);
    ProcessRailPainter make({
      ValueNotifier<double>? p,
      int index = 0,
      bool vertical = false,
      Color track = const Color(0xFF111111),
      Color active = const Color(0xFF22AA99),
      Color background = const Color(0xFFEEEEEE),
    }) =>
        ProcessRailPainter(progress: p ?? progress, index: index, count: 4, vertical: vertical, track: track, active: active, background: background);

    test('aynı girdiyle yeniden boyamaz; her girdi (tema renkleri dahil) değişince boyar', () {
      expect(make().shouldRepaint(make()), isFalse);
      expect(make().shouldRepaint(make(p: ValueNotifier<double>(0))), isTrue);
      expect(make().shouldRepaint(make(index: 1)), isTrue);
      expect(make().shouldRepaint(make(vertical: true)), isTrue);
      expect(make().shouldRepaint(make(track: const Color(0xFF333333))), isTrue, reason: 'tema geçişinde çizgi rengi');
      expect(make().shouldRepaint(make(active: const Color(0xFF00FF00))), isTrue, reason: 'tema geçişinde vurgu rengi');
      expect(make().shouldRepaint(make(background: const Color(0xFF000000))), isTrue, reason: 'tema geçişinde düğüm dolgusu');
    });
  });

  testWidgets('tema değişince sahneler yeni palette boyanır (Section zemini ve painter renkleri)', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const scene = Column(children: [ServicesScene(), ProcessScene(), ReferencesScene()]);

    await tester.pumpWidget(_host(scene));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_rail(tester, 0).active, AppColors.dark.accent);
    expect([for (final s in tester.widgetList<Section>(find.byType(Section))) s.color], [AppColors.dark.bgAlt, AppColors.dark.bg, AppColors.dark.bgAlt]);

    await tester.pumpWidget(_host(scene, brightness: Brightness.light));
    await tester.pumpAndSettle();
    expect(_rail(tester, 0).active, AppColors.light.accent);
    expect(_rail(tester, 0).background, AppColors.light.bg);
    expect([for (final s in tester.widgetList<Section>(find.byType(Section))) s.color], [AppColors.light.bgAlt, AppColors.light.bg, AppColors.light.bgAlt]);
  });
}
