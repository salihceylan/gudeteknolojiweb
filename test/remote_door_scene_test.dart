import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/scenes/remote/ad_stage.dart';
import 'package:gudeteknolojiweb/scenes/remote/ad_timeline.dart';
import 'package:gudeteknolojiweb/scenes/remote/box_asset.dart';
import 'package:gudeteknolojiweb/scenes/remote/box_painters.dart';
import 'package:gudeteknolojiweb/scenes/remote/phone_painters.dart';
import 'package:gudeteknolojiweb/scenes/remote/scene_painters.dart';
import 'package:gudeteknolojiweb/scenes/remote/signal_painter.dart';
import 'package:gudeteknolojiweb/scenes/remote/stage_geometry.dart';
import 'package:gudeteknolojiweb/scenes/remote_door_scene.dart';
import 'package:gudeteknolojiweb/theme.dart';
import 'package:gudeteknolojiweb/widgets/reveal.dart';

import 'helpers/app.dart';
import 'helpers/shot.dart';

AppColors _palette(Brightness b) => b == Brightness.dark ? AppColors.dark : AppColors.light;

/// Sahneyi iki temalı test uygulamasında, kaydırılabilir bir sayfa içinde kurar.
Widget _app(
  Widget scene, {
  Brightness brightness = Brightness.dark,
  bool reduceMotion = false,
  double textScale = 1,
  ScrollController? controller,
  double lead = 0,
}) {
  return testApp(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          backgroundColor: context.colors.bgAlt,
          body: SingleChildScrollView(
            controller: controller,
            child: Column(children: [if (lead > 0) SizedBox(height: lead), scene]),
          ),
        ),
      ),
    ),
    brightness: brightness,
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Reveal girişlerinin (gecikme + 700 ms) bitmesi için.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

/// Altyazı etiketinin o an çizildiği renk.
Color? _captionColor(WidgetTester tester, String text) {
  final styled = find.ancestor(of: find.text(text), matching: find.byType(AnimatedDefaultTextStyle));
  return tester.widget<AnimatedDefaultTextStyle>(styled.first).style.color;
}

/// Kutu görselinin çözülmesi gerçek zaman ister (widget testlerinin sahte saati beklemez).
Future<void> _loadBoxImage(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump();
}

/// Çizilmiş kareyi ham RGBA piksellerine çevirir; "o noktada ne var" sorularını yanıtlamak için.
class _Pixels {
  _Pixels(this.width, this.height, this.data);

  final int width;
  final int height;
  final ByteData data;

  static Future<_Pixels> of(WidgetTester tester, GlobalKey key) async {
    late _Pixels result;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      result = _Pixels(image.width, image.height, bytes);
    });
    return result;
  }

  /// WCAG göreli parlaklığı (0..1).
  double luminance(Offset p) {
    final x = p.dx.round().clamp(0, width - 1);
    final y = p.dy.round().clamp(0, height - 1);
    final i = (y * width + x) * 4;
    double lin(int v) {
      final s = v / 255;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * lin(data.getUint8(i)) + 0.7152 * lin(data.getUint8(i + 1)) + 0.0722 * lin(data.getUint8(i + 2));
  }

  /// (R, G, B) 0..255.
  (int, int, int) rgb(Offset p) {
    final i = (p.dy.round().clamp(0, height - 1) * width + p.dx.round().clamp(0, width - 1)) * 4;
    return (data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
  }

  /// [center] çevresindeki karenin ortalama parlaklığı.
  double meanLuminance(Offset center, int radius) {
    var sum = 0.0;
    var n = 0;
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        sum += luminance(center + Offset(dx.toDouble(), dy.toDouble()));
        n++;
      }
    }
    return sum / n;
  }
}

/// Gerçek sitedeki sabit üst çubuğun yaklaşık yüksekliği (Android Chrome QA ekran görüntülerinden).
const _navBarHeight = 60.0;

