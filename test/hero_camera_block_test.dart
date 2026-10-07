import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/core/core.dart';
import 'package:gudeteknolojiweb/scenes/hero_camera_block.dart';
import 'package:gudeteknolojiweb/scenes/iris/iris_cover_painter.dart';
import 'package:gudeteknolojiweb/scenes/iris/iris_geometry.dart';
import 'package:gudeteknolojiweb/scenes/iris/iris_motion.dart';
import 'package:gudeteknolojiweb/scenes/iris/lens_art.dart';
import 'package:gudeteknolojiweb/theme.dart';

import 'helpers/app.dart';
import 'helpers/shot.dart';

const _coverKey = ValueKey('hero_iris_cover');
const _sizes = [Size(1440, 900), Size(1024, 768), Size(390, 844), Size(360, 740)];

AppColors _paletteOf(Brightness b) => b == Brightness.dark ? AppColors.dark : AppColors.light;
String _themeName(Brightness b) => b == Brightness.dark ? 'koyu' : 'açık';

/// Piksel testlerindeki sahte kamera sahnesi: tek düz renk, ikiyle de (cover zemini, lens) ayırt edilir.
Color _markerColor(Brightness b) => b == Brightness.dark ? const Color(0xFF1A2A3A) : const Color(0xFFB9D2EA);

/// Sahte kamera sahnesi. [studio] false: düz renkli zemin, ortada "KAMERA", reveal'ı gösteren ilerleme
/// çubuğu, dokunma sayacı. [studio] true: gerçek sahneye benzer tema duyarlı stüdyo (c.stage + parıltı + koyu
/// gövde); görsel doğrulamada kenar halesini gerçekçi koşulda (zemin ≈ üst katman zemini) görmek içindir.
class _Rig {
  _Rig({this.brightness = Brightness.dark, this.studio = false, this.plain = false}) : controller = ScrollController();

  final Brightness brightness;
  final bool studio;

  /// true: sahne yalnızca düz renk (yazı/çubuk yok); piksel taramalarında sahne içeriği karışmasın diye.
  final bool plain;
  final ScrollController controller;
  int explore = 0;
  int contact = 0;
  int cameraTaps = 0;
  ValueListenable<double>? reveal;

  /// Kamera sahnesindeki (sahte) odaklanabilir kontrol: gizliyken Tab ile ona gidilmediğini sınamak için.
  final cameraFocus = FocusNode(debugLabel: 'kamera kontrolü');

  Widget app({bool reduceMotion = false, double textScale = 1, Brightness? themeOverride}) {
    return testApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: LayoutBuilder(
              builder: (context, c) => ScrollScope(
                controller: controller,
                viewportHeight: c.maxHeight,
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      HeroCameraBlock(
                        onExplore: () => explore++,
                        onContact: () => contact++,
                        cameraBuilder: (context, reveal) {
                          this.reveal = reveal;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => cameraTaps++,
                            child: Focus(focusNode: cameraFocus, child: studio ? _StudioScene(reveal: reveal) : _SolidScene(reveal: reveal, color: _markerColor(brightness), plain: plain)),
                          );
                        },
                      ),
                      const SizedBox(height: 2000),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      brightness: themeOverride ?? brightness,
    );
  }

  /// Ekranı [size] yapar, uygulamayı kurar ve ilk kareleri çizer.
  Future<GlobalKey> mount(WidgetTester tester, Size size, {bool reduceMotion = false, double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(controller.dispose);
    addTearDown(cameraFocus.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: app(reduceMotion: reduceMotion, textScale: textScale)));
    await tester.pump(const Duration(milliseconds: 400));
    return key;
  }

  /// Kaydırmayı ilerleme [p]'ye getirir.
  Future<void> seek(WidgetTester tester, double p, Size size) async {
    controller.jumpTo(p * HeroCameraBlock.transitionDistance(size.height));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _SolidScene extends StatelessWidget {
  const _SolidScene({required this.reveal, required this.color, this.plain = false});
  final ValueListenable<double> reveal;
  final Color color;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    if (plain) return ColoredBox(color: color, child: const SizedBox.expand());
    return Container(
      color: color,
      alignment: Alignment.center,
      child: ValueListenableBuilder<double>(
        valueListenable: reveal,
        builder: (context, v, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('KAMERA', style: TextStyle(color: Colors.white, fontSize: 40)),
            SizedBox(width: 200, child: LinearProgressIndicator(value: v)),
          ],
        ),
      ),
    );
  }
}

