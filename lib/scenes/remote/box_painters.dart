import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../theme.dart';
import 'ad_timeline.dart';
import 'box_asset.dart';
import 'fx_kit.dart';
import 'stage_geometry.dart';

/// Kutunun malzeme renk dönüşümü. Görsel açık gri bir CAD çıktısıdır; ürün çekimi gibi görünmesi için grafite
/// doğru koyultulur, hafif soğuk (mavi) eğilim verilir. Malzeme iki temada da grafittir; açık zeminde kutunun
/// silikleşmemesi için dönüşüm biraz daha derin ve kontrastlıdır.
abstract final class BoxGrade {
  static const dark = ColorFilter.matrix(<double>[
    0.60, 0, 0, 0, -13, //
    0, 0.62, 0, 0, -15,
    0, 0, 0.68, 0, -10,
    0, 0, 0, 1, 0,
  ]);

  static const light = ColorFilter.matrix(<double>[
    0.52, 0, 0, 0, -12, //
    0, 0.54, 0, 0, -14,
    0, 0, 0.58, 0, -9,
    0, 0, 0, 1, 0,
  ]);

  static ColorFilter of(AppColors c) => c.pick((dark, light));
}

/// Birim kareye (0..1) oturtulmuş görsel çizimi için ortak yardımcılar. Kutu ve yansıması, tuval kutunun
/// dikdörtgenine ölçeklenmiş hâlde bu kareye çizilir; böylece işaret noktaları ([BoxAsset]) doğrudan kullanılır.
abstract final class _Unit {
  static const rect = Rect.fromLTWH(0, 0, 1, 1);

  static Rect source(ui.Image img) => Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

  /// Görseli [filter] ile (yoksa olduğu gibi) birim kareye çizer.
  static void draw(Canvas canvas, ui.Image img, {ColorFilter? filter, BlendMode? blend, Rect? dst, FilterQuality quality = FilterQuality.medium}) {
    final paint = Paint()..filterQuality = quality;
    if (filter != null) paint.colorFilter = filter;
    if (blend != null) paint.blendMode = blend;
    canvas.drawImageRect(img, source(img), dst ?? rect, paint);
  }
}

/// Kutuyu "ürün çekimi" gibi gösteren durağan katman: CAD görünümünü grafite doğru koyultur, kenarına ince ışık
/// ekler, altına gölge ve zemin yansıması çizer. İçerik hareket etmez; Flutter bu katmanı bir kez boyayıp
/// önbelleğe alır (RepaintBoundary). Gölge ve ışık temaya uyar, kutunun kendisi uymaz.
class ProductBoxPainter extends CustomPainter {
  ProductBoxPainter({required this.geo, required this.image, required this.c})
      : _shadow = GlowSprite.shadow(c),
        _floorLight = GlowSprite(c.stageGlow);

  final StageGeometry geo;
  final ui.Image? image;
  final AppColors c;

  final GlowSprite _shadow;
  final GlowSprite _floorLight;

  // Zemin ışık havuzu: (yatay, dikey) yarıçap kutu genişliğine oranlıdır; (koyu, açık) yoğunluk.
  static const _floorLightReach = (0.62, 0.13);
  static const _floorLightGain = (1.4, 0.55);
  static const _floorLightDrop = 6.0;

  // Geniş yumuşak gölge (yoğunluğu [AppColors.shadow]) ve sıkı temas gölgesi.
  static const _wideShadowReach = (0.74, 0.17);
  static const _wideShadowDrop = 8.0;
  static const _contactShadowReach = 0.54;
  static const _contactShadowHeight = 9.0;
  static const _contactShadowDrop = 3.0;

  /// Temas gölgesi, tema gölgesinin bu kat yoğunudur ve bu üst sınırı aşmaz.
  static const _contactBoost = 3.2;
  static const _contactMax = 0.8;

  // Yansıma: zeminden uzaklaştıkça sönen, gölgeden daha silik bir ayna. (koyu, açık) en yoğun alfa (0..255).
  static const _reflectionFade = 0.17;
  static const _reflectionPeak = (0x40, 0x2E);
  static const _reflectionLayer = Rect.fromLTRB(-0.3, -1.5, 1.5, 2.5);
  static const _reflectionMask = Rect.fromLTRB(-2, -3, 3, 3);