double _contrast(double a, double b) => (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

void main() {
  setUpAll(loadAppFonts);

  group('AdTimeline', () {
    test('döngü başı ve sonu aynı durumda (t=0 ≡ t=loop)', () {
      final start = AdTimeline.stateAt(0);
      final end = AdTimeline.stateAt(AdTimeline.loop);
      expect(end, start);
      // Başlangıç gerçekten "boş" durumdur: kutu, telefon, kapı, ışıklar yok.
      for (final v in [start.boxOpacity, start.doorIn, start.phoneIn, start.tap, start.ledGlow, start.doorOpen, start.success, start.check]) {
        expect(v, 0);
      }
      expect(start.captionStep, 0);
    });

    test('saat döngüyü saran son adımda başlangıç durumuna döner', () {
      final clock = AdClock(AdTimeline.loop - 0.01);
      clock.advance(0.01);
      expect(clock.time, 0);
      expect(clock.value, AdTimeline.stateAt(0));
      clock.dispose();
    });

    test('döngü sonuna yaklaşırken süreklidir (atlama yok)', () {
      final a = AdTimeline.stateAt(AdTimeline.loop - 0.002);
      final b = AdTimeline.stateAt(AdTimeline.loop);
      final c = AdTimeline.stateAt(0.002);
      for (final f in <double Function(AdState)>[
        (s) => s.boxIn, (s) => s.boxOpacity, (s) => s.doorIn, (s) => s.phoneIn, (s) => s.tap, (s) => s.buttonState,
        (s) => s.sending, (s) => s.ledGlow, (s) => s.doorOpen, (s) => s.success, (s) => s.check, (s) => s.drift,
      ]) {
        expect((f(a) - f(b)).abs(), lessThan(5e-3));
        expect((f(c) - f(b)).abs(), lessThan(5e-2));
      }
    });

    test('sınır dışı zaman sıkıştırılır', () {
      expect(AdTimeline.stateAt(-3), AdTimeline.stateAt(0));
      expect(AdTimeline.stateAt(40), AdTimeline.stateAt(AdTimeline.loop));
    });

    test('saf fonksiyon: aynı girdi aynı durum', () {
      expect(AdTimeline.stateAt(3.3), AdTimeline.stateAt(3.3));
    });

    test('değerler izin verilen aralıklarda kalır', () {
      for (var t = 0.0; t <= AdTimeline.loop; t += 0.01) {
        final s = AdTimeline.stateAt(t);
        for (final v in [s.boxOpacity, s.doorIn, s.sweep, s.tap, s.buttonState, s.sending, s.tapRing, s.signalProgress, s.arrive, s.ledGlow, s.clickRing, s.doorOpen, s.success, s.check]) {
          expect(v, inInclusiveRange(-1e-9, 1 + 1e-9), reason: 't=$t');
        }
        // Yaylı değerler hedefi en çok %6 aşar.
        expect(s.boxIn, inInclusiveRange(-1e-9, 1.06), reason: 't=$t');
        expect(s.phoneIn, inInclusiveRange(-1e-9, 1.06), reason: 't=$t');
        expect(s.drift, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('yay: kutu ve telefon hedefi hafifçe aşıp yerine oturur', () {
      var boxPeak = 0.0, phonePeak = 0.0;
      for (var t = 0.0; t <= 3.0; t += 0.01) {
        final s = AdTimeline.stateAt(t);
        if (t <= 1.5) boxPeak = boxPeak < s.boxIn ? s.boxIn : boxPeak;
        if (t >= 1.2) phonePeak = phonePeak < s.phoneIn ? s.phoneIn : phonePeak;
      }
      expect(boxPeak, greaterThan(1.0));
      expect(phonePeak, greaterThan(1.0));
      expect(AdTimeline.stateAt(1.5).boxIn, closeTo(1, 1e-9));
      expect(AdTimeline.stateAt(2.6).phoneIn, closeTo(1, 1e-9));
    });

    /// [f] değerinin [a,b] aralığında azalmadığını (artan = true) ya da artmadığını doğrular.
    void monotone(String name, double Function(AdState) f, double a, double b, {bool increasing = true}) {
      var prev = f(AdTimeline.stateAt(a));
      for (var t = a + 0.005; t <= b; t += 0.005) {
        final v = f(AdTimeline.stateAt(t));
        expect(increasing ? v >= prev - 1e-9 : v <= prev + 1e-9, isTrue, reason: '$name t=$t');
        prev = v;
      }
    }

    test('geçişler tek yönlü ve monoton', () {
      monotone('doorOpen açılış', (s) => s.doorOpen, 5.0, 7.0);
      monotone('doorOpen kapanış', (s) => s.doorOpen, 8.4, 9.0, increasing: false);
      monotone('ledGlow yükseliş', (s) => s.ledGlow, 4.5, 5.0);
      monotone('ledGlow sönüş', (s) => s.ledGlow, 8.4, 9.0, increasing: false);
      monotone('success', (s) => s.success, 5.4, 5.85);
      monotone('check', (s) => s.check, 5.45, 5.95);
      monotone('signalProgress', (s) => s.signalProgress, 3.1005, 4.4995);
      monotone('tap yaklaşma', (s) => s.tap, 2.4, 2.85);
      monotone('phone çıkış', (s) => s.phoneIn, 8.4, 9.0, increasing: false);
      monotone('boxOpacity giriş', (s) => s.boxOpacity, 0, 0.9);
      monotone('doorIn giriş', (s) => s.doorIn, 0.6, 1.2);
      monotone('doorIn çıkış', (s) => s.doorIn, 8.5, 8.9, increasing: false);
    });

    // Şartname fazları: 0–1.2 kutu, 1.2–2.4 telefon, 2.4–3.1 dokunuş, 3.1–4.5 sinyal, 4.5–5.0 LED + klik,
    // 5.0–7.0 kapı, 7.0–8.4 bekleme, 8.4–9.0 başa dönüş.
    group('faz sınırları şartnameyle uyumlu', () {
      test('0.0–1.2: yalnızca kutu belirir', () {
        expect(AdTimeline.stateAt(0.6).boxOpacity, inExclusiveRange(0, 1));
        expect(AdTimeline.stateAt(0.6).boxIn, inExclusiveRange(0, 1.06));
        expect(AdTimeline.stateAt(0.6).sweep, inExclusiveRange(0, 1));
        // Kapı, kutu belirdikten sonra kapalı hâliyle sahnenin gerisinde ağır ağır görünür.
        expect(AdTimeline.stateAt(0.6).doorIn, 0);
        expect(AdTimeline.stateAt(0.9).doorIn, inExclusiveRange(0, 1));
        expect(AdTimeline.stateAt(1.2).doorIn, 1);
        for (final t in [0.0, 0.6, 1.1999]) {
          final s = AdTimeline.stateAt(t);
          expect(s.phoneIn, 0, reason: 't=$t');
          expect(s.tap, 0, reason: 't=$t');
          expect(s.doorOpen, 0, reason: 't=$t');
          expect(s.ledGlow, 0, reason: 't=$t');
        }
      });

      test('1.2–2.4: telefon girer, henüz dokunuş yok', () {
        expect(AdTimeline.stateAt(1.2).phoneIn, 0);
        expect(AdTimeline.stateAt(1.8).phoneIn, inExclusiveRange(0.2, 1.06));
        expect(AdTimeline.stateAt(2.39).phoneIn, closeTo(1, 0.06));
        expect(AdTimeline.stateAt(2.39).tap, 0);
        expect(AdTimeline.stateAt(2.39).buttonState, 0);
      });

      test('2.4–3.1: parmak iner, düğme basılır, dalga çıkar, "Gönderiliyor…"', () {
        expect(AdTimeline.stateAt(2.4).tap, 0);
        expect(AdTimeline.stateAt(2.6).tap, inExclusiveRange(0.3, 1));
        expect(AdTimeline.stateAt(2.5).buttonState, 0);
        // Dokunuş anı (parmak düğmede): düğme basılma yolundadır, sonra tam basılır.
        expect(AdTimeline.stateAt(2.88).buttonState, inExclusiveRange(0.3, 1));
        expect(AdTimeline.stateAt(3.0).buttonState, closeTo(1, 1e-9));
        expect(AdTimeline.stateAt(3.0).tapRing, inExclusiveRange(0, 1));
        expect(AdTimeline.stateAt(2.5).tapRing, 0);
        // Düğme etiketi art arda değişir: "KAPIYI AÇ" söner, sonra "Gönderiliyor…" belirir.
        expect(AdTimeline.stateAt(2.8).idle, 1);
        expect(AdTimeline.stateAt(3.0).idle, 0);
        expect(AdTimeline.stateAt(3.0).sending, 0);
        expect(AdTimeline.stateAt(3.1).sending, inExclusiveRange(0.5, 1));
        expect(AdTimeline.stateAt(3.15).sending, 1);
        expect(AdTimeline.stateAt(3.1).signalProgress, 0);
      });

      test('3.1–4.5: sinyal yalnızca bu aralıkta; LED henüz yanmaz', () {
        expect(AdTimeline.stateAt(3.0).signalProgress, 0);
        expect(AdTimeline.stateAt(3.1).signalProgress, 0);
        expect(AdTimeline.stateAt(3.8).signalProgress, inExclusiveRange(0.2, 0.8));
        expect(AdTimeline.stateAt(4.5).signalProgress, 0);
        expect(AdTimeline.stateAt(4.6).signalProgress, 0);
        expect(AdTimeline.stateAt(4.49).ledGlow, 0);
        // Varışta Wi-Fi yayları başlar.
        expect(AdTimeline.stateAt(4.3).arrive, inExclusiveRange(0, 1));
      });

      test('4.5–5.0: LED parlar, klik halkası kısa sürer', () {
        expect(AdTimeline.stateAt(4.5).ledGlow, 0);
        expect(AdTimeline.stateAt(4.7).ledGlow, inExclusiveRange(0.3, 1));
        expect(AdTimeline.stateAt(5.0).ledGlow, greaterThan(0.99));
        expect(AdTimeline.stateAt(4.7).clickRing, inExclusiveRange(0, 1));
        expect(AdTimeline.stateAt(4.5).clickRing, 0);
        expect(AdTimeline.stateAt(5.1).clickRing, 0);
        // Kapı, LED yandıktan sonra açılmaya başlar.
        expect(AdTimeline.stateAt(5.0).doorOpen, 0);
      });

      test('5.0–7.0: kapı açılır, telefonda "Kapı açıldı" ✓', () {
        expect(AdTimeline.stateAt(6.0).doorOpen, inExclusiveRange(0.2, 0.8));
        expect(AdTimeline.stateAt(7.0).doorOpen, 1);
        expect(AdTimeline.stateAt(5.1).success, 0);
        expect(AdTimeline.stateAt(5.85).success, 1);
        expect(AdTimeline.stateAt(5.95).check, 1);
        expect(AdTimeline.stateAt(5.4).sending, 0);
      });

      test('7.0–8.4: bekleme; durum değişmez, adım 3 vurgulu', () {
        final a = AdTimeline.stateAt(7.0), b = AdTimeline.stateAt(7.7), c = AdTimeline.stateAt(8.39);
        for (final f in <double Function(AdState)>[(s) => s.doorOpen, (s) => s.success, (s) => s.check, (s) => s.phoneIn, (s) => s.ledGlow]) {
          expect(f(b), closeTo(f(a), 1e-9));
          expect(f(c), closeTo(f(a), 1e-9));
        }
        expect(a.doorOpen, 1);
        expect(b.captionStep, 3);
      });

      test('telefon ekranındaki etiketler hiçbir an üst üste görünmez', () {
        for (var t = 0.0; t <= AdTimeline.loop; t += 0.005) {
          final s = AdTimeline.stateAt(t);
          expect(s.idle * s.sending, 0, reason: 'idle×sending t=$t');
          expect(s.sending * s.success, 0, reason: 'sending×success t=$t');
          // "KAPIYI AÇ" ile ✓ yalnızca döngünün son anında, telefon artık görünmezken yer değiştirir.
          if (s.idle * s.success > 0) expect(s.phoneIn, lessThan(0.02), reason: 'idle×success t=$t');
        }
      });

      test('8.4–9.0: her şey yumuşakça başlangıca döner', () {
        final s = AdTimeline.stateAt(8.7);
        expect(s.doorOpen, inExclusiveRange(0, 1));
        expect(s.phoneIn, inExclusiveRange(0, 1));
        expect(s.ledGlow, inExclusiveRange(0, 1));
        expect(s.captionStep, 0);
        expect(AdTimeline.stateAt(9.0).doorOpen, 0);
        expect(AdTimeline.stateAt(9.0).phoneIn, 0);
        expect(AdTimeline.stateAt(9.0).ledGlow, 0);
      });
    });

    test('altyazı adımları zamanla senkron', () {
      expect(AdTimeline.stateAt(2.39).captionStep, 0);
      expect(AdTimeline.stateAt(2.4).captionStep, 1);
      expect(AdTimeline.stateAt(3.09).captionStep, 1);
      expect(AdTimeline.stateAt(3.1).captionStep, 2);
      expect(AdTimeline.stateAt(4.99).captionStep, 2);
      expect(AdTimeline.stateAt(5.0).captionStep, 3);
      expect(AdTimeline.stateAt(8.39).captionStep, 3);
      expect(AdTimeline.stateAt(8.4).captionStep, 0);
    });

    test('durağan kare: kapı açık, ✓ görünür, üç adım da anlaşılır', () {
      final s = AdTimeline.stateAt(AdTimeline.restTime);
      expect(s.doorOpen, 1);
      expect(s.check, 1);
      expect(s.success, 1);
      expect(s.phoneIn, 1);
      expect(s.boxOpacity, 1);
      expect(s.captionStep, 3);
    });

    test('AdClock zamanı döngüye sarar ve adımı yayınlar', () {
      final clock = AdClock(8.9);
      clock.advance(0.3);
      expect(clock.time, closeTo(0.2, 1e-9));
      expect(clock.step.value, 0);
      clock.time = 3.5;
      expect(clock.step.value, 2);
      clock.dispose();
    });
  });

  test('BoxAsset sabitleri assets/images/ahbu_box.json ile aynı (gömülü değerler eskimemiş)', () {
    final json = jsonDecode(File('assets/images/ahbu_box.json').readAsStringSync()) as Map<String, dynamic>;
    Offset point(String key) {
      final v = (json[key] as List).cast<num>();
      return Offset(v[0].toDouble(), v[1].toDouble());
    }

    expect(BoxAsset.ledBlue, point('led_blue'));
    expect(BoxAsset.lightHole, point('light_hole'));
    expect(BoxAsset.usbC, point('usb_c'));
    expect(BoxAsset.dot, point('dot'));
    expect(BoxAsset.aspect, closeTo((json['aspect'] as num).toDouble(), 1e-9));
    final size = (json['size'] as List).cast<num>();
    expect(size[0] / size[1], closeTo(BoxAsset.aspect, 1e-3));
  });

  group('StageGeometry', () {
    for (final entry in {'wide': StageGeometry.wide, 'tall': StageGeometry.tall}.entries) {
      final geo = entry.value;
      final all = Offset.zero & geo.design;

      test('${entry.key}: her şey sahnenin içinde, LED kutunun üstünde', () {
        for (final r in [geo.box, geo.door, geo.phone]) {
          expect(all.contains(r.topLeft) && all.contains(r.bottomRight), isTrue, reason: '$r');
        }
        for (final p in [geo.signalStart, geo.signalC1, geo.signalC2, geo.led]) {
          expect(all.contains(p), isTrue, reason: '$p');
        }
        expect(geo.box.contains(geo.led), isTrue);
        expect(geo.led.dx, closeTo(geo.box.left + geo.box.width * BoxAsset.ledBlue.dx, 1e-9));
        expect(geo.box.width / geo.box.height, closeTo(BoxAsset.aspect, 1e-9));
      });

      test('${entry.key}: kapı ne kutuyla ne telefonla çakışır', () {
        expect(geo.door.overlaps(geo.box), isFalse);
        expect(geo.door.overlaps(geo.phone), isFalse);
      });
    }

    test('telefon ve kutu iki kompozisyonda da birbirine binmez', () {
      expect(StageGeometry.wide.phone.overlaps(StageGeometry.wide.box), isFalse);
      expect(StageGeometry.tall.phone.overlaps(StageGeometry.tall.box), isFalse);
    });

    for (final entry in {'wide': StageGeometry.wide, 'tall': StageGeometry.tall}.entries) {
      test('${entry.key}: sinyal eğrisi kapının içinden geçmez ve telefondan başlayıp LED ile biter', () {
        final geo = entry.value;
        Offset at(double t) {
          final u = 1 - t;
          return geo.signalStart * (u * u * u) + geo.signalC1 * (3 * u * u * t) + geo.signalC2 * (3 * u * t * t) + geo.led * (t * t * t);
        }

        expect(at(0), geo.signalStart);
        expect((at(1) - geo.led).distance, lessThan(1e-9));
        expect(geo.phone.inflate(8).contains(geo.signalStart), isTrue);
        for (var i = 0; i <= 100; i++) {
          expect(geo.door.inflate(3).contains(at(i / 100)), isFalse, reason: 'i=$i ${at(i / 100)}');
        }
      });
    }

    test('kutu girişte yükselir, boşta çok az yüzer', () {
      final geo = StageGeometry.wide;
      expect(geo.boxOffset(AdTimeline.stateAt(0.1)).dy, greaterThan(StageGeometry.boxRiseDistance * 0.5));
      expect(geo.boxOffset(AdTimeline.stateAt(AdTimeline.restTime)).dy.abs(), lessThanOrEqualTo(StageGeometry.boxDriftAmplitude));
    });
  });

  group('painter\'lar temaya duyarlı', () {
    // Tema geçişinde yeniden boyanmanın tek koşulu: renk kurucu alanının shouldRepaint'e katılması.
    final geo = StageGeometry.wide;
    final clock = AdClock();
    tearDownAll(clock.dispose);

    test('StageBackdropPainter', () {
      final dark = StageBackdropPainter(geo: geo, c: AppColors.dark);
      expect(dark.shouldRepaint(StageBackdropPainter(geo: geo, c: AppColors.dark)), isFalse);
      expect(dark.shouldRepaint(StageBackdropPainter(geo: geo, c: AppColors.light)), isTrue);
    });

    test('DoorPainter', () {
      final dark = DoorPainter(geo: geo, clock: clock, c: AppColors.dark);
      expect(dark.shouldRepaint(DoorPainter(geo: geo, clock: clock, c: AppColors.dark)), isFalse);
      expect(dark.shouldRepaint(DoorPainter(geo: geo, clock: clock, c: AppColors.light)), isTrue);
    });

    test('ProductBoxPainter', () {
      final dark = ProductBoxPainter(geo: geo, image: null, c: AppColors.dark);
      expect(dark.shouldRepaint(ProductBoxPainter(geo: geo, image: null, c: AppColors.dark)), isFalse);
      expect(dark.shouldRepaint(ProductBoxPainter(geo: geo, image: null, c: AppColors.light)), isTrue);
    });

    test('BoxLightPainter', () {
      final dark = BoxLightPainter(geo: geo, image: null, clock: clock, c: AppColors.dark);
      expect(dark.shouldRepaint(BoxLightPainter(geo: geo, image: null, clock: clock, c: AppColors.dark)), isFalse);
      expect(dark.shouldRepaint(BoxLightPainter(geo: geo, image: null, clock: clock, c: AppColors.light)), isTrue);
    });

    test('SignalPainter', () {
      final dark = SignalPainter(geo: geo, clock: clock, c: AppColors.dark);
      expect(dark.shouldRepaint(SignalPainter(geo: geo, clock: clock, c: AppColors.dark)), isFalse);
      expect(dark.shouldRepaint(SignalPainter(geo: geo, clock: clock, c: AppColors.light)), isTrue);
    });

    test('PhoneBodyPainter (gölge temaya uyar); PhoneScreenPainter ürün yüzeyi olduğundan uymaz', () {
      const dark = PhoneBodyPainter(c: AppColors.dark);
      expect(dark.shouldRepaint(const PhoneBodyPainter(c: AppColors.dark)), isFalse);
      expect(dark.shouldRepaint(const PhoneBodyPainter(c: AppColors.light)), isTrue);
      final screen = PhoneScreenPainter(clock: clock, title: 'AHBU');
      expect(screen.shouldRepaint(PhoneScreenPainter(clock: clock, title: 'AHBU')), isFalse);
    });
  });

  group('RemoteDoorScene', () {
    for (final brightness in Brightness.values) {
      for (final (name, size, scale) in [
        ('1440x900', const Size(1440, 900), 1.0),
        ('1024x768', const Size(1024, 768), 1.0),
        ('768x1024', const Size(768, 1024), 1.0),
        ('390x844', const Size(390, 844), 1.0),
        ('360x740', const Size(360, 740), 1.0),
        ('360x740 büyük yazı', const Size(360, 740), 1.8),
      ]) {
        testWidgets('${brightness.name} $name: metinler birebir, taşma yok', (tester) async {
          _size(tester, size);
          await tester.pumpWidget(_app(const RemoteDoorScene(), brightness: brightness, textScale: scale));
          await _settle(tester);
          expect(find.text('İLK ÜRÜNÜMÜZ'), findsOneWidget);
          expect(find.text('Kapıyı telefonunuzdan açın.'), findsOneWidget);
          expect(find.text('Yalnızca mobil uygulamayla, uzaktan kapı açan ilk AHBU cihazı. Kompakt kutu, tek dokunuşla açma.'), findsOneWidget);
          expect(find.text('Mobil uygulamayla uzaktan açma'), findsOneWidget);
          expect(find.text('Wi-Fi ile bağlantı'), findsOneWidget);
          expect(find.text('Kompakt, USB-C girişli gövde'), findsOneWidget);
          expect(find.text('Teklif İsteyin'), findsOneWidget);
          expect(find.text('1  Dokunun'), findsOneWidget);
          expect(find.text('2  Sinyal gider'), findsOneWidget);
          expect(find.text('3  Kapı açılır'), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Sahne taşmadan ekran genişliğine sığar.
          final stage = tester.getRect(find.byType(RemoteDoorStage));
          expect(stage.left, greaterThanOrEqualTo(-0.5));
          expect(stage.right, lessThanOrEqualTo(size.width + 0.5));
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }

    testWidgets('masaüstünde metin solda, sahne sağda; mobilde sahne metnin altında', (tester) async {
      _size(tester, const Size(1440, 900));
      await tester.pumpWidget(_app(const RemoteDoorScene()));
      await _settle(tester);
      final textBox = tester.getRect(find.text('Kapıyı telefonunuzdan açın.'));
      final caption = tester.getRect(find.text('2  Sinyal gider'));
      expect(caption.left, greaterThan(textBox.right - 40));

      // Mobilde (dikey) başlık + açıklama üstte, sahne hemen altında, maddeler ve düğme sahnenin altındadır.
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(const RemoteDoorScene()));
      await _settle(tester);
      final lead2 = tester.getRect(find.textContaining('Yalnızca mobil uygulamayla'));
      final stage2 = tester.getRect(find.byType(RemoteDoorStage));
      final bullet2 = tester.getRect(find.text('Mobil uygulamayla uzaktan açma'));
      final button2 = tester.getRect(find.text('Teklif İsteyin'));
      expect(stage2.top, greaterThan(lead2.bottom));
      expect(bullet2.top, greaterThan(stage2.bottom));
      expect(button2.top, greaterThan(bullet2.bottom));
      await tester.pump(const Duration(seconds: 1));
    });

    // Mobil ilk bakış: sahne bölümün üstüne yerleşince (üst çubuk altına etiketle birlikte) kutu, LED ve kapı
    // ekranda kalmalı. Eskiden başlık + 3 madde + düğme ekranın yarısını alıyor, kutu ekranın altından taşıyordu.
    for (final (name, size) in [
      ('412x784', const Size(412, 784)),
      ('390x844', const Size(390, 844)),
      ('360x740', const Size(360, 740)),
    ]) {
      testWidgets('mobil $name: sahne (kutu, LED, kapı, altyazı) etiketten itibaren tek ekrana sığar', (tester) async {
        _size(tester, size);
        await tester.pumpWidget(_app(const RemoteDoorScene()));
        await _settle(tester);
        final eyebrow = tester.getRect(find.text('İLK ÜRÜNÜMÜZ'));
        final stage = tester.getRect(find.byType(RemoteDoorStage));
        final captions = tester.getRect(find.text('3  Kapı açılır'));
        // Sahnenin tasarım koordinatındaki kutu altı, kapı üstü ve LED'in ekrandaki yeri.
        final geo = StageGeometry.tall;
        final s = stage.width / geo.design.width;
        final lowest = math.max(stage.top + geo.box.bottom * s, captions.bottom);
        final visibleBottom = eyebrow.top + size.height - _navBarHeight;
expect(lowest, lessThanOrEqualTo(visibleBottom), reason: 'kutu/altyazı alt=$lowest, görünür alt=$visibleBottom');
        expect(stage.top + geo.led.dy * s, lessThanOrEqualTo(visibleBottom));
        expect(stage.top + geo.door.top * s, greaterThanOrEqualTo(eyebrow.top));
        // Sahne küçülürken telefonun genişliği ekrandan taşmaz ve çok küçülmez.
        expect(stage.width, greaterThan(size.width * 0.65));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('kısa pencerede (yatay telefon) sahne çok küçülmez, taşma olmaz', (tester) async {
      _size(tester, const Size(780, 360));
      await tester.pumpWidget(_app(const RemoteDoorScene()));
      await _settle(tester);
      expect(tester.getRect(find.byType(RemoteDoorStage)).width, greaterThanOrEqualTo(300));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('"Teklif İsteyin" onContact çağırır', (tester) async {
      _size(tester, const Size(1440, 900));
      var n = 0;
      await tester.pumpWidget(_app(RemoteDoorScene(onContact: () => n++)));
      await _settle(tester);
      await tester.tap(find.text('Teklif İsteyin'));
      expect(n, 1);
      await tester.pump(const Duration(seconds: 1));
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: döngü gerçek zamanla ilerler, adımlar sırayla vurgulanır ve döngü sürer', (tester) async {
        final c = _palette(brightness);
        _size(tester, const Size(1440, 900));
        await tester.pumpWidget(_app(const RemoteDoorScene(), brightness: brightness));
        await _settle(tester); // her kare en çok 0.05 sn ilerletir: şimdi t ≈ 0.15 sn
        expect(tester.binding.transientCallbackCount, greaterThan(0));

        // Karelerin her biri 0.05 sn ilerletir (FrameLoop uzun kareleri sıkıştırır); sonda altyazı geçişi için bir kare daha.
        Future<void> run(double seconds) async {
          for (var i = 0; i < (seconds / 0.05).round(); i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          await tester.pump(const Duration(milliseconds: 400));
        }

        await run(3.8); // t ≈ 4.0: adım 2 (sinyal)
        expect(_captionColor(tester, '2  Sinyal gider'), c.text);
        expect(_captionColor(tester, '1  Dokunun'), c.textDim);
        await run(2.45); // t ≈ 6.5: adım 3 (kapı)
        expect(_captionColor(tester, '3  Kapı açılır'), c.text);
        expect(_captionColor(tester, '2  Sinyal gider'), c.textDim);
        await run(2.9); // t ≈ 9.4 → 0.4: döngü başa sardı, hiçbir adım vurgulu değil
        expect(_captionColor(tester, '3  Kapı açılır'), c.textDim);
        await run(3.55); // t ≈ 13.0 → 4.0: ikinci turda yine adım 2
        expect(_captionColor(tester, '2  Sinyal gider'), c.text);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sahne ekran dışındayken döngü durur, görününce baştan oynar', (tester) async {
      final c = AppColors.dark;
      _size(tester, const Size(1440, 900));
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(const RemoteDoorScene(), controller: controller, lead: 3000));
      await _settle(tester);
      // Ekran dışında: hiçbir kare isteği (ticker) yok.
      expect(tester.binding.transientCallbackCount, 0);

      controller.jumpTo(3000);
      await tester.pump();
      // Giriş animasyonları (Reveal) sonlu, döngü sonsuzdur: bitmeleri beklenince geriye yalnızca döngü kalır.
      await _settle(tester);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      Future<void> run(double seconds) async {
        for (var i = 0; i < (seconds / 0.05).round(); i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(milliseconds: 400));
      }

      await run(3.8); // t ≈ 4: adım 2
      expect(_captionColor(tester, '2  Sinyal gider'), c.text);

      controller.jumpTo(0);
      await tester.pump();
      await _settle(tester);
      expect(tester.binding.transientCallbackCount, 0);
      // Ekran dışında 6 sn geçse de zaman ilerlemez: döngü çalışsaydı t ≈ 10 → başa sarmış olurdu.
      await tester.pump(const Duration(seconds: 6));
      expect(_captionColor(tester, '2  Sinyal gider'), c.text);

      // Yeniden görününce reklam en baştan başlar (adım 2 değil).
      controller.jumpTo(3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_captionColor(tester, '2  Sinyal gider'), c.textDim);
      expect(_captionColor(tester, '1  Dokunun'), c.textDim);
    });

    testWidgets('hareketi azalt: giriş animasyonu ve döngü yok, içerik hemen görünür, durağan son kare', (tester) async {
      for (final brightness in Brightness.values) {
        final c = _palette(brightness);
        _size(tester, const Size(1440, 900));
        await tester.pumpWidget(_app(const RemoteDoorScene(), reduceMotion: true, brightness: brightness));
        // Hiçbir bekleme olmadan: içerik "Reveal" arkasında gizli kalmamalı.
        expect(find.byType(Reveal), findsNothing);
        expect(find.ancestor(of: find.text('Kapıyı telefonunuzdan açın.'), matching: find.byType(AnimatedOpacity)), findsNothing);
        expect(find.ancestor(of: find.byType(RemoteDoorStage), matching: find.byType(AnimatedOpacity)), findsNothing);
        await _settle(tester);
        expect(tester.binding.transientCallbackCount, 0);
        expect(_captionColor(tester, '3  Kapı açılır'), c.text);
        expect(_captionColor(tester, '1  Dokunun'), c.textDim);
        expect(_captionColor(tester, '2  Sinyal gider'), c.textDim);
        // Zaman ilerlese de bir şey değişmez.
        await tester.pump(const Duration(seconds: 3));
        expect(_captionColor(tester, '3  Kapı açılır'), c.text);
      }
    });

    testWidgets('hareketi azalt: sahne mobilde de ekran dışındayken bile görünür (kaydırma gerekmez)', (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(const RemoteDoorScene(), reduceMotion: true));
      expect(find.byType(Reveal), findsNothing);
      expect(find.byType(RemoteDoorStage), findsOneWidget);
      expect(find.ancestor(of: find.byType(RemoteDoorStage), matching: find.byType(AnimatedOpacity)), findsNothing);
    });

    testWidgets('hareket açıkken yalnızca metin süzülerek girer; reklam sahnesi gizlenmez', (tester) async {
      _size(tester, const Size(1440, 900));
      await tester.pumpWidget(_app(const RemoteDoorScene()));
      expect(find.byType(Reveal), findsOneWidget);
      // Reklamın ilk saniyesi (kutu belirir) bir giriş animasyonunun arkasında kaybolmasın.
      expect(find.ancestor(of: find.byType(RemoteDoorStage), matching: find.byType(AnimatedOpacity)), findsNothing);
      await _settle(tester);
      final opacity = tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Kapıyı telefonunuzdan açın.'), matching: find.byType(AnimatedOpacity)).first);
      expect(opacity.opacity, 1);
    });

    testWidgets('tema değişince sahne yeniden boyanır ve renkler yeni temadan gelir', (tester) async {
      _size(tester, const Size(1440, 900));
      await tester.pumpWidget(_app(const RemoteDoorScene(), brightness: Brightness.dark));
      await _settle(tester);
      expect(_captionColor(tester, '1  Dokunun'), AppColors.dark.textDim);
      await tester.pumpWidget(_app(const RemoteDoorScene(), brightness: Brightness.light));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // MaterialApp tema geçişi (themeAnimationDuration) biter
      expect(_captionColor(tester, '1  Dokunun'), AppColors.light.textDim);
      expect(tester.takeException(), isNull);
    });
  });

  group('görsel doğrulama', () {
    const times = [0.6, 2.0, 3.5, 4.8, 6.0, 8.0];

    for (final brightness in Brightness.values) {
      for (final (name, size, scrolled) in [('w1440', const Size(1440, 900), false), ('m390', const Size(390, 844), true)]) {
        testWidgets('${brightness.name} $name için t=${times.join(", ")} sn görüntüleri üretilir', (tester) async {
          _size(tester, size);
          final clock = AdClock(times.first);
          addTearDown(clock.dispose);
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: _app(RemoteDoorScene(debugClock: clock), brightness: brightness, controller: controller),
          ));
          await _loadBoxImage(tester);
          await _settle(tester);
          if (scrolled) {
            // Mobilde sahnenin kendisi (telefon + kutu + kapı) ekranda olsun.
            controller.jumpTo(controller.position.maxScrollExtent);
            await tester.pump();
          }
          for (final t in times) {
            clock.time = t;
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            final path = await captureBoundary(tester, key, name: 'remote_door_${brightness.name}_${name}_${(t * 10).round()}');
            expect(File(path).lengthSync(), greaterThan(5000), reason: path);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    /// Kutunun, zeminin ve LED'in sahnede nerede olduğunu piksel olarak hesaplayıp ölçer.
    Offset toPixel(WidgetTester tester, Offset design) {
      final rect = tester.getRect(find.byType(RemoteDoorStage));
      final s = rect.width / StageGeometry.wide.design.width;
      return rect.topLeft + design * s;
    }

    Offset onBox(Offset normalized) {
      final b = StageGeometry.wide.box;
      return b.topLeft + Offset(b.width * normalized.dx, b.height * normalized.dy);
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: kutu zeminden ayrışır (açık zeminde silikleşmez), temas gölgesi belirgindir', (tester) async {
        _size(tester, const Size(1440, 900));
        final clock = AdClock(AdTimeline.restTime);
        addTearDown(clock.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: _app(RemoteDoorScene(debugClock: clock), brightness: brightness)));
        await _loadBoxImage(tester);
        await _settle(tester);
        final px = await _Pixels.of(tester, key);

        // Ön yüzün sol-orta bölgesi (LED parıltısının dışında) ve sahnenin boş bir köşesi.
        final face = px.meanLuminance(toPixel(tester, onBox(const Offset(0.25, 0.60))), 3);
        final empty = px.meanLuminance(toPixel(tester, const Offset(40, 90)), 3);
        // Koyu temada ürün zaten zeminden açıktır (kontrast daha düşük olabilir); açık temada koyu grafit olmalı.
        final needed = brightness == Brightness.light ? 4.5 : 1.3;
        expect(_contrast(face, empty), greaterThan(needed), reason: 'yüz=$face zemin=$empty');

        // Temas gölgesi: kutunun ön-alt kenarının hemen altındaki zemin, sahnenin gölgesiz zeminden belirgin koyudur.
        // (Koyu temada zemin zaten çok koyudur; ölçü yalnızca açık tema için anlamlıdır.)
        if (brightness == Brightness.light) {
          final floorMid = Offset(0.5, BoxAsset.floorA.dy + (BoxAsset.floorB.dy - BoxAsset.floorA.dy) / (BoxAsset.floorB.dx - BoxAsset.floorA.dx) * (0.5 - BoxAsset.floorA.dx));
          final under = px.meanLuminance(toPixel(tester, onBox(floorMid) + const Offset(0, 5)), 2);
          final reference = px.meanLuminance(toPixel(tester, const Offset(40, 500)), 2);
          expect(under, lessThan(reference * 0.82), reason: 'gölge=$under referans=$reference');
        }
      });

      testWidgets('${brightness.name}: LED parlaması görünür (mavi çekirdek ve çevre)', (tester) async {
        _size(tester, const Size(1440, 900));
        // Aynı kutu konumunda (yüzme farkı < 1 birim) LED kapalı ve açık.
        final clock = AdClock(4.4);
        addTearDown(clock.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: _app(RemoteDoorScene(debugClock: clock), brightness: brightness)));
        await _loadBoxImage(tester);
        await _settle(tester);
        clock.time = 4.4;
        await tester.pump();
        final off = await _Pixels.of(tester, key);
        clock.time = 5.0;
        await tester.pump();
        final on = await _Pixels.of(tester, key);

        final led = toPixel(tester, StageGeometry.wide.led);
        final (r0, _, b0) = off.rgb(led);
        final (r1, _, b1) = on.rgb(led);
        // Çekirdekte belirgin aydınlanma ve maviye kayma.
        expect(on.luminance(led), greaterThan(off.luminance(led) + 0.08));
        expect(b1 - r1, greaterThan(b0 - r0));

        // Parıltının çevresi (LED'in ~28 birim sağında, ön yüzde): iki temada da belirgin değişir.
        final ring = led + Offset(28 * tester.getRect(find.byType(RemoteDoorStage)).width / StageGeometry.wide.design.width, 0);
        final offRing = off.luminance(ring);
        final onRing = on.luminance(ring);
        expect((onRing - offRing).abs(), greaterThan(0.01), reason: 'çevre: $offRing -> $onRing');
      });

      testWidgets('${brightness.name}: sinyal darbeleri zeminde görünür', (tester) async {
        _size(tester, const Size(1440, 900));
        final clock = AdClock(3.0);
        addTearDown(clock.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: _app(RemoteDoorScene(debugClock: clock), brightness: brightness)));
        await _loadBoxImage(tester);
        await _settle(tester);

        final geo = StageGeometry.wide;
        Offset bezier(double t) {
          final u = 1 - t;
          return geo.signalStart * (u * u * u) + geo.signalC1 * (3 * u * u * t) + geo.signalC2 * (3 * u * t * t) + geo.led * (t * t * t);
        }

        /// Eğrinin zeminde (kutu ile telefon arasında) kalan ilk bölümünde, eğri üzerindeki piksellerle 12 birim
        /// yanındaki piksellerin parlaklık farkının en büyüğü.
        Future<double> pulseContrast(double time) async {
          clock.time = time;
          await tester.pump();
          final px = await _Pixels.of(tester, key);
          var best = 0.0;
          var samples = 0;
          for (var i = 4; i <= 60; i++) {
            final u = i / 100;
            final tangent = bezier(u + 0.01) - bezier(u - 0.01);
            final normal = Offset(-tangent.dy, tangent.dx) / tangent.distance;
            final onDesign = bezier(u);
            final besideDesign = onDesign + normal * 12;
            // Yalnızca çıplak zemindeki örnekler: telefon, kutu ve kapının kendi kenarları sayılmaz.
            final free = [onDesign, besideDesign].every((p) => ![geo.phone, geo.box, geo.door].any((r) => r.inflate(14).contains(p)));
            if (!free) continue;
            samples++;
            final on = px.meanLuminance(toPixel(tester, onDesign), 1);
            final beside = px.meanLuminance(toPixel(tester, besideDesign), 1);
            best = math.max(best, (on - beside).abs());
          }
          expect(samples, greaterThan(10), reason: 'eğrinin zeminde kalan kısmı yeterince örneklenmeli');
          return best;
        }

        final idle = await pulseContrast(3.0); // sinyal henüz yok
        final pulsing = await pulseContrast(3.4); // ilk darbeler zeminde
        // Zeminin kendi eğimi (parıltı, telefon gölgesi) küçük bir taban fark verir; darbeler bunun çok üstündedir.
        expect(pulsing, greaterThan(idle * 3 + 0.05), reason: 'darbeler zeminden ayrışmalı: boş=$idle darbeli=$pulsing');
        expect(idle, lessThan(0.06), reason: 'sinyal yokken eğri boş olmalı');
      });
    }
  });
}
