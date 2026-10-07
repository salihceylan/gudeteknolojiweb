import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/camera3d/camera_model.dart';
import 'package:gudeteknolojiweb/camera3d/camera_painter.dart';
import 'package:gudeteknolojiweb/camera3d/camera_pose.dart';

import 'helpers/shot.dart';

/// Painter'ı gerçekten bir görüntüye çizer ve RGBA baytlarını döndürür (arka plan şeffaftır).
Future<Uint8List> raster(WidgetTester tester, CameraProductPainter painter, Size size) async {
  late Uint8List out;
  await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    painter.paint(Canvas(rec), size);
    final pic = rec.endRecording();
    final img = await pic.toImage(size.width.round(), size.height.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    out = Uint8List.fromList(data!.buffer.asUint8List());
    img.dispose();
    pic.dispose();
  });
  return out;
}

class Stats {
  Stats(this.opaque, this.partial, this.bounds, this.anyBounds);

  /// Tam opak (alfa >= 250) piksel sayısı, kısmen saydam (0 < alfa < 250) piksel sayısı.
  final int opaque, partial;

  /// Opak piksellerin ve herhangi bir piksel (gölge dahil) sınırları.
  final Rect bounds, anyBounds;
}

Stats statsOf(Uint8List px, int w, int h) {
  var opaque = 0, partial = 0;
  var x0 = w, y0 = h, x1 = -1, y1 = -1;
  var ax0 = w, ay0 = h, ax1 = -1, ay1 = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final a = px[(y * w + x) * 4 + 3];
      if (a == 0) continue;
      ax0 = math.min(ax0, x);
      ay0 = math.min(ay0, y);
      ax1 = math.max(ax1, x);
      ay1 = math.max(ay1, y);
      if (a >= 250) {
        opaque++;
        x0 = math.min(x0, x);
        y0 = math.min(y0, y);
        x1 = math.max(x1, x);
        y1 = math.max(y1, y);
      } else {
        partial++;
      }
    }
  }
  return Stats(
    opaque,
    partial,
    Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0),
    Rect.fromLTRB(ax0.toDouble(), ay0.toDouble(), ax1 + 1.0, ay1 + 1.0),
  );
}

double deg(double d) => d * math.pi / 180;

