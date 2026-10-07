import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../theme.dart';
import 'ad_timeline.dart';
import 'fx_kit.dart';

/// Telefonun ölçüleri ve ekran yerleşimi (telefonun kendi 176x360 birim uzayında).
abstract final class PhoneMetrics {
  static const w = 176.0;
  static const h = 360.0;
  static const bodyRadius = 30.0;
  static const bezel = 6.0;
  static const button = Offset(88, 214);
  static const buttonRadius = 56.0;

  static final body = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, w, h), const Radius.circular(bodyRadius));
  static final screen = RRect.fromRectAndRadius(
    const Rect.fromLTWH(bezel, bezel, w - 2 * bezel, h - 2 * bezel),
    const Radius.circular(bodyRadius - bezel + 1),
  );
}

/// Telefonun malzeme renkleri ve ekranındaki AHBU uygulamasının kendi (koyu) arayüzü. Telefon ürünün kendi
/// yüzeyi olduğundan bu renkler iki temada da aynıdır (docs/THEMING.md, "ortam ve malzeme ayrımı").
abstract final class PhoneUi {
  // Gövde ve ekran camı.
  static const bodyLight = Color(0xFF262C36);
  static const bodyDark = Color(0xFF0C0F14);
  static const bodyEdge = [Color(0x66FFFFFF), Color(0x14FFFFFF), Color(0x33FFFFFF)];
  static const sideKey = Color(0xFF2B323D);
  static const glassTop = Color(0xFF0B0E13);
  static const glassBottom = Color(0xFF07090D);
  static const notch = Color(0xFF000000);

  // Uygulama arayüzü.
  static const text = Color(0xFFF3F5F8);
  static const textDim = Color(0xFFA3ACB9);
  static const surface = Color(0xFF11151B);
  static const surfaceHi = Color(0xFF181D25);
  static const line = Color(0x1AFFFFFF);
  static const accent = Color(0xFF58D6CB);
  static const ok = Color(0xFF34D399);
  static const buttonLight = Color(0xFF232B37);
  static const buttonDark = Color(0xFF11151B);
  static const homeBar = Color(0x38FFFFFF);
  static const white = Color(0xFFFFFFFF);

  // Parmak noktası (ışıklı bir imleç).
  static const finger = Color(0xFFEBF2FF);
}

/// Telefon gövdesi: ince çerçeveli koyu cihaz ve yumuşak gölge. Durağan; bir kez boyanır.
/// Gölge ortamdır ve temaya uyar ([AppColors.shadow]); cihazın kendisi uymaz.
class PhoneBodyPainter extends CustomPainter {
  const PhoneBodyPainter({required this.c});

  final AppColors c;

  // Gölge: geniş yumuşak bir leke ve gövdeye yapışık sıkı bir leke. Bu katman durağandır (bir kez boyanıp
  // önbelleğe alınır), bu yüzden bulanıklık karede maliyet getirmez. Çarpanlar (koyu, açık) tema gölge alfasınadır.
  static const _wideSigma = 13.0;
  static const _wideDrop = 15.0;
  static const _wideGain = (0.75, 1.7);
  static const _tightSigma = 3.5;
  static const _tightDrop = 4.0;
  static const _tightGain = (0.45, 1.5);

  // Gövde ve çerçeve.
  static const _edgeWidth = 1.4;
  static const _edgeInset = 0.7;
  static const _edgeStops = [0.0, 0.55, 1.0];
  static const _keyRadius = Radius.circular(1.2);
  static const _keys = [
    Rect.fromLTWH(PhoneMetrics.w - 1.2, 96, 2.6, 38), // sağ: güç
    Rect.fromLTWH(-1.4, 80, 2.6, 22), // sol: ses +
    Rect.fromLTWH(-1.4, 110, 2.6, 22), // sol: ses −
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / PhoneMetrics.w);
    final body = PhoneMetrics.body;
    const far = Offset(PhoneMetrics.w, PhoneMetrics.h);

    _shadow(canvas, body, _wideSigma, _wideDrop, c.pick(_wideGain));
    _shadow(canvas, body, _tightSigma, _tightDrop, c.pick(_tightGain));