/// Gerçek CameraScene'in ortam özelliklerini taklit eder: zemin `c.stage`, merkezde `c.stageGlow`, ortada koyu
/// kamera gövdesi; içerik `reveal` ile belirir. Üst katmanla aynı zemin rengini paylaştığı için en zor kenar
/// koşulunu (açıklık kenarında zemin farkı yok) sınar.
class _StudioScene extends StatelessWidget {
  const _StudioScene({required this.reveal});
  final ValueListenable<double> reveal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.stage),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [c.stageGlow, c.stageGlow.withValues(alpha: 0)], radius: 0.7),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: reveal,
          builder: (context, v, _) => Opacity(
            opacity: v,
            child: Center(
              child: Transform.scale(
                scale: 0.9 + 0.1 * v,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 360,
                      height: 130,
                      decoration: BoxDecoration(
                        color: const Color(0xFF20262E),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 40, offset: const Offset(0, 24))],
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 28),
                      child: Container(width: 78, height: 78, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF07090C))),
                    ),
                    const SizedBox(height: 24),
                    Text('Her açıdan net görüntü.', style: AppText.h2(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pixels {
  _Pixels(this.width, this.height, this.data);
  final int width;
  final int height;
  final ByteData data;

  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  }

  Color atOffset(Offset o) => at(o.dx.round().clamp(0, width - 1), o.dy.round().clamp(0, height - 1));
}

Future<_Pixels> _grab(WidgetTester tester, GlobalKey key) async {
  late _Pixels result;
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    result = _Pixels(image.width, image.height, data!);
  });
  return result;
}

bool _near(Color a, Color b, [int tol = 3]) =>
    ((a.r - b.r).abs() * 255).round() <= tol && ((a.g - b.g).abs() * 255).round() <= tol && ((a.b - b.b).abs() * 255).round() <= tol;

/// Algısal parlaklık (0..1), yalnızca "daha parlak / daha koyu" karşılaştırması için.
double _lum(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

/// Karelerin dt'si 50 ms ile sınırlandığından uzun süreyi küçük adımlarla ilerletir.
Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 40)) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

IrisCoverPainter? _painter(WidgetTester tester) {
  final f = find.byKey(_coverKey);
  if (f.evaluate().isEmpty) return null;
  return tester.widget<CustomPaint>(f).painter as IrisCoverPainter;
}

bool _inside(Size size, Offset p, [double margin = 2]) => p.dx >= margin && p.dy >= margin && p.dx <= size.width - margin - 1 && p.dy <= size.height - margin - 1;

