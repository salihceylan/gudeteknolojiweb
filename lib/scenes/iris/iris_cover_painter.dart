import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../core/motion.dart';
import '../../theme.dart';
import 'iris_geometry.dart';
import 'iris_motion.dart';
import 'lens_art.dart';

/// Açılış sahnesinin üst katmanı: tema zemini + lens; iris açıklığı `saveLayer + BlendMode.clear` ile
/// kesilir, altındaki kamera sahnesi buradan görünür.
///
/// Çizim yalnızca [progress] ve [motion] değiştiğinde yenilenir (widget ağacı yeniden kurulmaz).
/// Boyutla değişen her şey ([LensArt] resimleri) önbelleklenir; kare başına nesne üretimi yok sayılır
/// (yollar ve boyalar yeniden kullanılır).
///
/// Tema: zemin, arkadaki parıltı, düşen gölge ve açıklık kenarındaki ışık/gölge [colors]'tan gelir.
/// Lensin kendisi (gövde, cam, yaprak, LED) fiziksel malzeme olduğundan iki temada aynıdır.
class IrisCoverPainter extends CustomPainter {
  IrisCoverPainter({
    required this.progress,
    required this.motion,
    required this.layout,
    required this.art,
    required this.colors,
  })  : _bg = Paint()..color = colors.stage,
        _light = ambientLight(colors),
        super(repaint: Listenable.merge([progress, motion])) {
    // Kenar renkleri tema ışığına göre sürekli karışır (koyu: parlak halka, açık: koyu çizgi + iç gölge).
    _rimSoftColor = colors.line.withValues(alpha: colors.line.a * 0.4 * (1 - _light));
    _shadowStepColor = colors.shadow.withValues(alpha: colors.shadow.a * 0.085 * _light);
    _rimThinColor = Color.lerp(colors.line, colors.lineStrong, _light)!;
  }

  final ValueListenable<double> progress;
  final IrisMotion motion;
  final IrisLayout layout;
  final LensArt art;
  final AppColors colors;

  // Yeniden kullanılan nesneler.
  final _layer = Paint();
  final Paint _bg;

  /// Ortamın aydınlık düzeyi (0 koyu, 1 açık): bkz. [ambientLight].
  final double _light;
  late final Color _rimSoftColor;
  late final Color _shadowStepColor;
  late final Color _rimThinColor;
  final _clear = Paint()
    ..blendMode = BlendMode.clear
    ..isAntiAlias = true;
  final _blade = Paint()..isAntiAlias = true;
  final _seamDark = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final _seamLight = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final _rimSoft = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final _rimThin = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final _led = Paint()..isAntiAlias = true;
  final _poly = Path();
  final _wedge = Path();
  final _seams = Path();
  final _seamsLight = Path();
  final _vx = Float64List(kBladeCount);
  final _vy = Float64List(kBladeCount);
  final _sx = Float64List(kBladeCount);
  final _sy = Float64List(kBladeCount);

  /// Açık temadaki iç gölgenin şerit yarı genişlikleri (piksel); en geniş ~22 px içeri uzanır.
  static final List<double> _shadowReach = List.generate(14, (i) => 22 * math.pow((i + 1) / 14, 1.8).toDouble(), growable: false);

  // Işık yönü (sol üst) ve yaprak renk uçları.
  static const _lightAngle = -2.35;
  static const _bladeDark = Color(0xFF181D24);
  static const _bladeLight = Color(0xFF39414C);

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value.clamp(0.0, 1.0);
    if (p >= IrisChoreography.coverEnd) return;

    final r = layout.radius;
    if (r <= 0 || size.isEmpty) return;
    art.ensure(r, colors);
    final s = layout.scaleAt(p);
    final rect = Offset.zero & size;

    // Mikro hareketler, ilerledikçe kaybolur (geçiş sırasında açıklık titremesin).
    final calm = 1 - remap01(p, 0, 0.35);
    final t = motion.time;
    final breath = 1 + 0.03 * math.sin(2 * math.pi * t / 9) * calm;
    final par = 1 - remap01(p, 0, 0.5);
    final cx = layout.center.dx + motion.dx * par;
    final cy = layout.center.dy + motion.dy * par;