  // Kenar ışığı: yukarı-sola bakan kenarda ince çizgi. Kalınlık piksel cinsindendir.
  static const _rimWidth = 1.2;
  static const _rimAlpha = (0.55, 0.75);

  // Çekim görünümü: üstten hafif ışık, alta ve sağa doğru koyulaşma (ürünün kendi gölgelenmesi).
  static const _topLight = Color(0x10FFFFFF);
  static const _bottomShade = Color(0x59000000);
  static const _sideShade = Color(0x38000000);
  static const _clear = Color(0x00000000);
  static const _bottomShadeStops = [0.0, 0.25, 0.55, 1.0];
  static const _sideShadeStops = [0.0, 0.6, 1.0];
  static const _layerMargin = 0.02;

  static double get _floorSlope =>
      (BoxAsset.floorB.dy - BoxAsset.floorA.dy) / (BoxAsset.floorB.dx - BoxAsset.floorA.dx);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / geo.design.width);
    _paintFloor(canvas);
    final img = image;
    if (img != null) {
      _paintReflection(canvas, img);
      _paintBox(canvas, img);
    }
    canvas.restore();
  }

  void _paintFloor(Canvas canvas) {
    final box = geo.box;
    final m = _floorSlope;
    const cx = 0.5;
    final cy = BoxAsset.floorA.dy + m * (cx - BoxAsset.floorA.dx);
    final center = box.topLeft + Offset(box.width * cx, box.height * cy);
    final angle = math.atan2(m * box.height, box.width);
    final light = _floorLightReach;
    final wide = _wideShadowReach;
    _floorLight.drawEllipse(canvas, center + const Offset(0, _floorLightDrop), box.width * light.$1, box.width * light.$2, angle, c.pick(_floorLightGain));
    _shadow.drawEllipse(canvas, center + const Offset(0, _wideShadowDrop), box.width * wide.$1, box.width * wide.$2, angle, c.shadow.a);
    _shadow.drawEllipse(
      canvas,
      center + const Offset(0, _contactShadowDrop),
      box.width * _contactShadowReach,
      _contactShadowHeight,
      angle,
      (c.shadow.a * _contactBoost).clamp(0.0, _contactMax),
    );
  }

  void _paintReflection(Canvas canvas, ui.Image img) {
    final box = geo.box;
    final m = _floorSlope;
    final k = BoxAsset.floorA.dy - m * BoxAsset.floorA.dx; // zemin doğrusunun y-kesişimi (birim uzayda)

    canvas.save();
    canvas.translate(box.left, box.top);
    canvas.scale(box.width, box.height);

    // Yalnızca zemin doğrusunun üstündeki parçanın yansıması: aşağıdakiler kutunun içine düşmesin.
    canvas.clipPath(Path()
      ..moveTo(-0.5, -0.5)
      ..lineTo(1.5, -0.5)
      ..lineTo(1.5, k + m * 1.5)
      ..lineTo(-0.5, k + m * -0.5)
      ..close());

    // Zemin doğrusuna göre dikey ayna: x' = x, y' = 2(k + m·x) - y.
    canvas.transform(Float64List.fromList(<double>[
      1, 2 * m, 0, 0, //
      0, -1, 0, 0,
      0, 0, 1, 0,
      0, 2 * k, 0, 1,
    ]));

    canvas.saveLayer(_reflectionLayer, Paint());
    _Unit.draw(canvas, img, filter: BoxGrade.of(c));
    // Yansımayı zeminden uzaklaştıkça sönümle; maske zemin doğrusuna paralel (kaymalı) çizilir.
    canvas.save();
    canvas.transform(Float64List.fromList(<double>[
      1, m, 0, 0, //
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]));
    canvas.drawRect(
      _reflectionMask,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, k - _reflectionFade),
          Offset(0, k),
          [const Color(0x00FFFFFF), Color.fromRGBO(255, 255, 255, c.pick(_reflectionPeak) / 255)],
        ),
    );
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  void _paintBox(Canvas canvas, ui.Image img) {
    final box = geo.box;
    final shift = Offset(_rimWidth / box.width, _rimWidth / box.height);

    canvas.save();
    canvas.translate(box.left, box.top);
    canvas.scale(box.width, box.height);

    // Koyu zeminde kenar ışığı: aynı silüeti soğuk beyaza boyayıp bir piksel kadar sol-üste kaydırarak altına
    // çizeriz; yalnızca yukarı-sola bakan kenarlarda ince bir çizgi olarak taşar.
    if (c.isDark) {
      _Unit.draw(
        canvas,
        img,
        dst: _Unit.rect.shift(-shift),
        filter: ColorFilter.mode(AdColors.coolWhite.withValues(alpha: c.pick(_rimAlpha)), BlendMode.srcIn),
      );
    }

    canvas.saveLayer(_Unit.rect.inflate(_layerMargin), Paint());
    _Unit.draw(canvas, img, filter: BoxGrade.of(c));
    // Alta doğru koyulaşma ve sol-üstten gelen çok hafif ışık: düz CAD dolgusunu çekim gibi gösterir.
    canvas.drawRect(
      _Unit.rect,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, 1),
          const [_topLight, _clear, _clear, _bottomShade],
          _bottomShadeStops,
        ),
    );
    canvas.drawRect(
      _Unit.rect,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(1, 0),
          const [_clear, _clear, _sideShade],
          _sideShadeStops,
        ),
    );

    // Açık zeminde kenar ışığı silüetin içinde kalır (dışındaki parlak şerit zeminle karışıp görünmez):
    // silüet eksi kaydırılmış silüet = yukarı-sola bakan ince şerit.
    if (!c.isDark) {
      canvas.saveLayer(_Unit.rect.inflate(_layerMargin), Paint()..color = Color.fromRGBO(255, 255, 255, c.pick(_rimAlpha)));
      _Unit.draw(canvas, img, filter: const ColorFilter.mode(AdColors.coolWhite, BlendMode.srcIn));
      _Unit.draw(canvas, img, dst: _Unit.rect.shift(shift), blend: BlendMode.dstOut);
      canvas.restore();
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(ProductBoxPainter old) => old.image != image || old.geo != geo || old.c != c;
}

