import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../theme.dart';
import 'ad_timeline.dart';
import 'fx_kit.dart';
import 'stage_geometry.dart';

/// Sahnenin durağan zemini: ürünün arkasında stüdyo ışığı, zeminde ışık havuzu ve kapının bastığı çizgi.
/// Renkler temadan gelir: koyuda çok yumuşak bir parıltı, açıkta güçlü bir stüdyo vurgusu ([AppColors.stageGlow]);
/// zemin tonu [AppColors.stage], çizgi [AppColors.line]. Kenarlara doğru tamamen söner; sahneyi bölüm
/// zemininden ayıran sert bir sınır oluşmaz.
class StageBackdropPainter extends CustomPainter {
  StageBackdropPainter({required this.geo, required this.c})
      : _spot = GlowSprite(c.stageGlow),
        _pool = GlowSprite(c.stage);

  final StageGeometry geo;
  final AppColors c;

  final GlowSprite _spot;
  final GlowSprite _pool;

  // Stüdyo zemin tonunun ([AppColors.stage]) kapladığı alan: yatay yarıçap sahne genişliğine oranlıdır.
  static const _poolReach = 0.62;
  static const _poolHeight = 250.0;
  static const _poolDrop = 40.0;

  // Ürünün arkasındaki ışığın yarıçap çarpanı ve zemin ışık havuzunun ölçüleri.
  static const _spotReach = 1.15;
  static const _floorReach = 0.52;
  static const _floorHeight = 120.0;
  static const _floorDrop = 70.0;
  static const _floorStrength = 0.7;

  // Kapının bastığı zemin çizgisi: sahnenin bu kadarını kaplar, uçlarda kaybolur.
  static const _horizonInset = 0.04;
  static const _horizonFade = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final d = geo.design;
    canvas.save();
    canvas.scale(size.width / d.width);
    final y = geo.horizonY;

    _pool.drawEllipse(canvas, Offset(d.width / 2, y + _poolDrop), d.width * _poolReach, _poolHeight, 0, 1);
    _spot.draw(canvas, geo.glowCenter, geo.glowRadius * _spotReach, 1);
    _spot.drawEllipse(canvas, Offset(d.width / 2, y + _floorDrop), d.width * _floorReach, _floorHeight, 0, _floorStrength);