void main() {
  setUpAll(loadAppFonts);

  group('Sözleşme ve geometri', () {
    test('transitionDistance ve totalHeight şartnameye uyar', () {
      expect(HeroCameraBlock.transitionDistance(900), closeTo(855, 1e-9));
      expect(HeroCameraBlock.totalHeight(900), closeTo(1755, 1e-9));
      expect(HeroCameraBlock.totalHeight(740), closeTo(740 + 740 * 0.95, 1e-9));
    });

    test('p=1 ölçeği açıklık poligonunun görünür alanı tamamen kapladığı en küçük ölçektir (+%4 pay)', () {
      for (final size in [..._sizes, const Size(844, 390)]) {
        final layout = IrisLayout.compute(size, mobileTextBottom: IrisLayout.isWideSize(size) ? 0 : 380);
        final rot = IrisChoreography.rotation(1);
        final dEnd = IrisChoreography.openAperture * layout.radius;
        final corners = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
        bool covers(double scale) => corners.every((c) => irisPolygonContains(layout.center, dEnd * scale, rot, c));

        expect(covers(layout.endScale), isTrue, reason: '$size: köşeler açıklığın içinde olmalı');
        // Pay hariç ölçekte (1/1.04) hâlâ örter, daha küçükte örtmez: sabit uydurulmadığını kanıtlar.
        final tight = layout.endScale / 1.04;
        expect(covers(tight * 1.0001), isTrue, reason: '$size: pay hariç ölçek yeterli olmalı');
        expect(covers(tight * 0.97), isFalse, reason: '$size: %3 küçük ölçek örtmemeli (ölçek hesaplanmış, uydurma değil)');
        expect(layout.endScale, greaterThan(2));
      }
    });

    test('koreografi sınırları: p=0 ve p=1', () {
      expect(IrisChoreography.aperture(0), closeTo(0.07, 1e-9));
      expect(IrisChoreography.aperture(1), closeTo(0.60, 1e-9));
      expect(IrisChoreography.lensScale(0, 5), closeTo(1, 1e-9));
      expect(IrisChoreography.lensScale(1, 5), closeTo(5, 1e-9));
      expect(IrisChoreography.textOpacity(0), 1);
      expect(IrisChoreography.textOpacity(0.22), closeTo(0, 1e-9));
      expect(IrisChoreography.hintOpacity(0.1), closeTo(0, 1e-9));
      expect(IrisChoreography.reveal(0.35), 0);
      expect(IrisChoreography.reveal(1), 1);
      // Doğrusal değil: ilk yarıda açıklık yarıdan fazla açılır (easeOut).
      expect(IrisChoreography.aperture(0.4), greaterThan((0.07 + 0.60) / 2));
      // p sınırları dışında (taşan kaydırma) da sayılar sınırda kalır.
      for (final p in [-1.0, 2.0]) {
        expect(IrisChoreography.aperture(p), inInclusiveRange(0.07 - 1e-9, 0.60 + 1e-9));
        expect(IrisChoreography.reveal(p), inInclusiveRange(0.0, 1.0));
        expect(IrisChoreography.textOpacity(p), inInclusiveRange(0.0, 1.0));
        expect(IrisChoreography.lensScale(p, 5), inInclusiveRange(1.0 - 1e-9, 5.0 + 1e-9));
      }
    });

    test('lens yerleşimi: masaüstünde sağda, mobilde metnin altında ve sığar', () {
      final wide = IrisLayout.compute(const Size(1440, 900));
      expect(wide.center.dx, closeTo(1008, 1e-9));
      expect(wide.center.dy, closeTo(468, 1e-9));
      expect(wide.radius, closeTo(math.min(0.22 * 1440, 0.30 * 900), 1e-9));

      final phone = IrisLayout.compute(const Size(360, 740), mobileTextBottom: 406);
      expect(phone.center.dy - phone.radius, greaterThanOrEqualTo(406 + 20 - 1e-6));
      expect(phone.center.dy + phone.radius, lessThanOrEqualTo(740 - 92 + 1e-6));
    });

    test('yatay telefon (geniş ve kısa ekran) masaüstü yerleşimini kullanır; dikey telefon ve tablet kullanmaz', () {
      expect(IrisLayout.isWideSize(const Size(844, 390)), isTrue);
      expect(IrisLayout.isWideSize(const Size(667, 375)), isTrue);
      expect(IrisLayout.isWideSize(const Size(1024, 768)), isTrue);
      expect(IrisLayout.isWideSize(const Size(390, 844)), isFalse);
      expect(IrisLayout.isWideSize(const Size(768, 1024)), isFalse);
      expect(IrisLayout.isWideSize(const Size(800, 600)), isFalse);
      // Yatay telefonda lens üstteki 72 px'lik çubuk boşluğuna girmez ve ekrana sığar.
      final l = IrisLayout.compute(const Size(844, 390));
      expect(l.center.dy - l.radius, greaterThanOrEqualTo(72));
      expect(l.center.dy + l.radius, lessThanOrEqualTo(390));
    });

    test('sıfır boyutlu sahne NaN üretmez ve çizim hata vermez', () {
      final layout = IrisLayout.compute(Size.zero);
      expect(layout.endScale.isFinite, isTrue);
      expect(layout.scaleAt(0.5).isFinite, isTrue);
      final art = LensArt();
      final progress = ValueNotifier<double>(0.5);
      final motion = IrisMotion();
      final painter = IrisCoverPainter(progress: progress, motion: motion, layout: layout, art: art, colors: AppColors.light);
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), Size.zero);
      recorder.endRecording().dispose();
      art.dispose();
      progress.dispose();
      motion.dispose();
    });

    test('painter tema renkleri değişince yeniden boyanır, aynıysa boyanmaz', () {
      final progress = ValueNotifier<double>(0);
      final motion = IrisMotion();
      final art = LensArt();
      final layout = IrisLayout.compute(const Size(1440, 900));
      IrisCoverPainter make(AppColors c) => IrisCoverPainter(progress: progress, motion: motion, layout: layout, art: art, colors: c);
      expect(make(AppColors.light).shouldRepaint(make(AppColors.dark)), isTrue);
      expect(make(AppColors.dark).shouldRepaint(make(AppColors.dark)), isFalse);
      art.dispose();
      progress.dispose();
      motion.dispose();
    });
  });

  for (final brightness in Brightness.values) {
    final c = _paletteOf(brightness);
    final tn = _themeName(brightness);

    group('HeroCameraBlock — $tn tema', () {
      for (final size in _sizes) {
        testWidgets('taşma yok: ${size.width.toInt()}x${size.height.toInt()}, p=0/0.25/0.5/0.75/1; metin ve düğmeler görünür', (tester) async {
          final rig = _Rig(brightness: brightness);
          await rig.mount(tester, size);
          expect(tester.takeException(), isNull);
          // Blok yüksekliği sözleşmedeki totalHeight ile aynıdır.
          expect(tester.getSize(find.byType(HeroCameraBlock)).height, closeTo(HeroCameraBlock.totalHeight(size.height), 0.01));
          expect(find.text('Gelecek sizin elinizde.'), findsOneWidget);
          expect(find.textContaining('Zayıf akım ve teknoloji'), findsOneWidget);
          expect(find.text('Kamera Sistemlerini Keşfedin'), findsOneWidget);
          expect(find.text('Bize Ulaşın'), findsOneWidget);
          expect(find.text('Aşağı kaydırın'), findsOneWidget);
          // Metin ekranın içinde.
          final screen = Offset.zero & size;
          final title = tester.getRect(find.text('Gelecek sizin elinizde.'));
          expect(screen.contains(title.topLeft) && screen.contains(title.bottomRight), isTrue, reason: 'başlık ekran dışında: $title');
          final buttons = tester.getRect(find.text('Bize Ulaşın'));
          expect(screen.contains(buttons.topLeft) && screen.contains(buttons.bottomRight), isTrue, reason: 'düğme ekran dışında: $buttons');
          // Üst çubuk 64 px sabit: içerik üstte 72 px boşluk bırakır (eyebrow en üst öğedir).
          expect(tester.getRect(find.text('GÜDE TEKNOLOJİ')).top, greaterThanOrEqualTo(72 - 1), reason: 'içerik üst çubuğa girmiş');

          for (final p in [0.25, 0.5, 0.75, 1.0]) {
            await rig.seek(tester, p, size);
            expect(tester.takeException(), isNull, reason: 'p=$p');
          }
        });
      }

      testWidgets('metin ve düğmeler çakışmaz: başlık/gövde/düğme dikeyde sıralı, lens metnin dışında', (tester) async {
        for (final size in _sizes) {
          final rig = _Rig(brightness: brightness);
          await rig.mount(tester, size);
          final title = tester.getRect(find.text('Gelecek sizin elinizde.'));
          final lead = tester.getRect(find.textContaining('Zayıf akım ve teknoloji'));
          final cta = tester.getRect(find.text('Kamera Sistemlerini Keşfedin'));
          final ghost = tester.getRect(find.text('Bize Ulaşın'));
          expect(lead.top, greaterThanOrEqualTo(title.bottom - 1), reason: '$size: gövde başlığa binmiş');
          expect(cta.top, greaterThanOrEqualTo(lead.bottom - 1), reason: '$size: düğme gövdeye binmiş');
          expect(ghost.top >= cta.bottom - 1 || ghost.left >= cta.right - 1, isTrue, reason: '$size: iki düğme üst üste');
          // Lens (gövde dahil) metin kutularının hiçbirine değmez.
          final layout = _painter(tester)!.layout;
          for (final r in [title, lead, cta, ghost]) {
            // Lens merkezinin dikdörtgene uzaklığı lens yarıçapından büyük olmalı.
            final dx = math.max(math.max(r.left - layout.center.dx, layout.center.dx - r.right), 0.0);
            final dy = math.max(math.max(r.top - layout.center.dy, layout.center.dy - r.bottom), 0.0);
            expect(math.sqrt(dx * dx + dy * dy), greaterThan(layout.radius), reason: '$size: lens metne biniyor ($r)');
          }
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('büyük yazı ölçeğinde (1.6x) metin kırpılmadan ekrana sığar', (tester) async {
        for (final size in [const Size(390, 844), const Size(360, 740), const Size(1440, 900)]) {
          final rig = _Rig(brightness: brightness);
          await rig.mount(tester, size, textScale: 1.6);
          expect(tester.takeException(), isNull, reason: '$size');
          final cta = tester.getRect(find.text('Bize Ulaşın'));
          expect(cta.bottom, lessThanOrEqualTo(size.height), reason: '$size');
          // Lens düğmelerin üstüne binmez: kapak boyacısının merkezi düğmelerin altında.
          if (!IrisLayout.isWideSize(size)) {
            final layout = _painter(tester)!.layout;
            expect(layout.center.dy - layout.radius, greaterThanOrEqualTo(cta.bottom - 1), reason: '$size');
          }
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('yatay telefon (844x390): masaüstü yerleşimi, taşma yok, ipucu gizli', (tester) async {
        const size = Size(844, 390);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        expect(tester.takeException(), isNull);
        expect(_painter(tester)!.layout.wide, isTrue);
        expect(find.text('Aşağı kaydırın'), findsNothing, reason: 'ipucu metin sütununa binerdi');
        final cta = tester.getRect(find.text('Bize Ulaşın'));
        expect(cta.bottom, lessThanOrEqualTo(size.height));
        expect(tester.getRect(find.text('GÜDE TEKNOLOJİ')).top, greaterThanOrEqualTo(72 - 1));
        await rig.seek(tester, 0.6, size);
        expect(tester.takeException(), isNull);
      });

      testWidgets('düğmeler çağrılır (onExplore / onContact)', (tester) async {
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, const Size(1440, 900));
        await tester.tap(find.text('Kamera Sistemlerini Keşfedin'));
        expect(rig.explore, 1);
        await tester.tap(find.text('Bize Ulaşın'));
        expect(rig.contact, 1);
      });

      testWidgets('klavye ile düğmelere odaklanılır, Enter çalıştırır', (tester) async {
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, const Size(1440, 900));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(rig.explore, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(rig.contact, 1);
      });

      testWidgets('açılış metni solduktan sonra (p>=0.18; şartname en geç 0.3) kapalıdır: dokunma ve odak geçmez', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        await rig.seek(tester, 0.35, size);
        // Stage tepeye sabitlendiği için düğmenin ilk konumu hâlâ ekranda; yine de olay almaz.
        await tester.tapAt(const Offset(300, 590));
        expect(rig.explore, 0);
        expect(rig.contact, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(rig.explore, 0);
        expect(rig.contact, 0);
        // Görünmez (opaklık ~0) ama etkileşimli düğme kalmaz: p=0.25'te de kapalı.
        await rig.seek(tester, 0.25, size);
        await tester.tap(find.text('Bize Ulaşın'), warnIfMissed: false);
        expect(rig.contact, 0);
        // Metin hâlâ okunabilirken (p=0.1) açık.
        await rig.seek(tester, 0.1, size);
        await tester.tap(find.text('Bize Ulaşın'), warnIfMissed: false);
        expect(rig.contact, 1);
      });

      testWidgets('klavye odağı: üst katman varken gizli kamera kontrolüne Tab ile ya da kodla gidilmez; p>=0.98 iken gidilir', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(rig.cameraFocus.hasFocus, isFalse, reason: 'Tab #$i: odak gizli kameraya girmemeli');
        }
        await rig.seek(tester, 0.5, size);
        rig.cameraFocus.requestFocus();
        await tester.pump();
        expect(rig.cameraFocus.hasFocus, isFalse, reason: 'p=0.5: kamera odağa kapalı');
        await rig.seek(tester, 1.0, size);
        rig.cameraFocus.requestFocus();
        await tester.pump();
        expect(rig.cameraFocus.hasFocus, isTrue, reason: 'p=1: kamera sahnesi etkileşime açık');
      });

      testWidgets('p<0.98 iken kamera sahnesine pointer geçmez; p>=0.98 iken geçer ve üst katman çizilmez', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        const center = Offset(720, 450);

        for (final p in [0.0, 0.5, 0.97]) {
          await rig.seek(tester, p, size);
          expect(find.byKey(_coverKey), findsOneWidget, reason: 'p=$p: üst katman çizilmeli');
          await tester.tapAt(center);
          expect(rig.cameraTaps, 0, reason: 'p=$p: kamera sahnesi pointer almamalı');
        }
        for (final p in [0.99, 1.0]) {
          await rig.seek(tester, p, size);
          expect(find.byKey(_coverKey), findsNothing, reason: 'p=$p: üst katman çizilmemeli');
          await tester.tapAt(center);
        }
        expect(rig.cameraTaps, 2);
      });

      testWidgets('reveal: p<=0.35 iken 0, p=1 iken 1, arada kaydırmayla orantılı', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        double reveal() => rig.reveal!.value;
        expect(reveal(), 0);
        await rig.seek(tester, 0.35, size);
        expect(reveal(), closeTo(0, 1e-9));
        await rig.seek(tester, 0.675, size);
        expect(reveal(), closeTo(0.5, 1e-6));
        await rig.seek(tester, 1.0, size);
        expect(reveal(), closeTo(1, 1e-9));
        // Daha öteye kaydırınca (sayfanın devamı) 1'de kalır; geri dönünce azalır.
        rig.controller.jumpTo(1.4 * HeroCameraBlock.transitionDistance(size.height));
        await tester.pump();
        expect(reveal(), 1);
        await rig.seek(tester, 0.2, size);
        expect(reveal(), 0);
      });

      testWidgets('görüntü: üst katman zemini temadan gelir; açıklık altındaki sahneyi gösterir (1440x900)', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        final key = await rig.mount(tester, size);
        final scene = _markerColor(brightness);

        var px = await _grab(tester, key);
        expect(_near(px.at(5, 5), c.stage), isTrue, reason: 'p=0 köşe tema zemini (c.stage) olmalı: ${px.at(5, 5)}');
        expect(_near(px.at(1008, 568), scene, 6), isFalse, reason: 'p=0: lens gövdesi/yaprağı sahneyi örtmeli');
        expect(_near(px.at(720, 300), scene, 6), isFalse, reason: 'p=0: sahne görünmemeli');

        await rig.seek(tester, 0.75, size);
        px = await _grab(tester, key);
        expect(_near(px.at(1008, 568), scene), isTrue, reason: 'p=0.75: açıklık sahneyi göstermeli');
        expect(_near(px.at(720, 300), scene), isTrue);

        await rig.seek(tester, 1.0, size);
        px = await _grab(tester, key);
        for (final pt in [const Offset(2, 2), const Offset(1437, 2), const Offset(2, 897), const Offset(1437, 897)]) {
          expect(_near(px.at(pt.dx.toInt(), pt.dy.toInt()), scene), isTrue, reason: 'p=1: köşe $pt sahne olmalı');
        }
      });

      testWidgets('görüntü: mobil (390x844) p=0 tema zemini, p=0.75 açıklıktan sahne, p=1 köşeler sahne', (tester) async {
        const size = Size(390, 844);
        final rig = _Rig(brightness: brightness);
        final key = await rig.mount(tester, size);
        final scene = _markerColor(brightness);
        var px = await _grab(tester, key);
        expect(_near(px.at(380, 300), c.stage), isTrue);
        await rig.seek(tester, 0.75, size);
        px = await _grab(tester, key);
        expect(_near(px.at(60, 300), scene), isTrue, reason: 'p=0.75: açıklık sahneyi göstermeli');
        await rig.seek(tester, 1.0, size);
        px = await _grab(tester, key);
        for (final pt in [const Offset(1, 1), const Offset(388, 1), const Offset(1, 842), const Offset(388, 842)]) {
          expect(_near(px.at(pt.dx.toInt(), pt.dy.toInt()), scene), isTrue, reason: 'köşe $pt');
        }
      });

      testWidgets('açıklık kenarı: ${brightness == Brightness.dark ? 'koyuda ince ışık halkası' : 'açıkta içe yumuşak gölge, ışık halesi yok'}', (tester) async {
        // Hareketi azalt: nefes/paralaks kapalı, açıklığın geometrisi birebir hesaplanabilir.
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness, plain: true);
        final key = await rig.mount(tester, size, reduceMotion: true);
        final scene = _markerColor(brightness);
        var checked = 0;
        for (final p in [0.45, 0.55, 0.65]) {
          await rig.seek(tester, p, size);
          final px = await _grab(tester, key);
          final layout = _painter(tester)!.layout;
          final d = layout.apertureRadiusAt(p);
          final rot = IrisChoreography.rotation(p);
          final inner = d * math.cos(math.pi / kBladeCount);
          for (var k = 0; k < kBladeCount; k++) {
            final a = rot + (k + 0.5) * 2 * math.pi / kBladeCount;
            final dir = Offset(math.cos(a), math.sin(a));
            Offset at(double dist) => layout.center + dir * dist;
            if (!_inside(size, at(inner - 70)) || !_inside(size, at(inner + 4))) continue;
            checked++;
            final near = _lum(px.atOffset(at(inner - 3)));
            final deep = _lum(px.atOffset(at(inner - 70)));
            if (brightness == Brightness.light) {
              expect(near, lessThan(deep - 0.015), reason: 'p=$p k=$k: kenarda yumuşak gölge olmalı');
              // Açıklığın hiçbir yerinde sahneden daha parlak (halka/hale) piksel yok.
              for (var dist = inner - 60; dist <= inner - 1; dist += 3) {
                expect(_lum(px.atOffset(at(dist))), lessThanOrEqualTo(_lum(scene) + 0.004), reason: 'p=$p k=$k dist=$dist: ışık halesi');
              }
            } else {
              final rim = _lum(px.atOffset(at(inner - 0.5)));
              expect(rim, greaterThan(deep + 0.012), reason: 'p=$p k=$k: koyuda kenarda ince ışık halkası olmalı');
            }
          }
        }
        expect(checked, greaterThan(3), reason: 'ekran içinde yeterli kenar örneği bulunamadı');
      });

      testWidgets('mikro hareketler: açılış görünürken çalışır; p>0.9 iken durur; yeniden başlayınca saat başa atlamaz', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        expect(tester.hasRunningAnimations, isTrue, reason: 'p=0: lens yaşar');
        final before = _painter(tester)!.motion.time;
        await _pumpFor(tester, const Duration(seconds: 2));
        final t1 = _painter(tester)!.motion.time;
        expect(t1, greaterThan(before + 1.5));

        await rig.seek(tester, 0.95, size);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isFalse, reason: 'p>0.9: döngü durmalı');

        await rig.seek(tester, 0.2, size);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isTrue, reason: 'geri dönünce yeniden başlamalı');
        await _pumpFor(tester, const Duration(milliseconds: 400));
        // Yansıma/nabız fazı kaldığı yerden sürer; başa (t≈0) atlamaz.
        expect(_painter(tester)!.motion.time, greaterThan(t1));
      });

      testWidgets('hareketi azalt: hiçbir döngü çalışmaz, fare paralaksı yok, geçiş yine kaydırmayla oynar', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        final key = await rig.mount(tester, size, reduceMotion: true);
        expect(tester.hasRunningAnimations, isFalse);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(10, 10));
        await mouse.moveTo(const Offset(1400, 850));
        await tester.pump(const Duration(seconds: 1));
        expect(_painter(tester)!.motion.dx, 0);
        expect(_painter(tester)!.motion.time, 0);
        await rig.seek(tester, 0.75, size);
        final px = await _grab(tester, key);
        expect(_near(px.at(1008, 568), _markerColor(brightness)), isTrue);
        await mouse.removePointer();
      });

      testWidgets('masaüstünde fare konumuna doğru ±6 px paralaks (yayla yumuşatılmış); geçişte etkisiz', (tester) async {
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(720, 450));
        await tester.pump();
        await mouse.moveTo(const Offset(1430, 890));
        await tester.pump(const Duration(milliseconds: 40));
        final early = _painter(tester)!.motion.dx;
        expect(early, lessThan(2.0), reason: 'yay: anında atlamaz');
        await _pumpFor(tester, const Duration(seconds: 2));
        final m = _painter(tester)!.motion;
        expect(m.dx, inInclusiveRange(5.0, 6.2));
        expect(m.dy, inInclusiveRange(4.5, 6.2));
        await mouse.moveTo(const Offset(2, 2));
        await _pumpFor(tester, const Duration(seconds: 2));
        expect(_painter(tester)!.motion.dx, inInclusiveRange(-6.2, -5.0));
        await mouse.removePointer();
      });

      testWidgets('mobilde paralaks yok', (tester) async {
        const size = Size(390, 844);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(10, 10));
        await mouse.moveTo(const Offset(380, 800));
        await tester.pump(const Duration(seconds: 1));
        expect(_painter(tester)!.motion.dx, 0);
        await mouse.removePointer();
      });

      testWidgets('lens ve kaydırma ipucu anlamsal ağaçta yok; başlık başlık olarak işaretli', (tester) async {
        final handle = tester.ensureSemantics();
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, const Size(1440, 900));
        expect(find.semantics.byLabel(RegExp('Aşağı kaydırın')), findsNothing);
        expect(tester.getSemantics(find.text('Gelecek sizin elinizde.')).flagsCollection.isHeader, isTrue);
        expect(find.semantics.byLabel(RegExp('Kamera Sistemlerini Keşfedin')), findsWidgets);
        await rig.seek(tester, 0.5, const Size(1440, 900));
        await tester.pump();
        expect(find.semantics.byLabel(RegExp('Kamera Sistemlerini Keşfedin')), findsNothing, reason: 'p>0.18: metin anlamsal ağaçtan çıkar');
        handle.dispose();
      });

      testWidgets('kamera sahnesi anlamsal ağaçta: üst katman varken (p<0.98) yok, p>=0.98 iken var', (tester) async {
        final handle = tester.ensureSemantics();
        const size = Size(1440, 900);
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, size);
        final scene = find.semantics.byLabel('KAMERA');
        for (final p in [0.0, 0.5, 0.97]) {
          await rig.seek(tester, p, size);
          expect(scene, findsNothing, reason: 'p=$p: görünmeyen kamera sahnesi ekran okuyucuya sunulmamalı');
        }
        await rig.seek(tester, 1.0, size);
        expect(scene, findsOneWidget, reason: 'p=1: kamera sahnesi görünür, okunabilir olmalı');
        handle.dispose();
      });

      testWidgets('yazı renkleri temadan gelir: başlık c.text, gövde c.textDim', (tester) async {
        final rig = _Rig(brightness: brightness);
        await rig.mount(tester, const Size(1440, 900));
        final title = tester.widget<Text>(find.text('Gelecek sizin elinizde.'));
        expect(title.style!.color, c.text);
        final lead = tester.widget<Text>(find.textContaining('Zayıf akım ve teknoloji'));
        expect(lead.style!.color, c.textDim);
      });
    });
  }

  group('Tema bağımsızlığı', () {
    testWidgets('lens gövdesi (malzeme) iki temada piksel piksel aynıdır; yalnızca zemin ve gölge değişir', (tester) async {
      const size = Size(1440, 900);
      final samples = <Color>[];
      final bases = <Color>[];
      for (final b in Brightness.values) {
        final rig = _Rig(brightness: b);
        // Hareket kapalı: yansıma ve nabız aynı fazda, kare farkı yok.
        final key = await rig.mount(tester, size, reduceMotion: true);
        final px = await _grab(tester, key);
        final layout = _painter(tester)!.layout;
        for (var k = 0; k < 24; k++) {
          final a = (k * 15 + 7) * math.pi / 180;
          for (final f in [0.955, 0.86, LensRadii.led + 0.0, 0.74]) {
            samples.add(px.atOffset(layout.center + Offset(math.cos(a), math.sin(a)) * (layout.radius * f)));
          }
        }
        bases.add(px.at(5, 5));
        await tester.pumpWidget(const SizedBox());
      }
      final n = samples.length ~/ 2;
      for (var i = 0; i < n; i++) {
        expect(_near(samples[i], samples[n + i], 2), isTrue, reason: 'örnek $i: koyu ${samples[i]} ≠ açık ${samples[n + i]}');
      }
      expect(_near(bases[0], bases[1], 8), isFalse, reason: 'zemin iki temada farklı olmalı');
    });

    testWidgets('LED halkası iki temada aynı turkuaz malzeme rengindedir', (tester) async {
      const size = Size(1440, 900);
      final ring = <Color>[];
      for (final b in Brightness.values) {
        final rig = _Rig(brightness: b);
        final key = await rig.mount(tester, size, reduceMotion: true);
        final px = await _grab(tester, key);
        final layout = _painter(tester)!.layout;
        // Saat 7 yönünde (LED noktasından uzak) halka çizgisi.
        const a = 2.4;
        ring.add(px.atOffset(layout.center + Offset(math.cos(a), math.sin(a)) * (layout.radius * LensRadii.led)));
        await tester.pumpWidget(const SizedBox());
      }
      expect(_near(ring[0], ring[1], 2), isTrue, reason: '${ring[0]} ≠ ${ring[1]}');
      // Turkuaz: yeşil/mavi kanal kırmızıdan belirgin yüksek.
      expect(ring[0].g, greaterThan(ring[0].r + 0.08));
    });
  });

  group('Tema geçişi ve yeniden boyutlandırma', () {
    test('ambientLight: koyu 0, açık 1; geçişte (lerp) sürekli ve tek yönlü artar', () {
      expect(ambientLight(AppColors.dark), closeTo(0, 1e-9));
      expect(ambientLight(AppColors.light), closeTo(1, 1e-9));
      var prev = -1.0;
      for (var i = 0; i <= 10; i++) {
        final k = ambientLight(AppColors.dark.lerp(AppColors.light, i / 10));
        expect(k, greaterThanOrEqualTo(prev), reason: 't=${i / 10}');
        expect(k, inInclusiveRange(0.0, 1.0));
        if (i > 0 && i < 10) expect(k, inExclusiveRange(0.0, 1.0));
        prev = k;
      }
    });

    testWidgets('canlı tema geçişi: koyu → açık sırasında hata yok, ara karede zemin iki rengin arasında, sonunda açık zemin', (tester) async {
      const size = Size(1440, 900);
      final rig = _Rig();
      final key = await rig.mount(tester, size);
      await rig.seek(tester, 0.4, size);
      await tester.pumpWidget(RepaintBoundary(key: key, child: rig.app(themeOverride: Brightness.light)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final mid = _lum((await _grab(tester, key)).at(5, 5));
      expect(mid, greaterThan(_lum(AppColors.dark.stage) + 0.05));
      expect(mid, lessThan(_lum(AppColors.light.stage) - 0.05));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(_near((await _grab(tester, key)).at(5, 5), AppColors.light.stage), isTrue);
      // Geri dönüş de sorunsuz.
      await tester.pumpWidget(RepaintBoundary(key: key, child: rig.app(themeOverride: Brightness.dark)));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_near((await _grab(tester, key)).at(5, 5), AppColors.dark.stage), isTrue);
    });

    testWidgets('pencere yeniden boyutlanınca (viewport değişimi) hata yok; yerleşim ve p yeni boyuta göre hesaplanır', (tester) async {
      final rig = _Rig();
      await rig.mount(tester, const Size(1440, 900));
      await rig.seek(tester, 0.5, const Size(1440, 900));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(HeroCameraBlock)).height, closeTo(HeroCameraBlock.totalHeight(844), 0.01));
      final painter = _painter(tester);
      // Kaydırma konumu piksel olarak kaldığından p, yeni mesafeye göre yeniden hesaplanır: 0.5·855/802 ≈ 0.53 → üst katman hâlâ var.
      expect(painter, isNotNull);
      expect(painter!.layout.wide, isFalse);
      expect(painter.layout.size, const Size(390, 844));
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(_painter(tester)!.layout.wide, isTrue);
    });
  });

  group('Görsel doğrulama (PNG üretir)', () {
    for (final brightness in Brightness.values) {
      testWidgets('${_themeName(brightness)} tema, yatay telefon 844x390, p = 0, 0.5', (tester) async {
        const size = Size(844, 390);
        final rig = _Rig(brightness: brightness, studio: true);
        final key = await rig.mount(tester, size);
        for (final p in [0.0, 0.5]) {
          await rig.seek(tester, p, size);
          final path = await captureBoundary(tester, key, name: 'hero_${brightness.name}_844x390_p${(p * 100).round()}');
          expect(File(path).lengthSync(), greaterThan(2000));
          // ignore: avoid_print
          print('SHOT: $path');
        }
      });

      for (final size in _sizes) {
        testWidgets('${_themeName(brightness)} tema, p = 0, 0.25, 0.5, 0.75, 1.0 — ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          final rig = _Rig(brightness: brightness, studio: true);
          final key = await rig.mount(tester, size);
          for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
            await rig.seek(tester, p, size);
            final name = 'hero_${brightness.name}_${size.width.toInt()}_p${(p * 100).round()}';
            final path = await captureBoundary(tester, key, name: name);
            expect(File(path).lengthSync(), greaterThan(2000));
            expect(tester.takeException(), isNull);
            // ignore: avoid_print
            print('SHOT: $path');
          }
        });
      }
    }
  });
}