/// Kutunun üstündeki hareketli ışıklar: yüzeyde yavaş ışık süpürmesi, LED parıltısı, klik halkası ve
/// varışta Wi-Fi yayları. Kutu katmanının içinde (aynı dönüşümle) durduğundan kutuyla birlikte yükselir.
///
/// LED'in rengi ürünündür (iki temada aynı mavi). Koyu zeminde parıltı toplanarak (additive) çizilir; açık zeminde
/// toplama beyaza doyup kaybolacağından ışık normal alfa, ek bir halka ve daha geniş bir mavi tonla çizilir.
class BoxLightPainter extends CustomPainter {
  BoxLightPainter({required this.geo, required this.image, required this.clock, required this.c}) : super(repaint: clock);

  final StageGeometry geo;
  final ui.Image? image;
  final AdClock clock;
  final AppColors c;

  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  // Işık süpürmesi: eğik bant, en parlak anında bu alfaya çıkar.
  static const _sweepPeak = 0.13;
  static const _sweepAngle = -0.4;
  static const _sweepHalfLength = 0.24; // kutu genişliğine oranla
  static const _sweepStart = -0.3;
  static const _sweepTravel = 1.6;
  static const _sweepClear = Color(0x00DCE9FF);

  // LED parıltısı: geniş bloom, orta parıltı, beyaz çekirdek (yarıçap tasarım birimi, alfa).
  static const _bloomRadius = 62.0;
  static const _bloomAlpha = (0.20, 0.30); // (koyu, açık)
  static const _glowRadius = 22.0;
  static const _glowGrowth = 6.0;
  static const _glowAlpha = 0.85;
  static const _coreRadius = 6.5;
  static const _coreAlpha = 0.7;
  static const _ringRadius = 10.0; // yalnızca açık zeminde
  static const _ringAlpha = 0.6;
  static const _ringWidth = 1.4;

  // Klik halkası.
  static const _clickStart = 7.0;
  static const _clickGrowth = 21.0;
  static const _clickAlpha = 0.7;
  static const _clickWidth = (1.6, 0.6); // (başta, sonda)

  // Wi-Fi yayları.
  static const _arcCount = 3;
  static const _arcDelay = 0.14;
  static const _arcLife = 0.5;
  static const _arcFirstRadius = 12.0;
  static const _arcStep = 8.5;
  static const _arcSpread = 1.2; // radyan
  static const _arcAlpha = 0.85;
  static const _arcWidth = 1.5;
  static const _arcMinAlpha = 0.01;