    canvas.drawRRect(body, Paint()..shader = ui.Gradient.linear(Offset.zero, far, const [PhoneUi.bodyLight, PhoneUi.bodyDark]));
    // Çerçevenin ince metalik kenarı: sol-üstte parlak, sağ-altta sönük.
    canvas.drawRRect(
      body.deflate(_edgeInset),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _edgeWidth
        ..shader = ui.Gradient.linear(Offset.zero, far, PhoneUi.bodyEdge, _edgeStops),
    );
    final key = Paint()..color = PhoneUi.sideKey;
    for (final r in _keys) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, _keyRadius), key);
    }

    // Ekran camı
    canvas.drawRRect(
      PhoneMetrics.screen,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, PhoneMetrics.bezel),
          const Offset(0, PhoneMetrics.h - PhoneMetrics.bezel),
          const [PhoneUi.glassTop, PhoneUi.glassBottom],
        ),
    );
    canvas.restore();
  }

  void _shadow(Canvas canvas, RRect body, double sigma, double drop, double gain) {
    canvas.drawRRect(
      body.shift(Offset(0, drop)),
      Paint()
        ..color = c.shadow.withValues(alpha: (c.shadow.a * gain).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
  }

  @override
  bool shouldRepaint(PhoneBodyPainter old) => old.c != c;
}

/// Telefon ekranındaki AHBU uygulaması: "Ana Giriş" kartı, "KAPIYI AÇ" düğmesi, gönderiliyor ve
/// "Kapı açıldı" durumları; ayrıca parmak noktası ve dokunma dalgası. Her şey [AdState]'ten çizilir.
/// Ekran ürünün yüzeyidir: renkler [PhoneUi]'dan gelir ve temadan etkilenmez.
class PhoneScreenPainter extends CustomPainter {
  PhoneScreenPainter({required this.clock, required this.title}) : super(repaint: clock);

  final AdClock clock;

  /// Uygulama başlığı (YER TUTUCU: ürün adı kesinleşince değişir).
  final String title;

  final Paint _p = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static final _accentGlow = GlowSprite(PhoneUi.accent);
  static final _okGlow = GlowSprite(PhoneUi.ok);

  // Üst bölüm: çentik ve uygulama başlığı.
  static const _notch = Rect.fromLTWH(63, 14, 50, 14);
  static const _notchRadius = Radius.circular(7);
  static const _titleCenter = Offset(90.5, 49);
  static const _homeBar = Rect.fromLTWH(63, 342, 50, 4);
  static const _homeBarRadius = Radius.circular(2);

  // "Ana Giriş" kartı: kart, kapı simgesi, ad ve durum satırı.
  static const _cardRect = Rect.fromLTWH(16, 66, 144, 54);
  static const _cardRadius = Radius.circular(14);
  static const _iconTile = Rect.fromLTWH(26, 79, 28, 28);
  static const _iconTileRadius = Radius.circular(9);
  static const _doorGlyph = Rect.fromLTWH(34, 85.5, 12, 16);
  static const _doorKnob = Offset(43, 94);
  static const _nameAt = Offset(63, 80);
  static const _statusDot = Offset(66, 102.5);
  static const _statusAt = Offset(74, 96.5);

  // Düğme.
  static const _c = PhoneMetrics.button;
  static const _r = PhoneMetrics.buttonRadius;
  static const _ringGap = 8.0; // dış ince halka ve dönen yay: düğme yarıçapının dışında
  static const _glowReach = 1.75;
  static const _pressDepth = 0.055; // basıldığında küçülme oranı
  static const _labelOffset = Offset(0, 14);
  static const _lockOffset = Offset(0, -14);

  /// "Gönderiliyor…" yayının dönüş hızı (radyan/sn) ve uzunluğu.
  static const _spinRate = 4.6;
  static const _spinSweep = 1.15;

  // Sonuç yazıları.
  static const _resultTitleAt = Offset(88, 292);
  static const _resultSubAt = Offset(88, 312);

  // Parmak noktası, düğme merkezine göre başlangıç ve varış konumu; dokunma dalgası.
  static const _fingerFrom = Offset(46, 118);
  static const _fingerTo = Offset(4, 6);
  static const _fingerRadius = 13.0;
  static const _fingerPressShrink = 2.2;
  static const _rippleStart = 14.0;
  static const _rippleGrowth = 52.0;

  static const _hidden = 0.002;
  static const _labelMin = 0.01;
  static const _stateMin = 0.01;

  static final _buttonFill = ui.Gradient.radial(
    _c + const Offset(-14, -20),
    _r * 1.55,
    const [PhoneUi.buttonLight, PhoneUi.buttonDark],
  );

  static final Path _checkPath = Path()
    ..moveTo(_c.dx - 15, _c.dy + 1)
    ..lineTo(_c.dx - 4.5, _c.dy + 11)
    ..lineTo(_c.dx + 16, _c.dy - 11);

  @override
  void paint(Canvas canvas, Size size) {
    final st = clock.value;
    if (st.phoneIn <= _hidden) return;
    canvas.save();
    canvas.scale(size.width / PhoneMetrics.w);

    canvas.save();
    canvas.clipRRect(PhoneMetrics.screen);
    _header(canvas);
    _card(canvas);
    _button(canvas, st);
    _result(canvas, st);
    _fillRRect(canvas, RRect.fromRectAndRadius(_homeBar, _homeBarRadius), PhoneUi.homeBar);
    canvas.restore();

    _finger(canvas, st);
    canvas.restore();
  }

  void _fillRRect(Canvas canvas, RRect rr, Color color) {
    _p
      ..shader = null
      ..color = color;
    canvas.drawRRect(rr, _p);
  }

  void _header(Canvas canvas) {
    _fillRRect(canvas, RRect.fromRectAndRadius(_notch, _notchRadius), PhoneUi.notch);
    final t = adTextCache.get(title, size: 13, weight: 750, color: PhoneUi.text, spacing: 5);
    TextCache.paintCentered(canvas, t, _titleCenter);
  }

  void _card(Canvas canvas) {
    final rr = RRect.fromRectAndRadius(_cardRect, _cardRadius);
    _fillRRect(canvas, rr, PhoneUi.surface);
    _stroke
      ..strokeWidth = 1
      ..color = PhoneUi.line;
    canvas.drawRRect(rr.deflate(0.5), _stroke);

    // Kapı simgesi: ince çizgili küçük kapı
    _fillRRect(canvas, RRect.fromRectAndRadius(_iconTile, _iconTileRadius), PhoneUi.surfaceHi);
    _stroke
      ..strokeWidth = 1.3
      ..color = PhoneUi.textDim;
    canvas.drawRRect(RRect.fromRectAndRadius(_doorGlyph, const Radius.circular(2)), _stroke);
    _p.color = PhoneUi.textDim;
    canvas.drawCircle(_doorKnob, 1.1, _p);

    TextCache.paintAt(canvas, adTextCache.get('Ana Giriş', size: 12.5, weight: 650, color: PhoneUi.text), _nameAt);
    _p.color = PhoneUi.ok;
    canvas.drawCircle(_statusDot, 3, _p);
    TextCache.paintAt(canvas, adTextCache.get('Çevrimiçi', size: 10.5, weight: 550, color: PhoneUi.textDim), _statusAt);
  }

  void _button(Canvas canvas, AdState st) {
    final press = st.buttonState;
    final sending = st.sending;
    final success = st.success;
    final ringColor = Color.lerp(PhoneUi.accent, PhoneUi.ok, success)!;

    // Düğmenin çevresindeki çok yumuşak ışık
    _accentGlow.draw(canvas, _c, _r * _glowReach, 0.10 * (1 - success) + 0.04 * sending, mode: BlendMode.plus);
    if (success > _stateMin) _okGlow.draw(canvas, _c, _r * _glowReach, 0.13 * success, mode: BlendMode.plus);

    canvas.save();
    canvas.translate(_c.dx, _c.dy);
    canvas.scale(1 - _pressDepth * press);
    canvas.translate(-_c.dx, -_c.dy);

    // Dış ince halka
    _stroke
      ..strokeWidth = 0.8
      ..color = ringColor.withValues(alpha: 0.14 + 0.1 * sending);
    canvas.drawCircle(_c, _r + _ringGap, _stroke);

    // Gövde
    _p
      ..shader = _buttonFill
      ..color = PhoneUi.white;
    canvas.drawCircle(_c, _r, _p);
    _p.shader = null;
    if (press > _stateMin) {
      _p.color = Color.fromRGBO(255, 255, 255, 0.05 * press);
      canvas.drawCircle(_c, _r, _p);
    }
    if (success > _stateMin) {
      _p.color = PhoneUi.ok.withValues(alpha: 0.10 * success);
      canvas.drawCircle(_c, _r, _p);
    }

    _stroke
      ..strokeWidth = 1.4
      ..color = ringColor.withValues(alpha: 0.55 + 0.35 * math.max(sending, success));
    canvas.drawCircle(_c, _r, _stroke);

    // Gönderilirken halkanın çevresinde dönen kısa yay
    if (sending > _stateMin) {
      _stroke
        ..strokeWidth = 2
        ..color = PhoneUi.accent.withValues(alpha: 0.9 * sending * (1 - success));
      canvas.drawArc(Rect.fromCircle(center: _c, radius: _r + _ringGap), clock.time * _spinRate, _spinSweep, false, _stroke);
    }

    // Etiketler: zaman çizelgesi bunları art arda açıp kapatır, hiçbir an iki etiket üst üste görünmez.
    final idle = st.idle;
    if (idle > _labelMin) {
      _lock(canvas, idle);
      final t = adTextCache.get('KAPIYI AÇ', size: 12, weight: 700, color: PhoneUi.text, spacing: 1.4);
      TextCache.paintCentered(canvas, t, _c + _labelOffset, alpha: idle);
    }
    if (sending > _labelMin) {
      final t = adTextCache.get('Gönderiliyor…', size: 11.5, weight: 600, color: PhoneUi.text, spacing: 0.2);
      TextCache.paintCentered(canvas, t, _c, alpha: sending);
    }

    // ✓
    if (success > _stateMin && st.check > _hidden) {
      _stroke
        ..strokeWidth = 3.4
        ..color = PhoneUi.ok.withValues(alpha: success);
      if (st.check >= 0.999) {
        canvas.drawPath(_checkPath, _stroke);
      } else {
        for (final m in _checkPath.computeMetrics()) {
          canvas.drawPath(m.extractPath(0, m.length * st.check), _stroke);
        }
      }
    }
    canvas.restore();
  }

  /// Etiketin üstündeki küçük kilit simgesi.
  void _lock(Canvas canvas, double alpha) {
    final center = _c + _lockOffset;
    _stroke
      ..strokeWidth = 1.5
      ..color = PhoneUi.textDim.withValues(alpha: alpha);
    final body = Rect.fromCenter(center: center + const Offset(0, 3), width: 14, height: 10);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(2.5)), _stroke);
    final shackle = Rect.fromCenter(center: center + const Offset(0, -2), width: 8, height: 10);
    canvas.drawArc(shackle, math.pi, math.pi, false, _stroke);
  }

  void _result(Canvas canvas, AdState st) {
    if (st.success <= _stateMin) return;
    final a = adTextCache.get('Kapı açıldı', size: 15, weight: 700, color: PhoneUi.ok);
    TextCache.paintCentered(canvas, a, _resultTitleAt, alpha: st.success);
    final b = adTextCache.get('Ana Giriş', size: 11, weight: 550, color: PhoneUi.textDim);
    TextCache.paintCentered(canvas, b, _resultSubAt, alpha: st.success);
  }

  /// Parmak/imleç noktası ve dokunma dalgası.
  void _finger(Canvas canvas, AdState st) {
    final ring = st.tapRing;
    if (ring > 0 && ring < 1) {
      _stroke
        ..strokeWidth = 2.2 * (1 - ring) + 0.5
        ..color = PhoneUi.accent.withValues(alpha: 0.55 * (1 - ring) * (1 - ring));
      canvas.drawCircle(_c + _fingerTo, _rippleStart + _rippleGrowth * ring, _stroke);
    }
    final tap = st.tap;
    if (tap <= _hidden) return;
    final pos = Offset.lerp(_c + _fingerFrom, _c + _fingerTo, tap)!;
    final a = (tap * 3).clamp(0.0, 1.0);
    final radius = _fingerRadius - _fingerPressShrink * st.buttonState;
    GlowSprite.coolWhite.draw(canvas, pos, radius * 2.4, 0.16 * a, mode: BlendMode.plus);
    _p
      ..shader = null
      ..color = PhoneUi.finger.withValues(alpha: 0.20 * a);
    canvas.drawCircle(pos, radius, _p);
    _stroke
      ..strokeWidth = 1.2
      ..color = PhoneUi.finger.withValues(alpha: 0.6 * a);
    canvas.drawCircle(pos, radius, _stroke);
  }

  @override
  bool shouldRepaint(PhoneScreenPainter old) => old.title != title || old.clock != clock;
}