void main() {
  // Bu testte metin yok; yine de projenin görsel testlerindeki kurala uyuyoruz.
  setUpAll(loadAppFonts);

  group('CameraPose', () {
    test('set() değer değişirse tek bildirim gönderir, değişmezse göndermez', () {
      final pose = CameraPose();
      var n = 0;
      pose.addListener(() => n++);
      pose.set(yaw: 1.0, pitch: 0.1, lightPhase: 2.0, scale: 0.9);
      expect(n, 1, reason: 'dört alan birden değişse de tek bildirim');
      pose.set(yaw: 1.0, pitch: 0.1);
      expect(n, 1, reason: 'aynı değerler bildirim göndermez');
      pose.set();
      expect(n, 1);
      pose.yaw = 1.5;
      expect(n, 2);
      expect((pose.yaw, pose.pitch, pose.lightPhase, pose.scale), (1.5, 0.1, 2.0, 0.9));
    });

    test('sonlu olmayan değerler yok sayılır (yay hesabındaki NaN çizimi bozamaz)', () {
      final pose = CameraPose(yaw: 0.5);
      var n = 0;
      pose.addListener(() => n++);
      pose.set(yaw: double.nan, pitch: double.infinity, scale: double.negativeInfinity);
      expect(n, 0);
      expect(pose.yaw, 0.5);
      expect(CameraPose(yaw: double.nan).yaw, kCameraHomeYaw);
      expect(CameraPose(scale: double.nan).scale, 1);
    });

    test('kCameraHomeYaw: 3/4 görünüş, objektif ekranın soluna-öne bakar; ana poz eğimi hafif aşağıdan', () {
      expect(kCameraHomeYaw, inInclusiveRange(deg(25), deg(55)));
      expect(kCameraHomePitch, inInclusiveRange(deg(-8), deg(0)));
      expect(CameraPose().yaw, kCameraHomeYaw);
      expect(CameraPose().pitch, kCameraHomePitch);
    });

    test('nearestHomeYaw / reset: çok tur atılmış açı en yakın eşdeğer ana poza döner', () {
      const tau = math.pi * 2;
      expect(nearestHomeYaw(kCameraHomeYaw + 3 * tau + 0.2), closeTo(kCameraHomeYaw + 3 * tau, 1e-9));
      expect(nearestHomeYaw(kCameraHomeYaw - 2 * tau - 0.2), closeTo(kCameraHomeYaw - 2 * tau, 1e-9));
      // yarım turdan fazla uzaktaysa bir sonraki tura yakın olan seçilir
      expect(nearestHomeYaw(kCameraHomeYaw + math.pi + 0.1), closeTo(kCameraHomeYaw + tau, 1e-9));
      final pose = CameraPose(yaw: kCameraHomeYaw + 2 * tau + 0.4, pitch: 0.2, lightPhase: 3, scale: 0.5);
      pose.reset();
      expect(pose.yaw, closeTo(kCameraHomeYaw + 2 * tau, 1e-9));
      expect((pose.pitch, pose.lightPhase, pose.scale), (kCameraHomePitch, 0.0, 1.0));
    });
  });

  group('Model (ağ)', () {
    for (final segs in [18, 36]) {
      test('segs=$segs: ağ tutarlı (indeksler, birim normaller, sarım yönü, komşuluk simetrisi)', () {
        final m = CameraModel.build(segs);
        final mesh = m.mesh;
        expect(mesh.vertexCount, lessThan(60000), reason: 'Uint16 indeks + silüet şeritleri için pay');
        for (final i in mesh.idx) {
          expect(i, lessThan(mesh.vertexCount));
        }
        for (var v = 0; v < mesh.vertexCount; v++) {
          final nx = mesh.nrm[v * 3], ny = mesh.nrm[v * 3 + 1], nz = mesh.nrm[v * 3 + 2];
          final l = math.sqrt(nx * nx + ny * ny + nz * nz);
          expect(l, closeTo(1, 1e-6), reason: 'köşe $v normali birim olmalı');
        }
        var badWinding = 0, twins = 0;
        for (var f = 0; f < mesh.faceCount; f++) {
          final a = mesh.idx[f * 3], b = mesh.idx[f * 3 + 1], c = mesh.idx[f * 3 + 2];
          double p(int v, int k) => mesh.pos[v * 3 + k];
          final ux = p(b, 0) - p(a, 0), uy = p(b, 1) - p(a, 1), uz = p(b, 2) - p(a, 2);
          final vx = p(c, 0) - p(a, 0), vy = p(c, 1) - p(a, 1), vz = p(c, 2) - p(a, 2);
          final gx = uy * vz - uz * vy, gy = uz * vx - ux * vz, gz = ux * vy - uy * vx;
          final sx = mesh.nrm[a * 3] + mesh.nrm[b * 3] + mesh.nrm[c * 3];
          final sy = mesh.nrm[a * 3 + 1] + mesh.nrm[b * 3 + 1] + mesh.nrm[c * 3 + 1];
          final sz = mesh.nrm[a * 3 + 2] + mesh.nrm[b * 3 + 2] + mesh.nrm[c * 3 + 2];
          if (gx * sx + gy * sy + gz * sz <= 0) badWinding++;
          for (var k = 0; k < 3; k++) {
            final t = mesh.twin[f * 3 + k];
            if (t < 0) continue;
            twins++;
            expect(mesh.twin[t], f * 3 + k, reason: 'komşuluk karşılıklı olmalı');
            final tf = t ~/ 3, tk = t % 3;
            final a0 = mesh.idx[f * 3 + k], a1 = mesh.idx[f * 3 + (k + 1) % 3];
            final b0 = mesh.idx[tf * 3 + tk], b1 = mesh.idx[tf * 3 + (tk + 1) % 3];
            for (var d = 0; d < 3; d++) {
              expect(p(a0, d), closeTo(p(b1, d), 1e-4), reason: 'ortak kenar ters yönlü olmalı');
              expect(p(a1, d), closeTo(p(b0, d), 1e-4));
            }
          }
        }
        // 1e-9'dan küçük normal uyuşmazlığı olabilecek tek yer, yarım sarım düzeltmesi sonrası kalan dejenere yüzlerdir
        expect(badWinding, 0, reason: 'sarım yönü köşe normalleriyle uyuşmalı (dış yüz = saat yönünün tersi)');
        expect(twins, greaterThan(mesh.faceCount), reason: 'yüzeylerin çoğu komşuluk bilgisine sahip olmalı');
      });
    }

    test('ürün gövdesi ~3.6 birim uzunlukta, yarıçap ~0.5; üçgen sayısı bütçeli', () {
      final m = CameraModel.build(36);
      expect(kZFront - kZRear, closeTo(3.6, 1e-9));
      var minZ = 1e9, maxZ = -1e9, maxR = 0.0;
      for (var v = 0; v < m.mesh.vertexCount; v++) {
        final x = m.mesh.pos[v * 3], y = m.mesh.pos[v * 3 + 1], z = m.mesh.pos[v * 3 + 2];
        if (y.abs() < 0.55 && y > -0.55 && x.abs() < 0.55) maxR = math.max(maxR, math.sqrt(x * x + y * y));
        minZ = math.min(minZ, z);
        maxZ = math.max(maxZ, z);
      }
      expect(maxR, inInclusiveRange(0.5, 0.7), reason: 'gövde yarıçapı ~0.5, güneşlik ~0.59');
      expect(maxZ - minZ, inInclusiveRange(4.3, 5.0), reason: 'kablo rakoru ve güneşlik dahil toplam uzunluk');
      expect(m.mesh.faceCount, lessThan(3200));
      expect(CameraModel.build(18).mesh.faceCount, lessThan(m.mesh.faceCount * 0.7), reason: 'quality düşünce ağ küçülür');
    });
  });

  group('CameraProductPainter', () {
    testWidgets('tüm açılarda (0–360, adım 15) ve eğimlerde çizim istisna fırlatmaz, ürün her zaman çizilir', (tester) async {
      const size = Size(330, 200);
      for (final pitch in [-12.0, 0.0, 12.0]) {
        for (var yaw = 0; yaw <= 360; yaw += 15) {
          final pose = CameraPose(yaw: deg(yaw.toDouble()), pitch: deg(pitch));
          final s = statsOf(await raster(tester, CameraProductPainter(pose: pose), size), 330, 200);
          expect(s.opaque, greaterThan(2500), reason: 'yaw=$yaw pitch=$pitch: ürün görünmeli');
          expect(s.partial, greaterThan(100), reason: 'yaw=$yaw: silüet yumuşatma ve gölge yarı saydam pikseller üretmeli');
        }
      }
    });

    testWidgets('ürün her açıda kutuya kenar payıyla sığar (yaw tam tur, eğim -8..+12)', (tester) async {
      final size = Size(CameraProductPainter.aspect * 200, 200);
      final w = size.width.round(), h = size.height.round();
      for (final pitch in [-8.0, 0.0, 12.0]) {
        for (var yaw = 0; yaw < 360; yaw += 10) {
          final px = await raster(tester, CameraProductPainter(pose: CameraPose(yaw: deg(yaw.toDouble()), pitch: deg(pitch))), size);
          final s = statsOf(px, w, h);
          expect(s.anyBounds.left, greaterThan(0), reason: 'yaw=$yaw pitch=$pitch: sol kenara taşmamalı');
          expect(s.anyBounds.top, greaterThan(0), reason: 'yaw=$yaw pitch=$pitch: üst kenara taşmamalı');
          expect(s.anyBounds.right, lessThan(w), reason: 'yaw=$yaw pitch=$pitch: sağ kenara taşmamalı');
          expect(s.anyBounds.bottom, lessThan(h), reason: 'yaw=$yaw pitch=$pitch: alt kenara taşmamalı');
        }
      }
    });

    testWidgets('arka plan çizilmez: köşeler şeffaf, ürün merkezde opak', (tester) async {
      const w = 600, h = 364;
      final px = await raster(tester, CameraProductPainter(pose: CameraPose()), const Size(600, 364));
      int alphaAt(int x, int y) => px[(y * w + x) * 4 + 3];
      for (final p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (5, h ~/ 2), (w - 5, h ~/ 2)]) {
        expect(alphaAt(p.$1, p.$2), 0, reason: 'köşe/kenar ${p.$1},${p.$2} şeffaf olmalı');
      }
      final s = statsOf(px, w, h);
      expect(s.bounds.center.dx, closeTo(w / 2, w * 0.12), reason: 'ürün yatayda ortalanır');
      expect(s.opaque / (w * h), greaterThan(0.12));
    });

    testWidgets('küçük (120x80) ve büyük (1400x900) boyutta çizim; ürün boyuta orantılı ölçeklenir', (tester) async {
      final small = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose()), const Size(120, 80)), 120, 80);
      final big = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose()), const Size(1400, 900)), 1400, 900);
      expect(small.opaque, greaterThan(300));
      expect(big.opaque, greaterThan(150000));
      // iki kutu da (en/boy < aspect) genişliğe göre sığdırılır: ürün genişliği kutu genişliğiyle orantılı
      expect(big.bounds.width / small.bounds.width, closeTo(1400 / 120, 1.5));
      expect(big.anyBounds.left, greaterThan(0));
      expect(big.anyBounds.right, lessThan(1400));
    });

    testWidgets('quality 0.5 / 0.75 / 1.0 ve geçersiz değerlerle çizilir; düşük kalite daha az üçgen çizer', (tester) async {
      const size = Size(400, 240);
      final counts = <double, int>{};
      for (final q in [0.5, 0.75, 1.0, 0.0, -3.0, 9.0, double.nan]) {
        final s = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose(), quality: q), size), 400, 240);
        expect(s.opaque, greaterThan(5000), reason: 'quality=$q');
        if (q == 0.5 || q == 1.0) counts[q] = CameraProductPainter.debugLastTriangleCount(q);
      }
      expect(counts[0.5]!, lessThan(counts[1.0]! * 0.75));
      expect(counts[0.5]!, greaterThan(500));
    });

    testWidgets('pose.scale ürünü ölçekler (0.5 → ~1/4 alan), scale<=0 hiçbir şey çizmez ve hata vermez', (tester) async {
      const size = Size(500, 303);
      final full = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose()), size), 500, 303);
      final half = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose(scale: 0.5)), size), 500, 303);
      final ratio = half.opaque / full.opaque;
      expect(ratio, inInclusiveRange(0.18, 0.34));
      final zero = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose(scale: 0)), size), 500, 303);
      expect(zero.opaque, 0);
    });

    testWidgets('silüet yumuşatma: gölgesiz çizimde bile kenarlarda kısmen saydam pikseller var (tırtıksız kenar)', (tester) async {
      // Kenar piksellerinin çoğu tam opak ile tam şeffaf arasında olmalı; tırtıklı kenar yalnızca 0/255 üretir.
      const size = Size(660, 400);
      final s = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose()), size), 660, 400);
      // gölgenin kendisi de yarı saydamdır; bu yüzden gölgesiz çizelim
      final noShadow = statsOf(
        await raster(tester, CameraProductPainter(pose: CameraPose(), shadowColor: const Color(0x00000000)), size),
        660,
        400,
      );
      expect(noShadow.partial, greaterThan(600), reason: 'silüet uzunluğu ~2000 piksel; yumuşatma şeritleri yarı saydam üretir');
      expect(s.partial, greaterThan(noShadow.partial));
    });

    testWidgets('shadowColor yalnızca zemin gölgesini değiştirir; ürün pikselleri (malzeme renkleri) iki temada aynıdır', (tester) async {
      const w = 500, h = 303;
      const size = Size(500, 303);
      final dark = await raster(tester, CameraProductPainter(pose: CameraPose()), size);
      final light = await raster(tester, CameraProductPainter(pose: CameraPose(), shadowColor: const Color(0x33101820)), size);
      final none = await raster(tester, CameraProductPainter(pose: CameraPose(), shadowColor: const Color(0x00000000)), size);
      var shadowDiff = 0, productDiff = 0, shadowPixels = 0;
      for (var i = 0; i < w * h; i++) {
        final a = none[i * 4 + 3];
        if (a >= 250) {
          // ürünün opak olduğu yerde üç görüntü bire bir aynı olmalı
          for (var c = 0; c < 4; c++) {
            if (dark[i * 4 + c] != none[i * 4 + c] || light[i * 4 + c] != none[i * 4 + c]) productDiff++;
          }
        } else if (a == 0) {
          if (dark[i * 4 + 3] > 0) shadowPixels++;
          if (dark[i * 4 + 3] != light[i * 4 + 3]) shadowDiff++;
        }
      }
      expect(productDiff, 0, reason: 'ürün malzemesi temadan bağımsız');
      expect(shadowPixels, greaterThan(3000), reason: 'koyu gölge görünür bir alan kaplar');
      expect(shadowDiff, greaterThan(3000), reason: 'açık/koyu gölge yoğunlukları farklıdır');
      // gölgeyi kapatınca ürünün altındaki zemin tamamen şeffaf kalır
      final s = statsOf(none, w, h);
      expect(s.anyBounds.bottom, lessThanOrEqualTo(s.bounds.bottom + 1));
    });

    testWidgets('rimStrength kenar ışığını değiştirir: 0 → daha koyu, 1 → daha parlak; yalnızca ürün pikselleri değişir', (tester) async {
      const w = 500, h = 303;
      const size = Size(500, 303);
      final none = await raster(tester, CameraProductPainter(pose: CameraPose(), shadowColor: const Color(0x00000000), rimStrength: 0), size);
      final one = await raster(tester, CameraProductPainter(pose: CameraPose(), shadowColor: const Color(0x00000000)), size);
      final strong = await raster(tester, CameraProductPainter(pose: CameraPose(), shadowColor: const Color(0x00000000), rimStrength: 2), size);
      double lum(Uint8List p) {
        var sum = 0.0;
        for (var i = 0; i < w * h; i++) {
          if (p[i * 4 + 3] >= 250) sum += p[i * 4] * 0.3 + p[i * 4 + 1] * 0.59 + p[i * 4 + 2] * 0.11;
        }
        return sum;
      }

      final l0 = lum(none), l1 = lum(one), l2 = lum(strong);
      expect(l1, greaterThan(l0 * 1.003), reason: 'kenar ışığı ürünü hafifçe aydınlatır');
      expect(l2, greaterThan(l1 * 1.003));
      // soğuk kenar ışığı mavi kanalı kırmızıdan fazla artırır
      double blueRed(Uint8List p) {
        var s = 0.0;
        for (var i = 0; i < w * h; i++) {
          if (p[i * 4 + 3] >= 250) s += p[i * 4 + 2] - p[i * 4];
        }
        return s;
      }

      expect(blueRed(strong), greaterThan(blueRed(none)));
      // şekil (maske) aynı kalır
      expect(statsOf(none, w, h).opaque, closeTo(statsOf(strong, w, h).opaque.toDouble(), 30));
    });

    testWidgets('yaw 2π periyodiktir: bir tur fazlası aynı görüntüyü verir', (tester) async {
      const size = Size(400, 242);
      final a = await raster(tester, CameraProductPainter(pose: CameraPose(yaw: 0.9, pitch: 0.1)), size);
      final b = await raster(tester, CameraProductPainter(pose: CameraPose(yaw: 0.9 + 2 * math.pi, pitch: 0.1)), size);
      final c = await raster(tester, CameraProductPainter(pose: CameraPose(yaw: 0.9 - 4 * math.pi, pitch: 0.1)), size);
      for (final other in [b, c]) {
        var diff = 0;
        for (var i = 0; i < a.length; i += 4) {
          if ((a[i] - other[i]).abs() > 6 || (a[i + 3] - other[i + 3]).abs() > 6) diff++;
        }
        expect(diff, lessThan(60), reason: 'yalnızca kayan nokta farkından doğan tek tük piksel');
      }
    });

    testWidgets('yaw 0 ve π farklı görüntüler (önden/arkadan), lens parlaması yalnızca öne bakarken görünür', (tester) async {
      const size = Size(400, 242);
      final front = await raster(tester, CameraProductPainter(pose: CameraPose(yaw: 0, pitch: 0)), size);
      final glintFront = CameraProductPainter.debugGlint(1.0);
      final back = await raster(tester, CameraProductPainter(pose: CameraPose(yaw: math.pi, pitch: 0)), size);
      final glintBack = CameraProductPainter.debugGlint(1.0);
      var diff = 0;
      for (var i = 0; i < front.length; i += 4) {
        if ((front[i] - back[i]).abs() + (front[i + 1] - back[i + 1]).abs() + (front[i + 2] - back[i + 2]).abs() > 60) diff++;
      }
      expect(diff, greaterThan(1500));
      expect(glintBack, 0.0, reason: 'objektif arkada: parlama yok');
      expect(glintFront, greaterThanOrEqualTo(0.0));
      // ana pozda (3/4 görünüş) lens parlaması belirgin
      await raster(tester, CameraProductPainter(pose: CameraPose()), size);
      expect(CameraProductPainter.debugGlint(1.0), greaterThan(0.5));
    });

    testWidgets('derinlik sıralaması (painter algoritması) bir z-tamponu referansıyla her açıda uyuşur', (tester) async {
      // Painter'ın gerçek çıktısı, aynı köşe renklerinden bağımsız olarak kurulan bir z-tamponu çiziminin (her pikselde
      // gerçek derinliğe göre en yakın yüzün Gouraud rengi) "iç" piksellerinde aynı olmalı. Kenar pikselleri (rasterleştirme
      // kuralı ve silüet yumuşatma farkları) ile yarı saydam çıkartmaların (hale, parlama) kapladığı pikseller sayılmaz.
      final cases = <(Size, double, double)>[
        for (final pitch in [-8.0, 0.0, 12.0])
          for (var yaw = 0; yaw < 360; yaw += 15) (const Size(330, 200), yaw.toDouble(), pitch),
        // ana poz büyük boyutta: lens halkası gibi ince yapılar daha çok piksel kaplar
        (const Size(736, 460), kCameraHomeYaw * 180 / math.pi, kCameraHomePitch * 180 / math.pi),
      ];
      var worst = 0.0, worstAt = '', totalInterior = 0, totalBad = 0;
      for (final c in cases) {
        final size = c.$1;
        final w = size.width.round(), h = size.height.round();
        final pose = CameraPose(yaw: deg(c.$2), pitch: deg(c.$3));
        final px = await raster(tester, CameraProductPainter(pose: pose, shadowColor: const Color(0x00000000)), size);
        final fr = CameraProductPainter.debugLastFrame(1.0);
        final mesh = fr.mesh;
        final zbuf = Float64List(w * h)..fillRange(0, w * h, -1e9);
        final ref = Int32List(w * h)..fillRange(0, w * h, -1);
        final skip = Uint8List(w * h);
        for (var f = 0; f < mesh.faceCount; f++) {
          if (fr.visible[f] == 0) continue;
          final ia = mesh.idx[f * 3], ib = mesh.idx[f * 3 + 1], ic = mesh.idx[f * 3 + 2];
          final ca = fr.colors[ia], cb = fr.colors[ib], cc = fr.colors[ic];
          final translucent = ((ca >> 24) & 255) < 250 || ((cb >> 24) & 255) < 250 || ((cc >> 24) & 255) < 250;
          final ax = fr.screen[ia * 2], ay = fr.screen[ia * 2 + 1];
          final bx = fr.screen[ib * 2], by = fr.screen[ib * 2 + 1];
          final cx = fr.screen[ic * 2], cy = fr.screen[ic * 2 + 1];
          final area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
          if (area.abs() < 1e-6) continue;
          final x0 = math.max(0, math.min(ax, math.min(bx, cx)).floor()), x1 = math.min(w - 1, math.max(ax, math.max(bx, cx)).ceil());
          final y0 = math.max(0, math.min(ay, math.min(by, cy)).floor()), y1 = math.min(h - 1, math.max(ay, math.max(by, cy)).ceil());
          for (var y = y0; y <= y1; y++) {
            for (var x = x0; x <= x1; x++) {
              final qx = x + 0.5, qy = y + 0.5;
              final l0 = ((bx - qx) * (cy - qy) - (by - qy) * (cx - qx)) / area;
              final l1 = ((cx - qx) * (ay - qy) - (cy - qy) * (ax - qx)) / area;
              final l2 = 1 - l0 - l1;
              if (l0 < 0 || l1 < 0 || l2 < 0) continue;
              if (translucent) {
                skip[y * w + x] = 1;
                continue;
              }
              final z = l0 * fr.viewZ[ia] + l1 * fr.viewZ[ib] + l2 * fr.viewZ[ic];
              if (z > zbuf[y * w + x]) {
                zbuf[y * w + x] = z;
                int ch(int sh) => (l0 * ((ca >> sh) & 255) + l1 * ((cb >> sh) & 255) + l2 * ((cc >> sh) & 255)).round();
                ref[y * w + x] = (ch(16) << 16) | (ch(8) << 8) | ch(0);
              }
            }
          }
        }
        int gap(int p, int q) => (((p >> 16) & 255) - ((q >> 16) & 255)).abs() + (((p >> 8) & 255) - ((q >> 8) & 255)).abs() + ((p & 255) - (q & 255)).abs();
        var interior = 0, bad = 0;
        for (var y = 1; y < h - 1; y++) {
          for (var x = 1; x < w - 1; x++) {
            final r = ref[y * w + x];
            if (r < 0 || skip[y * w + x] != 0) continue;
            var flat = true;
            for (var dy = -1; dy <= 1 && flat; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                final n = ref[(y + dy) * w + x + dx];
                if (n < 0 || skip[(y + dy) * w + x + dx] != 0 || gap(n, r) > 24) {
                  flat = false;
                  break;
                }
              }
            }
            if (!flat) continue;
            interior++;
            final i = (y * w + x) * 4;
            final d = (px[i] - ((r >> 16) & 255)).abs() + (px[i + 1] - ((r >> 8) & 255)).abs() + (px[i + 2] - (r & 255)).abs();
            if (px[i + 3] < 250 || d > 30) bad++;
          }
        }
        totalInterior += interior;
        totalBad += bad;
        final frac = interior == 0 ? 0.0 : bad / interior;
        if (frac > worst) {
          worst = frac;
          worstAt = 'yaw=${c.$2.toStringAsFixed(1)} pitch=${c.$3.toStringAsFixed(1)} boyut=${size.width.round()}x${size.height.round()}';
        }
      }
      // ignore: avoid_print
      print('DEPTH-ORDER toplam iç piksel=$totalInterior hatalı=$totalBad (${(totalBad * 100 / totalInterior).toStringAsFixed(3)}%), en kötü=${(worst * 100).toStringAsFixed(3)}% ($worstAt)');
      expect(totalBad / totalInterior, lessThan(0.0015), reason: 'ortalama sıralama hatası');
      expect(worst, lessThan(0.01), reason: 'en kötü poz: $worstAt');
    });

    testWidgets('lightPhase yansımayı kaydırır ama silueti değiştirmez', (tester) async {
      const size = Size(400, 242);
      final a = await raster(tester, CameraProductPainter(pose: CameraPose(lightPhase: 0), shadowColor: const Color(0x00000000)), size);
      final b = await raster(tester, CameraProductPainter(pose: CameraPose(lightPhase: math.pi), shadowColor: const Color(0x00000000)), size);
      var maskDiff = 0, colorDiff = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i + 3] >= 250) != (b[i + 3] >= 250)) maskDiff++;
        if (a[i + 3] >= 250 && b[i + 3] >= 250 && (a[i] - b[i]).abs() + (a[i + 1] - b[i + 1]).abs() + (a[i + 2] - b[i + 2]).abs() > 12) colorDiff++;
      }
      expect(maskDiff, lessThan(40), reason: 'yalnızca parlama kuyruğu/yumuşatma farkı');
      expect(colorDiff, greaterThan(300), reason: 'ışık kayınca yüzey renkleri değişir');
    });

    testWidgets('sınır dışı girdiler (NaN rimStrength, aşırı büyük/negatif yaw, pitch) istisna fırlatmaz', (tester) async {
      const size = Size(300, 182);
      final poses = [
        CameraPose(yaw: 1e6, pitch: 3.0),
        CameraPose(yaw: -1e5, pitch: -3.0, lightPhase: 1e4),
        CameraPose(yaw: 0.3, pitch: math.pi / 2),
      ];
      for (final pose in poses) {
        final s = statsOf(await raster(tester, CameraProductPainter(pose: pose, rimStrength: double.nan), size), 300, 182);
        expect(s.opaque, greaterThan(0));
      }
      final s = statsOf(await raster(tester, CameraProductPainter(pose: CameraPose(), rimStrength: -5), size), 300, 182);
      expect(s.opaque, greaterThan(1000));
      // boş boyut: çizim yapılmaz
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        CameraProductPainter(pose: CameraPose()).paint(Canvas(rec), Size.zero);
        rec.endRecording().dispose();
      });
    });

    test('shouldRepaint: pose/quality/shadowColor/rimStrength değişince true', () {
      final pose = CameraPose();
      final base = CameraProductPainter(pose: pose);
      expect(base.shouldRepaint(CameraProductPainter(pose: pose)), isFalse);
      expect(base.shouldRepaint(CameraProductPainter(pose: CameraPose())), isTrue);
      expect(base.shouldRepaint(CameraProductPainter(pose: pose, quality: 0.5)), isTrue);
      expect(base.shouldRepaint(CameraProductPainter(pose: pose, shadowColor: const Color(0x33101820))), isTrue);
      expect(base.shouldRepaint(CameraProductPainter(pose: pose, rimStrength: 0.5)), isTrue);
    });

    testWidgets('pose değişince widget ağacı yeniden kurulmadan yalnızca yeniden boyanır', (tester) async {
      final pose = CameraPose();
      var builds = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          builds++;
          return RepaintBoundary(
            child: CustomPaint(painter: CameraProductPainter(pose: pose), size: const Size(300, 182)),
          );
        }),
      ));
      await tester.pump();
      final render = tester.renderObject<RenderCustomPaint>(find.byType(CustomPaint).last);
      expect(render.debugNeedsPaint, isFalse);
      pose.set(yaw: 2.0);
      expect(render.debugNeedsPaint, isTrue, reason: 'pose dinleniyor: boyama istenir');
      await tester.pump();
      expect(builds, 1, reason: 'widget yeniden kurulmadı');
    });

    test('hata ayıklama sınırları: ürün (gölge hariç) en/boy oranı kutuya (aspect) sığar', () {
      var maxW = 0.0, maxUp = 0.0, maxDown = 0.0;
      for (var yaw = 0; yaw < 360; yaw += 5) {
        for (final pitch in [-8.0, 0.0, 12.0]) {
          final r = CameraProductPainter.debugBounds(1.0, deg(yaw.toDouble()), deg(pitch));
          maxW = math.max(maxW, math.max(-r.left, r.right) * 2);
          maxUp = math.max(maxUp, -r.top);
          maxDown = math.max(maxDown, r.bottom);
        }
      }
      // fit: kutu yüksekliği 3.2 model birimi, genişliği 3.2 * aspect
      expect(maxW, lessThan(3.2 * CameraProductPainter.aspect), reason: 'en geniş açıda (yan görünüş) kutu genişliğine sığar');
      expect(maxUp + maxDown, lessThan(3.2));
    });
  });

  group('Performans', () {
    test('300 karelik paint döngüsü: ortalama kare < 4 ms, çizilen üçgen sayısı bütçede', () {
      for (final q in [1.0, 0.5]) {
        final pose = CameraPose();
        final painter = CameraProductPainter(pose: pose, quality: q);
        const size = Size(900, 545);
        // Isınma: JIT ve ağ kurulumu ölçüme girmesin.
        CameraProductPainter.warmUp(quality: q);
        for (var i = 0; i < 40; i++) {
          pose.set(yaw: i * 0.1);
          final rec = ui.PictureRecorder();
          painter.paint(Canvas(rec), size);
          rec.endRecording().dispose();
        }
        final sw = Stopwatch()..start();
        var maxTris = 0;
        for (var i = 0; i < 300; i++) {
          pose.set(yaw: i * 0.0209, pitch: 0.05 * ((i % 7) - 3) / 3, lightPhase: i * 0.01);
          final rec = ui.PictureRecorder();
          painter.paint(Canvas(rec), size);
          final pic = rec.endRecording();
          maxTris = math.max(maxTris, CameraProductPainter.debugLastTriangleCount(q));
          pic.dispose();
        }
        sw.stop();
        final avgMs = sw.elapsedMicroseconds / 300 / 1000;
        // ignore: avoid_print
        print('PERF quality=$q: ortalama ${avgMs.toStringAsFixed(3)} ms/kare, en çok $maxTris üçgen, ağ ${CameraProductPainter.debugMeshTriangleCount(q)} üçgen');
        expect(avgMs, lessThan(4.0));
        expect(maxTris, lessThan(q == 1.0 ? 2900 : 1900));
      }
    });
  });
}