    final line = c.line;
    final left = d.width * _horizonInset;
    final right = d.width * (1 - _horizonInset);
    canvas.drawRect(
      Rect.fromLTRB(left, y - 0.5, right, y + 0.5),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(left, y),
          Offset(right, y),
          [line.withValues(alpha: 0), line, line, line.withValues(alpha: 0)],
          const [0, _horizonFade, 1 - _horizonFade, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(StageBackdropPainter old) => old.geo != geo || old.c != c;
}

/// Sade, kodla çizilmiş kapı: çerçeve + kanat. Kanat sol menteşesinden uzağa doğru açılır; perspektif için
/// serbest kenar kısalır ve küçülür. Açıldıkça arkasından soğuk ışık sızar ve zemine yayılır; çerçevenin üstündeki
/// küçük durum ışığı "açıldı" rengine ([AppColors.ok]) döner.
///
/// Kapının malzemesi (grafit çerçeve, kanat, kol) fiziksel olduğundan iki temada aynıdır; ışığın zemine
/// oturması (sızan ışık, gölge) temaya göre ayarlanır.
class DoorPainter extends CustomPainter {
  DoorPainter({required this.geo, required this.clock, required this.c})
      : _shadow = GlowSprite.shadow(c),
        _okGlow = GlowSprite(c.ok),
        _spill = GlowSprite(c.pick((AdColors.coolWhite, _spillLight))),
        super(repaint: clock);

  final StageGeometry geo;
  final AdClock clock;
  final AppColors c;

  final GlowSprite _shadow;
  final GlowSprite _okGlow;
  final GlowSprite _spill;

  // Karede yeniden kullanılan nesneler.
  final Path _leaf = Path();
  final Path _panel = Path();
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  // Malzeme renkleri (tema bağımsız).
  static const _frameTop = Color(0xFF222934);
  static const _frameBottom = Color(0xFF131820);
  static const _frameEdge = Color(0x33FFFFFF);
  static const _openingDark = Color(0xFF05070A);
  static const _leafNear = Color(0xFF232A35);
  static const _leafFar = Color(0xFF12161C);
  static const _leafEdgeNear = Color(0xFF1B212A);
  static const _leafEdgeFar = Color(0xFF0E1217);
  static const _panelLine = Color(0x14FFFFFF);
  static const _handle = Color(0xB39AA4B2);
  static const _white = Color(0xFFFFFFFF);

  /// Açık zeminde sızan ışık saf beyazdır: soğuk beyaz, açık gri zeminde mavimsi bir leke gibi okunur.
  static const _spillLight = _white;

  // Kapı ölçüleri (tasarım birimi).
  static const _frameThickness = 6.0;
  static const _frameRadius = 3.0;
  static const _maxSwing = 1.2; // radyan (~70°): kanat tam açıkken
  static const _perspectiveShrink = 0.17; // serbest kenarın uzaklaşırken kısalma oranı
  static const _panelInsetU = 0.16;
  static const _panelSpans = [(0.07, 0.46), (0.54, 0.93)];
  static const _handleU = 0.86;
  static const _handleV = 0.52;
  static const _handleSize = Size(2.6, 12);
  static const _handleMinScale = 0.3; // kapı açıldıkça kolun kısalma sınırı

  // Durum ışığı: çerçevenin üstünde.
  static const _indicatorRise = 9.0;
  static const _indicatorRadius = 2.2;
  static const _indicatorHalo = 4.5; // halo yarıçapı, ışık yarıçapının katı
  static const _indicatorHaloAlpha = 0.55;

  // Açıklığın içindeki ışık: (üst, alt) alfa. Koyu sahnede ışık zeminden parlak görünür; açık sahnede
  // zeminle yarışabilmesi için neredeyse beyaza çıkar.
  static const _openingAlpha = ((0.34, 0.68), (0.82, 1.0));

  // Sızan ışık: duvardaki hale ve zemindeki iki lekenin alfası (koyu, açık).
  static const _haloAlpha = (0.13, 0.55);
  static const _floorSpillAlpha = (0.16, 0.7);
  static const _floorSpillCoreAlpha = (0.12, 0.8);

  // Sızan ışığın geometrisi.
  static const _haloReach = 0.95; // kapı yüksekliğine oranla halo yarıçapı
  static const _haloDrop = 14.0;
  static const _floorSpillSpan = (width: 0.95, height: 34.0, drop: 24.0);
  static const _floorSpillCoreSpan = (width: 0.6, height: 12.0, drop: 6.0);
  static const _spillShift = -4.0;

  // Zemin gölgesi: kapının tabanında, temaya göre değişmeyen geometri; yoğunluk [AppColors.shadow]'dan gelir.
  static const _shadowSpread = 0.62;
  static const _shadowHeight = 6.0;
  static const _shadowBoost = 2.2;
  static const _shadowMax = 0.6;

  /// Işık, kapı aralandığı anda hızla belirir; sonra yavaşça tam değerine çıkar.
  static const _lightCurve = Curves.easeOut;

  @override
  void paint(Canvas canvas, Size size) {
    final st = clock.value;
    final vis = st.doorIn;
    if (vis <= _hidden) return;
    canvas.save();
    canvas.scale(size.width / geo.design.width);
    final fade = vis < _opaque;
    if (fade) {
      canvas.saveLayer(Offset.zero & geo.design, Paint()..color = Color.fromRGBO(0, 0, 0, vis));
    }

    final f = geo.door;
    final o = f.deflate(_frameThickness);
    final open = st.doorOpen;
    final light = _lightCurve.transform(open);

    _groundShadow(canvas, f);
    _lightSpill(canvas, f, light);

    // Çerçeve
    final frameRect = RRect.fromRectAndRadius(f, const Radius.circular(_frameRadius));
    _fill
      ..shader = ui.Gradient.linear(f.topLeft, f.bottomRight, const [_frameTop, _frameBottom])
      ..color = _white;
    canvas.drawRRect(frameRect, _fill);
    _fill.shader = null;
    _line
      ..strokeWidth = 1
      ..color = _frameEdge;
    canvas.drawRRect(frameRect, _line);

    // Açıklığın içi: kapalıyken koyu, açılınca soğuk ışık (altı daha parlak, zemine yakın).
    canvas.save();
    canvas.clipRect(o);
    _fill
      ..shader = null
      ..color = _openingDark;
    canvas.drawRect(o, _fill);
    if (light > _minLight) {
      final (top, bottom) = c.pick(_openingAlpha);
      _fill
        ..shader = ui.Gradient.linear(
          o.topCenter,
          o.bottomCenter,
          [AdColors.coolWhite.withValues(alpha: top * light), AdColors.coolWhite.withValues(alpha: bottom * light)],
        )
        ..color = _white;
      canvas.drawRect(o, _fill);
      _fill.shader = null;
    }

    _leafPaint(canvas, o, open, light);
    canvas.restore();

    _indicator(canvas, f, light);

    if (fade) canvas.restore();
    canvas.restore();
  }

  /// Kapının zemine bastığı yerdeki yumuşak gölge: nesneyi sahneye oturtur.
  void _groundShadow(Canvas canvas, Rect f) {
    final a = (c.shadow.a * _shadowBoost).clamp(0.0, _shadowMax);
    _shadow.drawEllipse(canvas, Offset(f.center.dx, f.bottom + 1), f.width * _shadowSpread, _shadowHeight, 0, a);
  }

  /// Kapının dışına taşan ışık: duvarda hafif hale ve zemine açılan yumuşak lekeler.
  void _lightSpill(Canvas canvas, Rect f, double light) {
    if (light <= _minLight) return;
    final mode = c.glowMode;
    _spill.draw(canvas, f.center + const Offset(0, _haloDrop), f.height * _haloReach, c.pick(_haloAlpha) * light, mode: mode);

    // Zemine yayılan ışık: kenarı olmayan, yassı ve yumuşak lekeler (sert yamuk yerine).
    final x = f.center.dx + _spillShift;
    final wide = _floorSpillSpan, core = _floorSpillCoreSpan;
    _spill.drawEllipse(canvas, Offset(x, f.bottom + wide.drop), f.width * wide.width, wide.height, 0, c.pick(_floorSpillAlpha) * light, mode: mode);
    _spill.drawEllipse(canvas, Offset(x, f.bottom + core.drop), f.width * core.width, core.height, 0, c.pick(_floorSpillCoreAlpha) * light, mode: mode);
  }

  /// Çerçevenin üstündeki küçük durum ışığı: kapı açılırken "açıldı" rengine ([AppColors.ok]) yanar.
  void _indicator(Canvas canvas, Rect f, double light) {
    if (light <= _minIndicator) return;
    final center = f.topCenter - const Offset(0, _indicatorRise);
    _okGlow.draw(canvas, center, _indicatorRadius * _indicatorHalo, _indicatorHaloAlpha * light, mode: c.glowMode);
    _fill
      ..shader = null
      ..color = c.ok.withValues(alpha: light);
    canvas.drawCircle(center, _indicatorRadius, _fill);
  }

  /// Kanat: sol menteşe sabit, serbest kenar açıldıkça içeri (uzağa) döner. θ = 0 → kapalı, ~70° → açık.
  void _leafPaint(Canvas canvas, Rect o, double open, double light) {
    final theta = open * _maxSwing;
    final cosT = math.cos(theta);
    final sinT = math.sin(theta);

    final hingeX = o.left;
    final freeX = o.left + o.width * cosT;
    final freeH = o.height * (1 - _perspectiveShrink * sinT);
    final cy = o.center.dy;
    final hTop = o.top, hBot = o.bottom;
    final fTop = cy - freeH / 2, fBot = cy + freeH / 2;

    _leaf
      ..reset()
      ..moveTo(hingeX, hTop)
      ..lineTo(freeX, fTop)
      ..lineTo(freeX, fBot)
      ..lineTo(hingeX, hBot)
      ..close();

    // Dönen kanat uzaklaştıkça koyulaşır.
    final base = Color.lerp(_leafNear, _leafFar, sinT)!;
    final edge = Color.lerp(_leafEdgeNear, _leafEdgeFar, sinT)!;
    _fill
      ..shader = ui.Gradient.linear(Offset(hingeX, cy), Offset(math.max(freeX, hingeX + 1), cy), [base, edge])
      ..color = _white;
    canvas.drawPath(_leaf, _fill);
    _fill.shader = null;

    // Panel çizgileri: kanat yüzeyinde (u,v) → perspektifli nokta.
    Offset at(double u, double v) {
      final hy = hTop + (hBot - hTop) * v;
      final fy = fTop + (fBot - fTop) * v;
      return Offset(hingeX + (freeX - hingeX) * u, hy + (fy - hy) * u);
    }

    _line
      ..strokeWidth = 0.9
      ..color = _panelLine;
    for (final (v0, v1) in _panelSpans) {
      final a = at(_panelInsetU, v0), b = at(1 - _panelInsetU, v0), d = at(1 - _panelInsetU, v1), e = at(_panelInsetU, v1);
      _panel
        ..reset()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(d.dx, d.dy)
        ..lineTo(e.dx, e.dy)
        ..close();
      canvas.drawPath(_panel, _line);
    }

    // Kol: serbest kenara yakın küçük çubuk.
    final hp = at(_handleU, _handleV);
    final hs = (0.4 + 0.6 * cosT).clamp(_handleMinScale, 1.0);
    _fill.color = _handle;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: hp, width: _handleSize.width * hs, height: _handleSize.height),
        Radius.circular(_handleSize.width / 2),
      ),
      _fill,
    );

    // Serbest kenarda ışık çizgisi: ışık kanadın kenarından sızar.
    if (light > _minIndicator) {
      _line
        ..strokeWidth = 1.2
        ..color = AdColors.coolWhite.withValues(alpha: _edgeLightAlpha * light);
      canvas.drawLine(Offset(freeX, fTop), Offset(freeX, fBot), _line);
    }
  }

  static const _edgeLightAlpha = 0.65;
  static const _hidden = 0.002;
  static const _opaque = 0.999;
  static const _minLight = 0.002;
  static const _minIndicator = 0.01;

  @override
  bool shouldRepaint(DoorPainter old) => old.geo != geo || old.c != c || old.clock != clock;
}