    canvas.save();
    canvas.clipRect(rect);
    canvas.saveLayer(rect, _layer);
    canvas.drawRect(rect, _bg);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(s);

    // Lensin arkasında geniş parıltı (koyuda %5 beyaz, açıkta stüdyo vurgusu) ve zemine düşen gölge.
    final glow = art.glowPaint!..color = Color.fromRGBO(255, 255, 255, 1 - smooth01(remap01(p, 0, 0.55)));
    canvas.drawCircle(Offset.zero, art.glowRadius, glow);
    for (final shadow in art.shadows) {
      canvas.drawCircle(Offset(0, shadow.dy), shadow.radius, shadow.paint);
    }

    // Gövde (önbellekli) + halkada çok yavaş kayan ışık yansıması.
    canvas.drawPicture(art.body);
    canvas.save();
    canvas.rotate(2 * math.pi * t / 28);
    canvas.drawPath(art.sweepRing, art.sweepPaint!);
    canvas.restore();

    // Diyafram.
    final d = r * IrisChoreography.aperture(p) * breath;
    _buildPolygon(d, IrisChoreography.rotation(p));
    _paintBlades(canvas, r, d);

    // Ön cam katmanı (önbellekli).
    canvas.drawPicture(art.glass);

    // LED noktası: saat 1 yönünde, çok yavaş nabız.
    final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t / 6);
    const ledAngle = -math.pi / 2 + math.pi / 6;
    final ledR = r * LensRadii.led;
    final led = Offset(math.cos(ledAngle) * ledR, math.sin(ledAngle) * ledR);
    canvas.drawCircle(led, r * 0.028, _led..color = LensArt.ledColor.withValues(alpha: 0.07 + 0.08 * pulse));
    canvas.drawCircle(led, math.max(1.6, r * 0.0115), _led..color = LensArt.ledColor.withValues(alpha: 0.62 + 0.38 * pulse));

    // Açıklığı kes: altındaki kamera sahnesi görünür.
    canvas.drawPath(_poly, _clear);

    _paintHoleLight(canvas, p, d);
    _paintHoleEdge(canvas, s);

    canvas.restore(); // lens dönüşümü
    canvas.restore(); // saveLayer
    canvas.restore(); // clip
  }

  /// Açıklığın içi (yol zaten kesildi): koyuda dinlenmede çok yumuşak bir ışık seçilir; açıkta lensin içine
  /// bakıyormuş gibi kenarlara doğru hafif koyulaşma olur, deliğin parlak bir patlamaya dönüşmesini önler.
  /// İkisi de kamera sahnesi belirdikçe kaybolur; tema geçişinde ağırlıkları [_light] ile karışır.
  void _paintHoleLight(Canvas canvas, double p, double d) {
    final glowFade = (1 - smooth01(remap01(p, 0, 0.3))) * (1 - _light);
    final shadeFade = (1 - smooth01(remap01(p, 0, 0.75))) * _light;
    if (glowFade <= 0.01 && shadeFade <= 0.01) return;
    canvas.save();
    canvas.clipPath(_poly);
    canvas.scale(d * 1.05);
    if (glowFade > 0.01) canvas.drawCircle(Offset.zero, 1, art.holeLightPaint!..color = Color.fromRGBO(255, 255, 255, glowFade));
    if (shadeFade > 0.01) canvas.drawCircle(Offset.zero, 1, art.holeShadePaint!..color = Color.fromRGBO(255, 255, 255, shadeFade));
    canvas.restore();
  }

  /// Açıklık kenarı (ekranda sabit kalınlıkta). Koyuda ince parlak ışık halkası (beyaz %10); açıkta koyu ince
  /// kenar ve açıklığın içine düşen yumuşak gölge (yapraklar sahnenin üstünde durur), böylece açık zeminde
  /// kenar ışık halesi gibi değil, gerçek bir kenar gibi okunur.
  void _paintHoleEdge(Canvas canvas, double s) {
    if (_light < 0.99) {
      canvas.drawPath(_poly, _rimSoft..strokeWidth = 7 / s..color = _rimSoftColor);
    }
    if (_light > 0.01) {
      // Yumuşak gölge: üst üste binen ince şeritler (kenara yakın sık, uzakta seyrek) yığılınca basamaksız bir
      // sönüm verir. Bulanıklık filtresi kullanmak tam ekran ölçeğinde pahalı olurdu.
      canvas.save();
      canvas.clipPath(_poly);
      _rimSoft.color = _shadowStepColor;
      for (final h in _shadowReach) {
        canvas.drawPath(_poly, _rimSoft..strokeWidth = 2 * h / s);
      }
      canvas.restore();
    }
    canvas.drawPath(_poly, _rimThin..strokeWidth = 1.3 / s..color = _rimThinColor);
  }

  /// Düzgün 9-gen köşeleri ve açıklık yolu.
  void _buildPolygon(double d, double rot) {
    const step = 2 * math.pi / kBladeCount;
    _poly.reset();
    for (var k = 0; k < kBladeCount; k++) {
      final a = rot + k * step;
      _vx[k] = d * math.cos(a);
      _vy[k] = d * math.sin(a);
      if (k == 0) {
        _poly.moveTo(_vx[k], _vy[k]);
      } else {
        _poly.lineTo(_vx[k], _vy[k]);
      }
    }
    _poly.close();
  }

  /// Grafit yapraklar: her köşeden bir önceki kenarın doğrultusunda dışa uzanan teğet dikişler,
  /// iki dikiş arasındaki bölge bir yapraktır (dönel "pinwheel" görünüm).
  void _paintBlades(Canvas canvas, double r, double d) {
    final b = r * LensRadii.blades;
    final hair = math.max(1.0, r * 0.0042);
    _seams.reset();
    _seamsLight.reset();
    for (var k = 0; k < kBladeCount; k++) {
      final prev = (k + kBladeCount - 1) % kBladeCount;
      var ux = _vx[k] - _vx[prev];
      var uy = _vy[k] - _vy[prev];
      final len = math.sqrt(ux * ux + uy * uy);
      ux /= len;
      uy /= len;
      final vu = _vx[k] * ux + _vy[k] * uy;
      final tt = -vu + math.sqrt(math.max(0, vu * vu - d * d + b * b));
      _sx[k] = _vx[k] + tt * ux;
      _sy[k] = _vy[k] + tt * uy;
      _seams
        ..moveTo(_vx[k], _vy[k])
        ..lineTo(_sx[k], _sy[k]);
    }
    final circle = Rect.fromCircle(center: Offset.zero, radius: b);
    for (var k = 0; k < kBladeCount; k++) {
      final next = (k + 1) % kBladeCount;
      final a0 = math.atan2(_sy[next], _sx[next]);
      final a1 = math.atan2(_sy[k], _sx[k]);
      var sweep = (a1 - a0) % (2 * math.pi) - 2 * math.pi;
      if (sweep > 0) sweep -= 2 * math.pi;
      _wedge
        ..reset()
        ..moveTo(_vx[k], _vy[k])
        ..lineTo(_sx[next], _sy[next])
        ..arcTo(circle, a0, sweep, false)
        ..close();
      final mid = a0 + sweep / 2;
      final lit = 0.5 + 0.5 * math.cos(mid - _lightAngle);
      canvas.drawPath(_wedge, _blade..color = Color.lerp(_bladeDark, _bladeLight, lit * lit)!);
    }
    // Dikişler: koyu çizgi + yanında çok soluk ışık kenarı.
    _seamsLight.addPath(_seams, Offset(hair * 0.7, hair * 0.9));
    canvas.drawPath(_seamsLight, _seamLight..strokeWidth = hair..color = const Color(0x12FFFFFF));
    canvas.drawPath(_seams, _seamDark..strokeWidth = hair * 1.2..color = const Color(0xB8000000));
  }

  @override
  bool shouldRepaint(IrisCoverPainter old) =>
      old.layout != layout || old.art != art || old.progress != progress || old.motion != motion || old.colors != colors;
}
