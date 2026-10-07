import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../theme.dart';
import 'ad_timeline.dart';
import 'fx_kit.dart';
import 'stage_geometry.dart';

/// Telefondan kutudaki LED'e giden ışıklı sinyal darbeleri: Bézier eğri boyunca 4 kuyruklu nokta.
/// Yalnızca sinyal penceresinde (3.1–4.5 sn) çizer; diğer zamanlarda boştur.
///
/// Darbenin rengi temanın vurgusudur ([AppColors.accent]). Koyu zeminde parıltı toplanarak (additive) çizilir ve
/// çekirdek neredeyse beyazdır; açık zeminde ikisi de beyaza doyup kaybolacağından parıltı normal alfa ile, çekirdek
/// ise vurgu renginde çizilir.
class SignalPainter extends CustomPainter {
  SignalPainter({required this.geo, required this.clock, required this.c})
      : _glow = GlowSprite(c.accent),
        super(repaint: clock);

  final StageGeometry geo;
  final AdClock clock;
  final AppColors c;

  final GlowSprite _glow;

  static const _pulses = 4;
  static const _gap = 0.11; // darbeler arası eğri payı
  static const _tail = 11; // kuyruk örnek sayısı
  static const _tailStep = 0.013;
  static const _edgeFade = 0.07; // darbenin uçlarda belirip kaybolduğu eğri payı

  // Temaya bağlı ayarlar (koyu, açık).
  static const _guideAlpha = (0.10, 0.22);
  static const _tailAlpha = (0.5, 0.85);
  static const _tailRadius = 1.0;
  static const _tailGrowth = 2.4;
  static const _glowRadius = 20.0;
  static const _glowAlpha = (0.6, 0.6);
  static const _headRadius = (2.6, 3.3);
  static const _headAlpha = 0.95;
  static const _coreRadius = 1.3; // açık zeminde başın beyaz çekirdeği

  final Paint _dot = Paint()..isAntiAlias = true;
  final Paint _guide = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = true;
  final Path _path = Path();

  static Offset _bezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final st = clock.value;
    final p = st.signalProgress;
    if (p <= 0 || p >= 1) return;

    canvas.save();
    canvas.scale(size.width / geo.design.width);

    final p0 = geo.signalStart;
    final p1 = geo.signalC1;
    final p2 = geo.signalC2;
    final p3 = geo.led + geo.boxOffset(st);

    // Eğrinin kendisi neredeyse görünmez bir kılavuz çizgidir; darbelerin yolunu sezdirir.
    final vis = math.sin(math.pi * p);
    _path
      ..reset()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    _guide.color = c.accent.withValues(alpha: c.pick(_guideAlpha) * vis);
    canvas.drawPath(_path, _guide);

    for (var i = 0; i < _pulses; i++) {
      final head = p * (1 + (_pulses - 1) * _gap) - i * _gap;
      if (head <= 0 || head >= 1) continue;
      // Uçlarda yumuşakça belirip kaybolur.
      final env = math.min(1.0, math.min(head / _edgeFade, (1 - head) / _edgeFade));
      _pulse(canvas, p0, p1, p2, p3, head, env);
    }
    canvas.restore();
  }

  void _pulse(Canvas canvas, Offset p0, Offset p1, Offset p2, Offset p3, double head, double env) {
    // Kuyruk: başa yaklaştıkça büyüyen ve koyulaşan noktalar.
    for (var k = _tail - 1; k >= 1; k--) {
      final s = head - k * _tailStep;
      if (s <= 0) continue;
      final f = 1 - k / _tail;
      _dot.color = c.accent.withValues(alpha: c.pick(_tailAlpha) * f * f * env);
      canvas.drawCircle(_bezier(p0, p1, p2, p3, s), _tailRadius + _tailGrowth * f, _dot);
    }
    final hp = _bezier(p0, p1, p2, p3, head);
    _glow.draw(canvas, hp, _glowRadius, c.pick(_glowAlpha) * env, mode: c.glowMode);
    _dot.color = c.pick((AdColors.pulseCore, c.accent)).withValues(alpha: _headAlpha * env);
    canvas.drawCircle(hp, c.pick(_headRadius), _dot);
    if (!c.isDark) {
      _dot.color = Color.fromRGBO(255, 255, 255, _headAlpha * env);
      canvas.drawCircle(hp, _coreRadius, _dot);
    }
  }

  @override
  bool shouldRepaint(SignalPainter old) => old.geo != geo || old.c != c || old.clock != clock;
}
