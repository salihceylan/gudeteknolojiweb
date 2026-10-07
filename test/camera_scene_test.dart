import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/camera3d/camera_pose.dart';
import 'package:gudeteknolojiweb/scenes/camera/camera_layout.dart';
import 'package:gudeteknolojiweb/scenes/camera/camera_stage_painters.dart';
import 'package:gudeteknolojiweb/scenes/camera/product_layer.dart';
import 'package:gudeteknolojiweb/scenes/camera/rotation_physics.dart';
import 'package:gudeteknolojiweb/scenes/camera_scene.dart';
import 'package:gudeteknolojiweb/theme.dart';

import 'helpers/app.dart';
import 'helpers/shot.dart';

const _tau = math.pi * 2;
const _k = 0.005; // rad/px (fizik testlerinde sabit)

/// Saf fizikte [seconds] saniyeyi 1/60 adımlarla ilerletir; her adımda [onStep] çağrılır.
void _run(RotationPhysics p, double seconds, [void Function(double t)? onStep]) {
  const dt = 1 / 60;
  final n = (seconds / dt).round();
  for (var i = 1; i <= n; i++) {
    p.step(dt);
    onStep?.call(i * dt);
  }
}

void main() {
  setUpAll(loadAppFonts);

  group('RotationPhysics', () {
    test('sürükleme: sağa giden parmak ürünün ön yüzünü sağa döndürür (yaw azalır), açı doğrudan izlenir', () {
      final p = RotationPhysics()..reset();
      final y0 = p.yaw;
      p.dragStart();
      p.dragUpdate(100, _k);
      expect(p.yaw, closeTo(y0 - 100 * _k, 1e-9));
      p.dragUpdate(-300, _k);
      expect(p.yaw, closeTo(y0 + 200 * _k, 1e-9));
      expect(p.phase, RotationPhase.dragging);
    });

    test('momentum: hız üstel söner (yarı ömür ~0.35 sn), monoton azalır; eşikte yay devralır ve konum/hız süreklidir', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragUpdate(-200, _k);
      // ω = dragSign * v * k = -1 * (-1600) * 0.005 = +8 rad/sn
      p.dragEnd(-1600, _k);
      expect(p.phase, RotationPhase.coasting);
      expect(p.omega, closeTo(8, 1e-9));

      var prev = p.omega;
      var prevYaw = p.yaw;
      var maxJump = 0.0;
      double? halfAt;
      var handoffAt = -1.0;
      _run(p, 6, (t) {
        if (p.phase == RotationPhase.coasting) {
          expect(p.omega, lessThan(prev), reason: 'momentum yalnızca azalmalı (t=$t)');
          prev = p.omega;
          if (halfAt == null && p.omega <= 4) halfAt = t;
        } else if (handoffAt < 0) {
          handoffAt = t;
        }
        maxJump = math.max(maxJump, (p.yaw - prevYaw).abs());
        prevYaw = p.yaw;
      });
      expect(halfAt, isNotNull);
      expect(halfAt!, closeTo(0.35, 0.03), reason: 'hız 0.35 sn sonra yarıya inmeli');
      expect(handoffAt, greaterThan(0.8), reason: 'momentum bir süre sürmeli');
      expect(handoffAt, lessThan(2.0));
      // 60 kare/sn'de bir karede 8 rad/sn * 1/60 ≈ 0.13 rad'dan fazla sıçrama olmamalı (yay devralırken de).
      expect(maxJump, lessThan(0.14));
      expect(p.phase, RotationPhase.rest);
    });

    test('momentum yolu: bırakmadan sonra ürün aynı yönde bir süre daha döner (hemen geri dönmez)', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragUpdate(-100, _k);
      final released = p.yaw;
      p.dragEnd(-1200, _k); // ω = +6
      _run(p, 0.3);
      expect(p.yaw, greaterThan(released + 0.8), reason: 'momentum ile ilerlemeli');
    });

    test('sert fırlatma üst sınırla kırpılır', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragEnd(-90000, _k);
      expect(p.omega, closeTo(p.maxOmega, 1e-9));
      final q = RotationPhysics()..reset();
      q.dragStart();
      q.dragEnd(90000, _k);
      expect(q.omega, closeTo(-q.maxOmega, 1e-9));
    });

    test('yavaş/duran bırakma: momentum yok, yay hemen başlar', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragUpdate(60, _k);
      p.dragEnd(10, _k);
      expect(p.phase, RotationPhase.returning);
    });

    test('3 tur sonra bırakılınca ana poza EN KISA yoldan döner, hafif aşar ve 1.2–1.8 sn içinde oturur', () {
      const extra = 1.0; // ana pozdan 3 tur + 1 rad uzakta
      final home3 = kCameraHomeYaw + 3 * _tau;
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragUpdate(-(3 * _tau + extra) / _k, _k); // dragSign=-1: negatif dx yaw'ı artırır
      expect(p.yaw, closeTo(home3 + extra, 1e-6));
      p.dragEnd(0, _k);
      expect(p.phase, RotationPhase.returning);
      expect(p.target, closeTo(home3, 1e-9), reason: '3 tur geri sarmak yerine en yakın eşdeğer ana poz hedeflenmeli');

      var minYaw = p.yaw;
      var maxYaw = p.yaw;
      double? settledAt;
      var lastOutside1deg = 0.0;
      _run(p, 4, (t) {
        minYaw = math.min(minYaw, p.yaw);
        maxYaw = math.max(maxYaw, p.yaw);
        if (p.phase == RotationPhase.returning && (p.yaw - home3).abs() >= 1 * math.pi / 180) lastOutside1deg = t;
        if (settledAt == null && p.phase == RotationPhase.rest) settledAt = t;
      });
      // Hiçbir an başlangıçtan daha uzağa gitmedi ve 3 tur geri sarmadı.
      expect(maxYaw, closeTo(home3 + extra, 1e-6));
      expect(minYaw, greaterThan(home3 - 0.3), reason: 'kısa yoldan dönmeli, tur atmamalı');
      // Hedefi aştı (aşmalı oturma): yay ζ=0.65 → ~%7 aşar; aşma görünür ama küçük olmalı.
      final overshoot = home3 - minYaw;
      expect(overshoot, greaterThan(0.02));
      expect(overshoot, lessThan(extra * 0.12));
      // Süre: ürün hedefin 1° çevresine kalıcı olarak 1.2–1.8 sn içinde girer (aşma dahil).
      expect(lastOutside1deg, inInclusiveRange(1.2, 1.8));
      expect(settledAt, isNotNull);
      expect(settledAt!, lessThan(3.5));
      expect(p.phase, RotationPhase.rest);
      expect(p.yaw, closeTo(home3, 0.1), reason: 'oturdu; yalnızca boşta salınım payı (±5°) kaldı');
    });

    test('ana pozun diğer yanından bırakılınca da en kısa yol seçilir (π\'den uzaksa bir tur ileri)', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragUpdate(-(4.0) / _k, _k); // ana pozdan +4 rad: hedef home+2π (2.28 rad ileride), geri 4 rad değil
      p.dragEnd(0, _k);
      expect(p.target, closeTo(kCameraHomeYaw + _tau, 1e-9));
      _run(p, 5);
      // Dinlenmeye geçince boşta salınım (±5° = 0.087 rad) yeniden başlar; yaw ana poz çevresindedir.
      expect(p.yaw, closeTo(kCameraHomeYaw + _tau, 0.09));
      expect(p.phase, RotationPhase.rest);
    });

    test('bırakmada anında atlama yok: yay her karede küçük adımlarla ilerler', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragUpdate(-(math.pi * 0.95) / _k, _k);
      p.dragEnd(0, _k);
      var prev = p.yaw;
      final start = p.yaw;
      var maxStep = 0.0;
      double? firstStep;
      _run(p, 3, (_) {
        final step = (p.yaw - prev).abs();
        firstStep ??= step;
        maxStep = math.max(maxStep, step);
        prev = p.yaw;
      });
      final distance = (start - p.target).abs();
      expect(firstStep!, lessThan(0.02), reason: 'yay durgunluktan yumuşakça hızlanır; ilk karede sıçrama yok');
      expect(maxStep, lessThan(distance * 0.08), reason: 'hiçbir karede yolun yüzde 8 inden fazlası kat edilmez (anında atlama yok)');
    });

    test('yeni sürükleme başlayınca fizik hemen devredilir', () {
      final p = RotationPhysics()..reset();
      p.dragStart();
      p.dragEnd(-1600, _k);
      _run(p, 0.2);
      final y = p.yaw;
      p.dragStart();
      expect(p.phase, RotationPhase.dragging);
      _run(p, 0.5);
      expect(p.yaw, closeTo(y, 1e-9), reason: 'sürüklerken ürün kendi başına kaymaz');
      expect(p.idleBlend, 0);
    });

    test('boşta salınım: yaw ana pozun ±5°, pitch ±1.5° çevresinde kalır ve gerçekten salınır', () {
      final p = RotationPhysics()..reset();
      var minD = 0.0, maxD = 0.0, minP = 0.0, maxP = 0.0;
      _run(p, 40); // salınım yavaşça devreye girer (~2 sn)
      _run(p, 30, (_) {
        final d = p.yaw - kCameraHomeYaw;
        minD = math.min(minD, d);
        maxD = math.max(maxD, d);
        minP = math.min(minP, p.idlePitch);
        maxP = math.max(maxP, p.idlePitch);
      });
      const deg = math.pi / 180;
      expect(maxD, inInclusiveRange(4.0 * deg, 5.2 * deg));
      expect(minD, inInclusiveRange(-5.2 * deg, -4.0 * deg));
      expect(maxP, inInclusiveRange(1.2 * deg, 1.51 * deg));
      expect(minP, inInclusiveRange(-1.51 * deg, -1.2 * deg));
    });

    test('hareketi azalt: salınım yok, momentum yok, bırakınca ana poza anında oturur', () {
      final p = RotationPhysics()
        ..reset()
        ..reduceMotion = true;
      _run(p, 20);
      expect(p.yaw, kCameraHomeYaw);
      expect(p.idlePitch, 0);
      expect(p.needsFrames, isFalse, reason: 'boşta kare gerekmez');

      p.dragStart();
      p.dragUpdate(-300, _k);
      expect(p.yaw, isNot(closeTo(kCameraHomeYaw, 0.1)));
      p.dragEnd(-3000, _k);
      expect(p.phase, RotationPhase.rest);
      expect(p.yaw, closeTo(nearestHomeYaw(kCameraHomeYaw + 300 * _k), 1e-9));
      expect(p.omega, 0);
    });

    test('klavye: yay hedef açıya gider, kısa süre bekler, sonra ana poza döner', () {
      final p = RotationPhysics()..reset();
      _run(p, 5);
      final start = p.yaw;
      const step = 15 * math.pi / 180;
      p.nudge(step);
      expect(p.phase, RotationPhase.holding);
      _run(p, 1.5);
      expect(p.yaw, closeTo(start + step, 0.02), reason: '15° döndü ve bekliyor');
      p.nudge(step);
      _run(p, 1.5);
      expect(p.yaw, closeTo(start + 2 * step, 0.02), reason: 'ikinci basış hedefe eklenir');
      _run(p, 6);
      expect(p.phase, RotationPhase.rest);
      expect(p.yaw, closeTo(kCameraHomeYaw, 0.1), reason: 'bekleme bitince ana poza döndü (salınım payı)');
    });
  });

  group('CameraSceneLayout', () {
    test('geniş: ürün sağda ve büyük, metin solda; hiçbir kutu sahne dışına taşmaz', () {
      for (final size in const [Size(1440, 900), Size(1024, 768), Size(900, 700), Size(1280, 520)]) {
        final l = CameraSceneLayout.compute(size: size, mode: CameraLayoutMode.wide, textHeight: 200, sidePad: 40, aspect: kProductAspect);
        expect(l.product.center.dx - l.product.width * kProductVisibleWidth / 2, greaterThan(l.text.right), reason: '$size: ürünün görünür alanı metnin sağında');
        expect(l.product.height, lessThanOrEqualTo(size.height * 0.58 + 0.5), reason: '$size');
        expect(l.product.top, greaterThanOrEqualTo(CameraSceneLayout.topInset), reason: '$size: üst çubuğun altında');
        expect(l.hint.bottom, lessThanOrEqualTo(size.height), reason: '$size: ipucu sahne içinde');
        expect(l.noteGeometry, hasLength(3));
      }
    });

    test('dar: metin üstte, ürün ortada, notlar ürünün altında, ipucu en altta; üst üste binmez', () {
      for (final size in const [Size(390, 844), Size(360, 740), Size(600, 900), Size(320, 600)]) {
        final l = CameraSceneLayout.compute(size: size, mode: CameraLayoutMode.narrow, textHeight: 190, sidePad: 24, aspect: kProductAspect);
        expect(l.text.top, greaterThanOrEqualTo(CameraSceneLayout.topInset), reason: '$size');
        expect(l.product.top, greaterThanOrEqualTo(l.text.bottom - 0.5), reason: '$size: ürün metnin altında');
        expect(l.notes.top, greaterThanOrEqualTo(l.product.bottom - 0.5), reason: '$size: notlar ürünün altında');
        expect(l.hint.top, greaterThanOrEqualTo(l.notes.bottom - 0.5), reason: '$size: ipucu notların altında');
        expect(l.hint.bottom, lessThanOrEqualTo(size.height + 0.5), reason: '$size');
        expect(l.product.width * kProductVisibleWidth, lessThanOrEqualTo(size.width + 0.5), reason: '$size: yandan görünüm ekrana sığar');
      }
    });
  });

  group('CameraSceneLayout kipleri (AN-02/MB-01: kısa ve yatay görüntü alanı)', () {
    /// Metnin, ürünün görünür siluetinin (kutu genişliğinin kProductVisibleWidth'i) ve ipucunun kutuları.
    Map<String, Rect> boxes(CameraSceneLayout l) => {
          'metin': l.text,
          'ürün': Rect.fromCenter(center: l.product.center, width: l.product.width * kProductVisibleWidth, height: l.product.height),
          'ipucu': l.hint,
          if (!l.notes.isEmpty) 'notlar': l.notes,
          for (var i = 0; i < l.noteGeometry.length; i++) 'not$i': l.noteGeometry[i].label,
        };

    const sizes = [
      Size(844, 390), // Chrome mobil emülasyon, yatay telefon
      Size(864, 304), // Android emülatör, yatay
      Size(915, 412),
      Size(1366, 640),
      Size(1440, 900),
      Size(1024, 768),
      Size(768, 1024),
      Size(390, 844),
      Size(360, 740),
      Size(360, 640),
      Size(360, 480),
    ];

    test('kip seçimi: yalnızca genişliğe değil yüksekliğe de bakar', () {
      expect(CameraSceneLayout.modeFor(const Size(1440, 900)), CameraLayoutMode.wide);
      expect(CameraSceneLayout.modeFor(const Size(864, 304)), CameraLayoutMode.compact);
      expect(CameraSceneLayout.modeFor(const Size(844, 390)), CameraLayoutMode.compact);
      expect(CameraSceneLayout.modeFor(const Size(768, 1024)), CameraLayoutMode.narrow);
      expect(CameraSceneLayout.modeFor(const Size(360, 640)), CameraLayoutMode.narrow);
    });

    test('metin, ürün, ipucu ve notlar hiçbir görüntü alanında kesişmez; hepsi sahne içindedir', () {
      for (final size in sizes) {
        for (final textHeight in const [150.0, 260.0]) {
          final mode = CameraSceneLayout.modeFor(size);
          final l = CameraSceneLayout.compute(size: size, mode: mode, textHeight: textHeight, sidePad: 24, aspect: kProductAspect);
          final b = boxes(l);
          final names = b.keys.toList();
          for (var i = 0; i < names.length; i++) {
            final r = b[names[i]]!;
            expect(r.left, greaterThanOrEqualTo(-0.5), reason: '$size ${names[i]}');
            expect(r.right, lessThanOrEqualTo(size.width + 0.5), reason: '$size ${names[i]}');
            expect(r.bottom, lessThanOrEqualTo(size.height + 0.5), reason: '$size ${names[i]}');
            for (var j = i + 1; j < names.length; j++) {
              // Not etiketleri ürünün kutusu içinde durabilir (çizgi ürüne uzanır); yalnızca metin/ipucu/notlarla sınanır.
              if (names[i].startsWith('not') && names[i] != 'notlar' && names[j] == 'ürün') continue;
              if (names[j].startsWith('not') && names[j] != 'notlar' && names[i] == 'ürün') continue;
              // Geniş düzende ipucu ürün kutusunun alt boşluğuna 6 px girer (kutunun içi boştur); bilinçli.
              if (mode == CameraLayoutMode.wide && {names[i], names[j]}.containsAll(const {'ürün', 'ipucu'})) continue;
              final inter = b[names[i]]!.intersect(b[names[j]]!);
              final overlaps = inter.width > 0.5 && inter.height > 0.5;
              expect(overlaps, isFalse, reason: '$size (h=$textHeight, $mode): ${names[i]} ile ${names[j]} üst üste biniyor: ${b[names[i]]} / ${b[names[j]]}');
            }
          }
        }
      }
    });

    test('yatay telefonda kontrollü: metin küçülmez, ürün okunur boyutta kalır, yan yana dizilir', () {
      for (final size in const [Size(844, 390), Size(864, 304)]) {
        final l = CameraSceneLayout.compute(size: size, mode: CameraSceneLayout.modeFor(size), textHeight: 160, sidePad: 28, aspect: kProductAspect);
        expect(l.wide, isFalse);
        expect(l.text.height, 160, reason: '$size: kısa ekranda bile metin kırpılmadan/küçülmeden sığmalı');
        expect(l.product.height, greaterThanOrEqualTo(kMinProductHeight), reason: '$size: ürün çok küçük');
        expect(l.product.left, greaterThan(l.text.right), reason: '$size: ürün metnin sağında');
        expect(l.notes.isEmpty, isTrue, reason: '$size: kısa alanda notlar gizlenir');
        expect(l.noteGeometry, isEmpty);
        expect(l.text.top, greaterThanOrEqualTo(CameraSceneLayout.topInset), reason: '$size: üst çubuğun altında');
      }
    });

    test('dar düzende ürüne yer kalmazsa önce notlar gizlenir, ürün asla minimum yüksekliğin altına inmez', () {
      // 360x480 dikey: 3 not satırı + ipucu + metin birlikte sığmaz.
      final l = CameraSceneLayout.compute(size: const Size(360, 480), mode: CameraLayoutMode.narrow, textHeight: 190, sidePad: 24, aspect: kProductAspect);
      expect(l.notes.isEmpty, isTrue);
      expect(l.product.height, greaterThanOrEqualTo(kMinProductHeight - 0.5));
      // Yeterince uzun ekranda notlar kalır.
      final tall = CameraSceneLayout.compute(size: const Size(390, 844), mode: CameraLayoutMode.narrow, textHeight: 190, sidePad: 24, aspect: kProductAspect);
      expect(tall.notes.isEmpty, isFalse);
    });
  });

  group('Not görünürlüğü (CH-09)', () {
    const deg = math.pi / 180;

    test('ana pozda ve boşta salınım aralığında (±5°) tam görünür, yan/arka görünümlerde yok', () {
      expect(noteVisibilityForYaw(kCameraHomeYaw), 1);
      expect(noteVisibilityForYaw(kCameraHomeYaw + 5 * deg), 1);
      expect(noteVisibilityForYaw(kCameraHomeYaw - 5 * deg), 1);
      expect(noteVisibilityForYaw(kCameraHomeYaw + 135 * deg), 0);
      expect(noteVisibilityForYaw(kCameraHomeYaw + 180 * deg), 0);
    });

    test('monoton söner, simetriktir ve tam turlarda (birden çok tur) ana pozu tanır', () {
      var prev = 1.0;
      for (var d = 0; d <= 40; d++) {
        final v = noteVisibilityForYaw(kCameraHomeYaw + d * deg);
        expect(v, lessThanOrEqualTo(prev + 1e-12), reason: '$d°');
        expect(noteVisibilityForYaw(kCameraHomeYaw - d * deg), closeTo(v, 1e-9), reason: '-$d°');
        prev = v;
      }
      expect(noteVisibilityForYaw(kCameraHomeYaw + 3 * _tau), 1);
      expect(noteVisibilityForYaw(kCameraHomeYaw + 3 * _tau + 135 * deg), 0);
      expect(noteVisibilityForYaw(kCameraHomeYaw + 20 * deg), inExclusiveRange(0.2, 0.8));
    });
  });

  group('CameraSceneLayout notları', () {
    test('etiketler sahne içinde kalır, birbirine, metne ve ipucuna binmez (büyük etiket genişliklerinde de)', () {
      for (final size in const [Size(1440, 900), Size(1024, 768), Size(900, 700), Size(1920, 1080)]) {
        for (final widths in const [[110.0, 90.0, 80.0], [150.0, 130.0, 110.0]]) {
          final l = CameraSceneLayout.compute(
            size: size,
            mode: CameraLayoutMode.wide,
            textHeight: 230,
            sidePad: 40,
            aspect: kProductAspect,
            noteLabelWidths: widths,
          );
          for (var i = 0; i < 3; i++) {
            final r = l.noteGeometry[i].label;
            expect(r.left, greaterThanOrEqualTo(0), reason: '$size $widths #$i');
            expect(r.right, lessThanOrEqualTo(size.width), reason: '$size $widths #$i');
            expect(r.top, greaterThanOrEqualTo(CameraSceneLayout.topInset - 20), reason: '$size #$i');
            expect(r.bottom, lessThanOrEqualTo(size.height), reason: '$size #$i');
            expect(r.overlaps(l.text), isFalse, reason: '$size $widths: not #$i metne biniyor');
            expect(r.overlaps(l.hint), isFalse, reason: '$size $widths: not #$i ipucuna biniyor');
            for (var j = i + 1; j < 3; j++) {
              expect(r.overlaps(l.noteGeometry[j].label), isFalse, reason: '$size: #$i ile #$j çakışıyor');
            }
          }
        }
      }
    });
  });

  group('CameraScene (widget)', () {
    late ValueNotifier<double> reveal;

    setUp(() => reveal = ValueNotifier<double>(1));
    tearDown(() => reveal.dispose());

    Widget scene({Brightness brightness = Brightness.dark, bool reduceMotion = false, double textScale = 1}) {
      return testApp(
        MediaQuery(
          data: MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first)
              .copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SizedBox.expand(child: CameraScene(reveal: reveal))),
        ),
        brightness: brightness,
      );
    }

    Future<CameraSceneState> mount(WidgetTester tester, Size size, {Brightness brightness = Brightness.dark, bool reduceMotion = false, double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(scene(brightness: brightness, reduceMotion: reduceMotion, textScale: textScale));
      await tester.pump(const Duration(milliseconds: 200));
      return tester.state<CameraSceneState>(find.byType(CameraScene));
    }

    Future<void> frames(WidgetTester tester, double seconds) async {
      final n = (seconds * 60).round();
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    /// Ürünü çizen CustomPaint (painter türü [buildProductPainter]'ın döndürdüğüdür).
    Finder productCanvas() {
      final type = buildProductPainter(pose: CameraPose(), quality: 1, shadowColor: Colors.black, rimStrength: 1).runtimeType;
      return find.byWidgetPredicate((w) => w is CustomPaint && w.painter?.runtimeType == type);
    }

    Finder product() => find.descendant(of: find.byType(CameraScene), matching: find.byType(GestureDetector)).first;

    testWidgets('metinler şartnameyle birebir; geniş düzende üç çizgi-notu ve ipucu görünür', (tester) async {
      await mount(tester, const Size(1440, 900));
      expect(find.text('KAMERA SİSTEMLERİ'), findsOneWidget);
      expect(find.text('Her açıdan net görüntü.'), findsOneWidget);
      expect(
        find.text('IP ve analog kamera sistemleri, kayıt çözümleri, ağ altyapısı ve profesyonel görüntüleme sistemleri.'),
        findsOneWidget,
      );
      for (final n in ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Sürükleyerek döndürün'), findsOneWidget);
      expect(find.text('Yatay çevirerek döndürün'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobilde ipucu "Yatay çevirerek döndürün"dür ve notlar ürünün altındadır', (tester) async {
      await mount(tester, const Size(390, 844));
      expect(find.text('Yatay çevirerek döndürün'), findsOneWidget);
      expect(find.text('Sürükleyerek döndürün'), findsNothing);
      final productBottom = tester.getBottomLeft(product()).dy;
      for (final n in ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı']) {
        expect(tester.getTopLeft(find.text(n)).dy, greaterThan(productBottom - 1), reason: n);
      }
    });

    for (final dark in [true, false]) {
      for (final size in const [Size(1440, 900), Size(1024, 768), Size(390, 844), Size(360, 740), Size(1280, 520), Size(844, 390), Size(864, 304), Size(360, 640)]) {
        for (final scale in const [1.0, 2.0]) {
          testWidgets('taşma yok: ${dark ? 'koyu' : 'açık'} ${size.width.toInt()}x${size.height.toInt()} yazı x$scale', (tester) async {
            await mount(tester, size, brightness: dark ? Brightness.dark : Brightness.light, textScale: scale);
            expect(tester.takeException(), isNull);
            // Metin bloğu sahne içinde kalır (büyük yazıda içeride küçülür).
            final title = tester.getRect(find.text('Her açıdan net görüntü.'));
            expect(title.left, greaterThanOrEqualTo(-0.5));
            expect(title.right, lessThanOrEqualTo(size.width + 0.5));
            expect(title.bottom, lessThanOrEqualTo(size.height));
            // Etiketler sağdan/soldan taşmaz (yatay-kısa kipte notlar hiç çizilmez).
            for (final n in ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı']) {
              if (find.text(n).evaluate().isEmpty) {
                expect(CameraSceneLayout.modeFor(size), isNot(CameraLayoutMode.wide), reason: '$n geniş düzende her zaman çizilir');
                continue;
              }
              final r = tester.getRect(find.text(n));
              expect(r.left, greaterThanOrEqualTo(-0.5), reason: n);
              expect(r.right, lessThanOrEqualTo(size.width + 0.5), reason: '$n sağdan taşıyor');
            }
          });
        }
      }
    }

    testWidgets('giriş: reveal 0\'da ürün ve yazılar görünmez, 0.5\'te ürün kısmen, 1\'de tamamen görünür', (tester) async {
      double opacityOf(Finder f) {
        final ops = tester.widgetList<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)));
        return ops.fold(1.0, (a, o) => a * o.opacity);
      }

      reveal.value = 0;
      await mount(tester, const Size(1440, 900));
      final title = find.text('Her açıdan net görüntü.');
      final productPaint = productCanvas();
      expect(productPaint, findsOneWidget);
      expect(opacityOf(title), 0);
      expect(opacityOf(productPaint), 0);
      expect(find.text('Sürükleyerek döndürün').hitTestable(), findsNothing);

      reveal.value = 0.5;
      await tester.pump();
      expect(opacityOf(productPaint), inExclusiveRange(0.3, 1));
      expect(opacityOf(title), 0, reason: 'yazılar 0.55\'ten sonra gelir');
      double smallestScale() => tester
          .widgetList<Transform>(find.ancestor(of: productPaint, matching: find.byType(Transform)))
          .map((t) => t.transform.entry(0, 0))
          .reduce(math.min);
      final scaleHalf = smallestScale();
      expect(scaleHalf, inExclusiveRange(0.82, 1.0));

      reveal.value = 1;
      await tester.pump();
      expect(opacityOf(productPaint), 1);
      expect(opacityOf(title), 1);
      final scaleFull = smallestScale();
      expect(scaleFull, closeTo(1, 1e-9));
    });

    testWidgets('reveal < 0.98 iken jestler kapalı; 1\'de sürükleme yaw\'ı değiştirir', (tester) async {
      reveal.value = 0.9;
      final s = await mount(tester, const Size(1440, 900));
      final before = s.debugPose.yaw;
      await tester.drag(product(), const Offset(-200, 0), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(s.debugPhysics.phase, isNot(RotationPhase.dragging));
      expect((s.debugPose.yaw - before).abs(), lessThan(0.2), reason: 'yalnızca boşta salınım payı');
      expect(s.debugHintGone, isFalse);

      reveal.value = 1;
      await tester.pump();
      final g = await tester.startGesture(tester.getCenter(product()), kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(-120, 0));
      await tester.pump();
      final mid = s.debugPose.yaw;
      expect(mid, greaterThan(before + 0.3), reason: 'sola sürükleme yaw\'ı artırır');
      expect(s.debugPhysics.phase, RotationPhase.dragging);
      await g.up();
      await tester.pump();
    });

    testWidgets('jest ayrımı: dikey sürükleme sayfayı kaydırır (yaw değişmez); yatay sürükleme yaw\'ı değiştirir (kaydırma değişmez)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  SizedBox(height: 640, child: CameraScene(reveal: reveal)),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final s = tester.state<CameraSceneState>(find.byType(CameraScene));
      final yaw0 = s.debugPose.yaw;
      expect(controller.offset, 0);

      // Dikey: sayfa kayar, ürün dönmez.
      await tester.drag(product(), const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.offset, greaterThan(100), reason: 'dikey sürükleme kaydırmayı değiştirmeli');
      expect(s.debugPhysics.phase, isNot(RotationPhase.dragging));
      expect(s.debugPhysics.phase, isNot(RotationPhase.coasting));
      expect((s.debugPose.yaw - yaw0).abs(), lessThan(0.15), reason: 'dikey sürükleme yaw\'ı değiştirmemeli (yalnızca boşta salınım)');
      expect(s.debugHintGone, isFalse);

      // Yatay: ürün döner, sayfa kaymaz.
      controller.jumpTo(0);
      await tester.pump();
      final offsetBefore = controller.offset;
      final g = await tester.startGesture(tester.getCenter(product()));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.offset, offsetBefore, reason: 'yatay sürükleme kaydırmayı değiştirmemeli');
      expect(s.debugPhysics.phase, RotationPhase.dragging);
      expect(s.debugPose.yaw, greaterThan(yaw0 + 1.0), reason: '300 px sürükleme ~1.5 rad döndürmeli');
      await g.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.offset, offsetBefore);
      // Bırakınca ana poza dönüş sürer (aşağıdaki test ayrıntıyı doğrular); testi temiz bitirmek için bekle.
      await frames(tester, 8);
    });

    testWidgets('fırlatma: bırakınca ürün bir süre daha döner, sonra yayla ana poza oturur (atlama yok)', (tester) async {
      final s = await mount(tester, const Size(1440, 900));
      final yaws = <double>[];
      await tester.fling(product(), const Offset(-250, 0), 2500);
      final atRelease = s.debugPose.yaw;
      yaws.add(atRelease);
      expect(atRelease, greaterThan(kCameraHomeYaw + 0.5));
      var coastSeen = false;
      var returnSeen = false;
      var maxStep = 0.0;
      var prev = atRelease;
      for (var i = 0; i < 60 * 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final y = s.debugPose.yaw;
        maxStep = math.max(maxStep, (y - prev).abs());
        prev = y;
        coastSeen |= s.debugPhysics.phase == RotationPhase.coasting;
        returnSeen |= s.debugPhysics.phase == RotationPhase.returning;
      }
      expect(coastSeen, isTrue, reason: 'bırakınca momentum evresi olmalı');
      expect(returnSeen, isTrue, reason: 'sonra yay evresi olmalı');
      expect(maxStep, lessThan(0.25), reason: 'tek karede büyük sıçrama (anında atlama) yok');
      final home = nearestHomeYaw(prev);
      expect((prev - home).abs(), lessThan(0.12), reason: 'ana poza (boşta salınım payı ile) oturdu');
      expect(s.debugPhysics.phase, RotationPhase.rest);
    });

    testWidgets('boşta: yaw ±5° / pitch ±1.5° içinde gerçekten salınır; ışık fazı kayar', (tester) async {
      final s = await mount(tester, const Size(1440, 900));
      expect(s.debugLoopRunning, isTrue);
      var minD = 0.0, maxD = 0.0, minP = 0.0, maxP = 0.0;
      final light0 = s.debugPose.lightPhase;
      for (var i = 0; i < 60 * 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final d = s.debugPose.yaw - kCameraHomeYaw;
        minD = math.min(minD, d);
        maxD = math.max(maxD, d);
        final p = s.debugPose.pitch - kCameraHomePitch;
        minP = math.min(minP, p);
        maxP = math.max(maxP, p);
      }
      const deg = math.pi / 180;
      expect(maxD, inInclusiveRange(2 * deg, 5.3 * deg));
      expect(minD, inInclusiveRange(-5.3 * deg, -2 * deg));
      expect(maxP, inInclusiveRange(0.5 * deg, 1.6 * deg));
      expect(minP, inInclusiveRange(-1.6 * deg, -0.5 * deg));
      expect(s.debugPose.lightPhase, isNot(closeTo(light0, 0.05)));
    });

    testWidgets('hareketi azalt: boşta animasyon yok (kare istenmez, poz değişmez)', (tester) async {
      final s = await mount(tester, const Size(1440, 900), reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 300));
      final pose = s.debugPose.toString();
      expect(s.debugLoopRunning, isFalse);
      await frames(tester, 10);
      expect(s.debugPose.toString(), pose, reason: 'boşta poz hiç değişmemeli');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'boşta planlanmış kare olmamalı');

      // Sürükleyince döner, bırakınca anında ana poza oturur (momentum yok).
      final g = await tester.startGesture(tester.getCenter(product()), kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(-150, 0));
      await tester.pump();
      expect(s.debugPose.yaw, greaterThan(kCameraHomeYaw + 0.4));
      await g.up();
      await tester.pump();
      expect(s.debugPhysics.phase, RotationPhase.rest);
      expect(nearestHomeYaw(s.debugPose.yaw), closeTo(s.debugPose.yaw, 1e-9));
      expect(s.debugLoopRunning, isFalse);
    });

    testWidgets('sahne ekran dışındayken döngü durur, geri gelince başlar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  SizedBox(height: 900, child: CameraScene(reveal: reveal)),
                  const SizedBox(height: 3000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final s = tester.state<CameraSceneState>(find.byType(CameraScene));
      expect(s.debugLoopRunning, isTrue);
      controller.jumpTo(2000);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(s.debugLoopRunning, isFalse, reason: 'ekran dışında FrameLoop durmalı');
      controller.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(s.debugLoopRunning, isTrue);
    });

    testWidgets('reveal 0 iken (açıklığın altında) döngü çalışmaz', (tester) async {
      reveal.value = 0;
      final s = await mount(tester, const Size(1440, 900));
      expect(s.debugLoopRunning, isFalse);
      reveal.value = 0.4;
      await tester.pump();
      expect(s.debugLoopRunning, isTrue);
    });

    testWidgets('klavye: ürün odaklanır; ← yaw\'ı +15°, → -15° döndürür (yayla), sonra ana poza döner', (tester) async {
      final s = await mount(tester, const Size(1440, 900));
      await frames(tester, 1);
      final y0 = s.debugPhysics.yaw;
      // Ürüne tıklamak odağı verir.
      await tester.tapAt(tester.getCenter(product()));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await frames(tester, 1.2);
      const step = 15 * math.pi / 180;
      expect(s.debugPhysics.yaw - y0, closeTo(step, 0.06), reason: '← ürünü sola (yaw +15°) döndürür');
      expect(s.debugHintGone, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await frames(tester, 1.2);
      expect(s.debugPhysics.yaw - y0, closeTo(-step, 0.06), reason: '→ → toplam -15°');
      await frames(tester, 6);
      expect((s.debugPhysics.yaw - nearestHomeYaw(s.debugPhysics.yaw)).abs(), lessThan(0.12), reason: 'bekleme sonrası ana poz');
    });

    testWidgets('odak halkası yalnızca klavye odağında görünür: tıklamada yok, Tab ve ok tuşunda var', (tester) async {
      final s = await mount(tester, const Size(1440, 900));
      expect(s.debugFocusRingVisible, isFalse);
      // Tab: odak ürüne gelir (klavye) → halka görünür.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(s.debugFocusRingVisible, isTrue, reason: 'Tab ile odaklanınca halka görünmeli');
      // Fare tıklaması: halka kaybolur (odak kalır).
      await tester.tapAt(tester.getCenter(product()));
      await tester.pump();
      expect(s.debugFocusRingVisible, isFalse, reason: 'tıklamada halka çizilmemeli');
      // Ok tuşu: klavye kullanımı → halka geri gelir.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(s.debugFocusRingVisible, isTrue);
      await frames(tester, 6);
    });

    /// Bir widget'ın ekrandaki gerçek (FittedBox/Transform ölçeği dahil) kutusu.
    Rect paintedRect(WidgetTester tester, Finder f) => Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));

    for (final dark in [true, false]) {
      for (final size in const [Size(844, 390), Size(864, 304)]) {
        for (final scale in const [1.0, 1.6]) {
          testWidgets('yatay telefon ${size.width.toInt()}x${size.height.toInt()} ${dark ? 'koyu' : 'açık'} yazı x$scale: yazı, ürün ve ipucu üst üste binmez (AN-02/MB-01)', (tester) async {
            final s = await mount(tester, size, brightness: dark ? Brightness.dark : Brightness.light, textScale: scale);
            expect(tester.takeException(), isNull);
            final eyebrow = paintedRect(tester, find.text('KAMERA SİSTEMLERİ'));
            final title = paintedRect(tester, find.text('Her açıdan net görüntü.'));
            final lead = paintedRect(tester, find.textContaining('IP ve analog kamera sistemleri'));
            final hint = paintedRect(tester, find.text('Yatay çevirerek döndürün'));
            final p = tester.getRect(product());
            final visible = Rect.fromCenter(center: p.center, width: p.width * kProductVisibleWidth, height: p.height);
            // Notlar bu kipte çizilmez; yazı ile ürün yan yana durur.
            for (final n in ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı']) {
              expect(find.text(n), findsNothing, reason: n);
            }
            for (final (name, r) in [('etiket', eyebrow), ('başlık', title), ('paragraf', lead), ('ipucu', hint)]) {
              expect(r.top, greaterThanOrEqualTo(CameraSceneLayout.topInset - 0.5), reason: '$name üst çubuğun altında');
              expect(r.bottom, lessThanOrEqualTo(size.height + 0.5), reason: '$name sahne içinde');
            }
            for (final (name, r) in [('etiket', eyebrow), ('başlık', title), ('paragraf', lead)]) {
              final inter = r.intersect(visible);
              expect(inter.width > 0.5 && inter.height > 0.5, isFalse, reason: '$name ürünün siluetine biniyor: $r / $visible');
            }
            expect(hint.overlaps(title) || hint.overlaps(lead) || hint.overlaps(eyebrow), isFalse, reason: 'ipucu metne biniyor');
            expect(hint.top, greaterThanOrEqualTo(p.bottom - 0.5), reason: 'ipucu ürünün altında');
            // Metin satırları birbirinin üstüne de binmez.
            expect(eyebrow.bottom, lessThanOrEqualTo(title.top + 1));
            expect(title.bottom, lessThanOrEqualTo(lead.top + 1));
            expect(s.debugHintGone, isFalse);
          });
        }
      }
    }

    testWidgets('görüntü: yatay telefon iki temada (AN-02/MB-01)', (tester) async {
      for (final dark in [true, false]) {
        for (final size in const [Size(844, 390), Size(864, 304)]) {
          final path = await shot(
            tester,
            testApp(Scaffold(body: SizedBox.expand(child: CameraScene(reveal: reveal))), brightness: dark ? Brightness.dark : Brightness.light),
            size: size,
            name: 'camera_land_${dark ? 'dark' : 'light'}_${size.width.toInt()}x${size.height.toInt()}',
          );
          expect(File(path).existsSync(), isTrue);
        }
      }
    });

    testWidgets('odak ayraçları not etiketlerine ve çizgilerine değmez (CH-08)', (tester) async {
      for (final size in const [Size(1440, 900), Size(1920, 1080), Size(1024, 768)]) {
        final s = await mount(tester, size);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(s.debugFocusRingVisible, isTrue);
        final brackets = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FocusBracketsPainter);
        expect(brackets, findsOneWidget);
        final box = tester.getRect(brackets);
        expect(box, tester.getRect(product()), reason: '$size: ayraçlar ürün kutusuna oturur');
        final arms = [for (final r in FocusBracketsPainter.armRects(box.size)) r.shift(box.topLeft)];
        // Eski halka kutunun tüm kenarını çiziyordu; etiket ve çizgiler o kenarlara biniyordu.
        for (final n in ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı']) {
          final label = paintedRect(tester, find.text(n));
          for (final a in arms) {
            expect(a.overlaps(label), isFalse, reason: '$size: odak ayracı "$n" etiketine biniyor');
          }
        }
        final layout = CameraSceneLayout.compute(size: size, mode: CameraLayoutMode.wide, textHeight: 200, sidePad: 40, aspect: kProductAspect);
        for (final g in layout.noteGeometry) {
          for (final pt in [g.dot, g.elbow, g.end]) {
            for (final a in arms) {
              expect(a.inflate(2).contains(pt) && box.contains(pt), isFalse, reason: '$size: not çizgisi odak ayracına değiyor');
            }
          }
        }
        // Ayraçlar kutunun tamamını çevrelemez: kenar ortaları boştur.
        final f = FocusBracketsPainter.frameFor(box.size).shift(box.topLeft);
        for (final mid in [Offset(f.center.dx, f.top), Offset(f.center.dx, f.bottom), Offset(f.left, f.center.dy), Offset(f.right, f.center.dy)]) {
          expect(arms.any((a) => a.contains(mid)), isFalse, reason: '$size: kenar ortasında çizgi var');
        }
        await frames(tester, 1);
      }
    });

    testWidgets('notlar döndürürken solar, ana poza dönünce geri gelir (CH-09)', (tester) async {
      final s = await mount(tester, const Size(1440, 900));
      double opacityOf(Finder f) =>
          tester.widgetList<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity))).fold(1.0, (a, o) => a * o.opacity);
      final labels = [for (final n in ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı']) find.text(n)];
      for (final l in labels) {
        expect(opacityOf(l), 1);
      }
      expect(s.debugNoteFade, 1);

      // ~135° döndür (sola sürükleme yaw'ı artırır; 1 px = π / ürün genişliği rad).
      final pw = tester.getSize(product()).width;
      final g = await tester.startGesture(tester.getCenter(product()), kind: PointerDeviceKind.mouse);
      await g.moveBy(Offset(-pw * 0.75, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(s.debugPose.yaw - kCameraHomeYaw, closeTo(135 * math.pi / 180, 0.05));
      expect(s.debugNoteFade, 0, reason: 'yan görünüşte notlar silinmeli');
      for (final l in labels) {
        expect(opacityOf(l), 0, reason: 'etiket gövdeye binmesin');
      }
      // Ara açıda kısmen görünür.
      await g.moveBy(Offset(pw * 0.75 - pw * 0.11, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(s.debugNoteFade, inExclusiveRange(0.05, 0.95));
      await g.up();
      await frames(tester, 8);
      expect(s.debugNoteFade, 1, reason: 'ana poza dönünce notlar geri gelir');
      for (final l in labels) {
        expect(opacityOf(l), 1);
      }
    });

    testWidgets('ipucu ilk etkileşimden sonra kaybolur ve bir daha gelmez', (tester) async {
      final s = await mount(tester, const Size(1440, 900));
      double hintOpacity() {
        final ops = tester.widgetList<AnimatedOpacity>(find.ancestor(of: find.text('Sürükleyerek döndürün'), matching: find.byType(AnimatedOpacity)));
        return ops.first.opacity;
      }

      expect(hintOpacity(), 1);
      expect(s.debugHintGone, isFalse);
      await tester.drag(product(), const Offset(-80, 0));
      await frames(tester, 8);
      expect(s.debugHintGone, isTrue);
      expect(hintOpacity(), 0);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      // Ürün ana poza döndükten sonra da yeniden gösterilmez.
      expect(hintOpacity(), 0);
    });

    testWidgets('erişilebilirlik: ürünün anlamsal etiketi var, artır/azalt eylemleri döndürür', (tester) async {
      final handle = tester.ensureSemantics();
      final s = await mount(tester, const Size(1440, 900));
      final label = find.semantics.byLabel('Kamera ürünü. Sürükleyerek veya ok tuşlarıyla döndürülebilir.');
      expect(label, findsOneWidget);
      final y0 = s.debugPhysics.yaw;
      tester.semantics.increase(label);
      await frames(tester, 1.2);
      expect(s.debugPhysics.yaw, lessThan(y0 - 0.15), reason: 'artır = sağa (yaw azalır)');
      handle.dispose();
    });

    for (final dark in [true, false]) {
      testWidgets('tema: zemin ${dark ? 'koyu' : 'açık'} palete uyar, parıltı merkezdedir', (tester) async {
        final key = GlobalKey();
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(RepaintBoundary(key: key, child: scene(brightness: dark ? Brightness.dark : Brightness.light)));
        await tester.pump(const Duration(milliseconds: 300));
        final colors = dark ? AppColors.dark : AppColors.light;
        late ui.Image image;
        late ByteData data;
        await tester.runAsync(() async {
          final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          image = await b.toImage();
          data = (await image.toByteData())!;
        });
        Color px(int x, int y) {
          final i = (y * image.width + x) * 4;
          return Color.fromARGB(255, data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
        }

        final corner = px(4, 4);
        // Köşe: parıltıdan uzak, zemine (stage) çok yakın.
        expect((corner.r - colors.stage.r).abs() * 255, lessThan(14));
        expect((corner.g - colors.stage.g).abs() * 255, lessThan(14));
        expect((corner.b - colors.stage.b).abs() * 255, lessThan(14));
        // Metin okunur: başlık pikselleri zeminle yeterince farklı (ana metin ≥ 7:1 jetonlarda garanti; burada render doğrulaması).
        final title = tester.getRect(find.text('Her açıdan net görüntü.'));
        var minLum = 1.0, maxLum = 0.0;
        for (var y = title.top.toInt(); y < title.bottom.toInt(); y += 2) {
          for (var x = title.left.toInt(); x < title.right.toInt(); x += 2) {
            final l = px(x, y).computeLuminance();
            minLum = math.min(minLum, l);
            maxLum = math.max(maxLum, l);
          }
        }
        expect(maxLum - minLum, greaterThan(0.5), reason: 'başlık zeminden net ayrışmalı');
        // Açık temada merkez, köşeden belirgin biçimde parlak (stüdyo vurgusu); koyuda çok az parlak.
        final layoutCenter = CameraSceneLayout.compute(
          size: const Size(1440, 900),
          mode: CameraLayoutMode.wide,
          textHeight: 200,
          sidePad: 40,
          aspect: kProductAspect,
        ).glowCenter;
        final centerBg = px(layoutCenter.dx.toInt(), 40); // üst kenar, merkez hizasında (ürün dışında)
        if (dark) {
          expect(centerBg.computeLuminance() - corner.computeLuminance(), lessThan(0.05));
        } else {
          expect(centerBg.computeLuminance(), greaterThan(corner.computeLuminance()));
        }
      });
    }

    testWidgets('görüntüler: iki tema x iki boyut x reveal 0/0.5/1 + etkileşim sonrası', (tester) async {
      final paths = <String>[];
      for (final dark in [true, false]) {
        for (final size in const [Size(1440, 900), Size(390, 844)]) {
          for (final r in [0.0, 0.5, 1.0]) {
            final rv = ValueNotifier<double>(r);
            addTearDown(rv.dispose);
            final key = GlobalKey();
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: testApp(
                  Scaffold(body: SizedBox.expand(child: CameraScene(reveal: rv))),
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            final name = 'camera_${dark ? 'dark' : 'light'}_${size.width.toInt()}_r${(r * 100).round()}';
            paths.add(await captureBoundary(tester, key, name: name));
            if (r == 1.0) {
              // Etkileşim: ürünü ~110° çevirip sürüklerken görüntü al.
              final finder = find.descendant(of: find.byType(CameraScene), matching: find.byType(GestureDetector)).first;
              final g = await tester.startGesture(tester.getCenter(finder), kind: PointerDeviceKind.mouse);
              await g.moveBy(Offset(-size.width * 0.18, 0));
              await tester.pump(const Duration(milliseconds: 100));
              paths.add(await captureBoundary(tester, key, name: '${name}_drag'));
              await g.up();
              await tester.pump(const Duration(milliseconds: 100));
              paths.add(await captureBoundary(tester, key, name: '${name}_coast'));
              for (var i = 0; i < 60 * 6; i++) {
                await tester.pump(const Duration(milliseconds: 16));
              }
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
      tester.view.reset();
      expect(paths, hasLength(2 * 2 * 5));
    });
  });
}