  static const _hidden = 0.001;
  static const _minGlow = 0.002;

  @override
  void paint(Canvas canvas, Size size) {
    final st = clock.value;
    if (st.boxOpacity <= _hidden) return;
    canvas.save();
    canvas.scale(size.width / geo.design.width);
    _sweep(canvas, st);
    _led(canvas, st);
    _wifi(canvas, st);
    canvas.restore();
  }

  /// Yüzeyde yumuşak, eğik bir ışık bandı gezdirir. Bant, görselin silüetiyle sınırlanır (srcIn).
  void _sweep(Canvas canvas, AdState st) {
    final img = image;
    if (img == null || st.sweep <= 0 || st.sweep >= 1) return;
    final box = geo.box;
    final p = st.sweep;
    final intensity = math.sin(math.pi * p) * _sweepPeak;
    final center = Offset(box.left + (_sweepStart + _sweepTravel * p) * box.width, box.center.dy);
    final half = Offset(math.cos(_sweepAngle), math.sin(_sweepAngle)) * (box.width * _sweepHalfLength);
    canvas.saveLayer(box.inflate(2), Paint());
    canvas.drawImageRect(
      img,
      _Unit.source(img),
      box,
      Paint()
        ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn)
        ..filterQuality = FilterQuality.low,
    );
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.srcIn
        ..shader = ui.Gradient.linear(
          center - half,
          center + half,
          [_sweepClear, AdColors.coolWhite.withValues(alpha: intensity), _sweepClear],
          const [0, 0.5, 1],
        ),
    );
    canvas.restore();
  }

  /// LED: radyal parıltı + bloom (+ açık zeminde halka) + çok kısa klik halkası.
  void _led(Canvas canvas, AdState st) {
    final led = geo.led;
    final g = st.ledGlow;
    final mode = c.glowMode;
    if (g > _minGlow) {
      GlowSprite.ledBlue.draw(canvas, led, _bloomRadius, c.pick(_bloomAlpha) * g, mode: mode);
      GlowSprite.ledBlue.draw(canvas, led, _glowRadius + _glowGrowth * g, _glowAlpha * g, mode: mode);
      GlowSprite.coolWhite.draw(canvas, led, _coreRadius, _coreAlpha * g, mode: BlendMode.plus);
      if (!c.isDark) {
        _stroke
          ..strokeWidth = _ringWidth
          ..color = AdColors.ledBlue.withValues(alpha: _ringAlpha * g);
        canvas.drawCircle(led, _ringRadius + _glowGrowth * g, _stroke);
      }
    }
    final r = st.clickRing;
    if (r > 0 && r < 1) {
      final fade = (1 - r) * (1 - r);
      _stroke
        ..strokeWidth = _clickWidth.$1 + (_clickWidth.$2 - _clickWidth.$1) * r
        ..color = c.pick((AdColors.coolWhite, AdColors.ledBlue)).withValues(alpha: _clickAlpha * fade);
      canvas.drawCircle(led, _clickStart + _clickGrowth * r, _stroke);
    }
  }

  /// Varışta LED'in sinyalin geldiği yöne bakan küçük Wi-Fi yayları (içten dışa belirir, birlikte söner).
  void _wifi(Canvas canvas, AdState st) {
    final p = st.arrive;
    if (p <= 0 || p >= 1) return;
    final led = geo.led;
    final toward = geo.signalC2 - led;
    final base = math.atan2(toward.dy, toward.dx);
    for (var i = 0; i < _arcCount; i++) {
      final local = ((p - i * _arcDelay) / _arcLife).clamp(0.0, 1.0);
      final a = math.sin(math.pi * local);
      if (a <= _arcMinAlpha) continue;
      _stroke
        ..strokeWidth = _arcWidth
        ..color = c.accent.withValues(alpha: _arcAlpha * a);
      canvas.drawArc(
        Rect.fromCircle(center: led, radius: _arcFirstRadius + i * _arcStep),
        base - _arcSpread / 2,
        _arcSpread,
        false,
        _stroke,
      );
    }
  }

  @override
  bool shouldRepaint(BoxLightPainter old) => old.image != image || old.geo != geo || old.c != c || old.clock != clock;
}
