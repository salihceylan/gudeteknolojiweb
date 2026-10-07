import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart';

import '../../theme.dart';

/// Lens gövdesinin yarıçap oranları (R = 1). Çizici ve resim aynı ölçüleri kullanır.
class LensRadii {
  LensRadii._();

  static const grip = 0.925; // tırtıklı bilezik iç sınırı
  static const gripOuter = 0.985;
  static const scaleOuter = 0.915; // diyafram skalası bandı
  static const scaleInner = 0.80;
  static const led = 0.785; // turkuaz LED halka
  static const barrel = 0.77; // iç namlu
  static const bezel = 0.675; // ön cam çerçevesi
  static const blades = 0.665; // yaprakların dış sınırı
}

final double _darkStageLuminance = AppColors.dark.stage.computeLuminance();
final double _lightStageLuminance = AppColors.light.stage.computeLuminance();

/// Ortamın aydınlık düzeyi: 0 = koyu stüdyo, 1 = açık stüdyo. Zemin (`stage`) parlaklığından türetilir; böylece tema
/// geçişinde ([AppColors.lerp]) 0 ile 1 arasında sürekli değişir. `brightness` ise yarı yolda ikili atlar.
double ambientLight(AppColors c) =>
    ((c.stage.computeLuminance() - _darkStageLuminance) / (_lightStageLuminance - _darkStageLuminance)).clamp(0.0, 1.0);

/// Zemine oturan yumuşak bir gölge katmanı: [paint] lens uzayında, merkezi (0, [dy]) olan bir diskte çizilir.
class LensShadow {
  const LensShadow(this.paint, this.dy, this.radius);
  final Paint paint;
  final double dy;
  final double radius;
}

/// Lensin değişmeyen katmanlarını bir kez [Picture] olarak üretip saklar (halka, tırtık, skala, cam).
/// Kare başına yalnızca hareketli parçalar (yansıma, yapraklar, LED noktası, açıklık) çizilir.
/// Hepsi vektördür; lens büyürken keskin kalır.
///
/// MALZEME / ORTAM AYRIMI (docs/THEMING.md §5): lensin kendisi (koyu eloksal gövde, cam, yapraklar, tırtık,
/// skala, LED) fiziksel bir nesnedir ve iki temada AYNI renktedir; bu dosyada sabit durur. Temaya göre değişen
/// yalnızca lensin zemine oturması (arkadaki parıltı, düşen gölge, açıklıktaki ışık/gölge) olup `ensure`'a
/// verilen [AppColors]'tan üretilir.
class LensArt {
  /// LED'in malzeme rengi: iki temada da aynı turkuaz (koyu temadaki vurgu rengiyle aynı değer).
  static const ledColor = Color(0xFF58D6CB);

  double radius = 0;
  Picture? _body;
  Picture? _glass;
  AppColors? _ambientFor;

  /// Işık yansımasının süpürdüğü bilezik (tırtık + skala); even-odd halka.
  final Path sweepRing = Path()..fillType = PathFillType.evenOdd;

  Paint? sweepPaint;

  /// Lensin arkasındaki geniş parıltı (merkezde `stageGlow`), açıklıktaki ışık ve iç gölge, düşen gölgeler.
  Paint? glowPaint;
  double glowRadius = 0;
  Paint? holeLightPaint;
  Paint? holeShadePaint;
  List<LensShadow> shadows = const [];

  Picture get body => _body!;
  Picture get glass => _glass!;

  /// [r] ya da tema renkleri değiştiyse ilgili önbellekleri yeniden üretir. Tema geçişinde renkler her karede
  /// değişir; yalnızca birkaç gradyan yeniden kurulur, [Picture]'lar yeniden kaydedilmez.
  void ensure(double r, AppColors colors) {
    final rebuildBody = _body == null || (r - radius).abs() >= 0.25;
    if (rebuildBody) {
      _disposeBody();
      radius = r;
      _body = _record((c) => _paintBody(c, r));
      _glass = _record((c) => _paintGlass(c, r));
      sweepRing
        ..reset()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * LensRadii.gripOuter))
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: r * LensRadii.scaleInner));
      sweepPaint?.shader?.dispose();
      sweepPaint = Paint()
        ..shader = SweepGradient(
          colors: const [
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x1CFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x0EFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.06, 0.13, 0.22, 0.52, 0.60, 0.68, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    }
    if (rebuildBody || !identical(_ambientFor, colors)) {
      _ambientFor = colors;
      _buildAmbient(r, colors);
    }
  }

  void _buildAmbient(double r, AppColors c) {
    _disposeAmbient();
    // Koyu (0) ile açık (1) stüdyo arasında SÜREKLİ bir değer: tema geçişi animasyonunda renkler karışırken
    // parıltının boyu, gölgenin biçimi gibi yapısal ayarlar da karışır (ikili bir eşikte atlama olmaz).
    final k = ambientLight(c);

    // Lensin arkasında geniş parıltı. Koyuda zemini ancak seçilir kılan %5 beyaz; açıkta güçlü bir stüdyo
    // vurgusu: jeton (`stageGlow`) merkezde, kenara doğru yumuşakça sönen radyal ışık.
    final glow = c.stageGlow;
    final reach = r * _lerp(2.1, 3.0, k);
    glowRadius = reach;
    glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glow, glow.withValues(alpha: glow.a * 0.4), glow.withValues(alpha: 0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: reach));

    // Zemine düşen gölge: koyuda lensi saran dar bir koyulaşma; açıkta (koyu lens açık zeminde ağır durur)
    // aşağı kayık geniş yumuşak gölge + lens altında kısa temas gölgesi.
    shadows = [
      _shadow(c.shadow.withValues(alpha: c.shadow.a * _lerp(1.0, 0.85, k)), r, outer: _lerp(1.2, 1.7, k), dy: _lerp(0, 0.13, k)),
      if (k > 0.01) _shadow(c.shadow.withValues(alpha: c.shadow.a * 1.1 * k), r, outer: 1.12, dy: 0.03),
    ];

    // Birim yarıçaplı: kullanan taraf canvas.scale ile açıklığa uydurur.
    final unit = Rect.fromCircle(center: Offset.zero, radius: 1);
    // Koyuda: dinlenmede açıklığın içinde çok yumuşak bir ışık seçilir (altındaki sahnenin parıltısı).
    holeLightPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x26DDF4F2), Color(0x0EA9E4DE), Color(0x00A9E4DE)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(unit);
    // Açıkta: açıklığın içi, lensin içine bakarken kenarlara doğru koyulaşır. Açılan deliğin parlak bir
    // "ışık patlaması"na dönüşmesini önler; koyuda altı zaten koyu olduğundan görünmez.
    const shade = Color(0xFF0B1016);
    holeShadePaint = Paint()
      ..shader = RadialGradient(
        colors: [shade.withValues(alpha: 0.10 * k), shade.withValues(alpha: 0.10 * k), shade.withValues(alpha: 0.34 * k)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(unit);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// [outer] (R biriminde) yarıçapa kadar yumuşakça sönen gölge; lensin kendisi üstüne çizildiğinden
  /// gölgenin ilk R'si görünmez, sönüm eğrisi lens kenarından başlar.
  LensShadow _shadow(Color color, double r, {required double outer, required double dy}) {
    final start = 1 / outer; // gradyanın lens kenarına denk geldiği durak
    double at(double k) => start + (1 - start) * k;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color,
          color.withValues(alpha: color.a * 0.55),
          color.withValues(alpha: color.a * 0.22),
          color.withValues(alpha: color.a * 0.07),
          color.withValues(alpha: 0),
        ],
        stops: [0.0, start, at(0.2), at(0.45), at(0.7), 1.0],
      ).createShader(Rect.fromCircle(center: Offset(0, r * dy), radius: r * outer));
    return LensShadow(paint, r * dy, r * outer);
  }

  void _disposeAmbient() {
    glowPaint?.shader?.dispose();
    holeLightPaint?.shader?.dispose();
    holeShadePaint?.shader?.dispose();
    for (final s in shadows) {
      s.paint.shader?.dispose();
    }
    glowPaint = null;
    holeLightPaint = null;
    holeShadePaint = null;
    shadows = const [];
  }

  void _disposeBody() {
    _body?.dispose();
    _glass?.dispose();
    _body = null;
    _glass = null;
  }

  void dispose() {
    _disposeBody();
    _disposeAmbient();
    sweepPaint?.shader?.dispose();
    sweepPaint = null;
    _ambientFor = null;
  }

  static Picture _record(void Function(Canvas c) draw) {
    final rec = PictureRecorder();
    draw(Canvas(rec));
    return rec.endRecording();
  }

  static Path _annulus(double r0, double r1) => Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r1))
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: r0));

  static Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color
    ..isAntiAlias = true;

  /// Üstte-solda ve altta-sağda ince bir ışık vuran sweep gradyanı (cilalı kenar).
  static Shader _bevelShader(double r, {double hi = 0.34, double lo = 0.14}) {
    Color w(double a) => Color.fromRGBO(255, 255, 255, a);
    return SweepGradient(
      colors: [w(0), w(0), w(lo), w(0), w(0), w(0), w(hi), w(0), w(0)],
      stops: const [0.0, 0.07, 0.125, 0.18, 0.5, 0.57, 0.625, 0.69, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  }

  void _paintBody(Canvas c, double r) {
    const o = Offset.zero;
    final px = math.max(1.0, r * 0.0042); // ~1 px çizgi kalınlığı, küçük lenste de görünür

    // Dış gövde: koyu eloksal metal.
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F3741), Color(0xFF181D24), Color(0xFF0F1318), Color(0xFF1B2128)],
          stops: [0.0, 0.42, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    c.drawCircle(o, r * 0.992, _stroke(const Color(0xFFFFFFFF), px * 1.6)..shader = _bevelShader(r));

    // Tırtıklı bilezik: hafif çukur zemin + ~120 çentik.
    c.drawPath(_annulus(r * LensRadii.grip, r * LensRadii.gripOuter), Paint()..color = const Color(0x38000000));
    const notches = 120;
    final step = 2 * math.pi / notches;
    final groove = Path();
    final ridge = Path();
    final g0 = r * (LensRadii.grip + 0.008);
    final g1 = r * (LensRadii.gripOuter - 0.008);
    for (var i = 0; i < notches; i++) {
      final a = i * step;
      groove
        ..moveTo(math.cos(a) * g0, math.sin(a) * g0)
        ..lineTo(math.cos(a) * g1, math.sin(a) * g1);
      final b = a + step * 0.36;
      ridge
        ..moveTo(math.cos(b) * g0, math.sin(b) * g0)
        ..lineTo(math.cos(b) * g1, math.sin(b) * g1);
    }
    c.drawPath(groove, _stroke(const Color(0x8C000000), px * 1.1));
    c.drawPath(ridge, _stroke(const Color(0x10FFFFFF), px * 0.8));
    c.drawCircle(o, r * LensRadii.grip, _stroke(const Color(0x14FFFFFF), px * 0.8));
    c.drawCircle(o, r * LensRadii.gripOuter, _stroke(const Color(0x66000000), px));

    // Diyafram skalası bandı.
    c.drawPath(_annulus(r * LensRadii.scaleInner, r * LensRadii.scaleOuter), Paint()..color = const Color(0x2E000000));
    _paintScale(c, r, px);
    c.drawCircle(o, r * LensRadii.scaleOuter, _stroke(const Color(0x0FFFFFFF), px * 0.8));
    c.drawCircle(o, r * LensRadii.scaleInner, _stroke(const Color(0xB3000000), px * 1.4));
    c.drawCircle(o, r * (LensRadii.scaleInner - 0.006), _stroke(const Color(0x14FFFFFF), px * 0.8));

    // İnce turkuaz LED halka: altında çok hafif yayılım, üstte ince çizgi.
    final ledR = r * LensRadii.led;
    c.drawCircle(o, ledR, _stroke(ledColor.withValues(alpha: 0.035), r * 0.022));
    c.drawCircle(o, ledR, _stroke(ledColor.withValues(alpha: 0.07), r * 0.010));
    c.drawCircle(o, ledR, _stroke(ledColor.withValues(alpha: 0.50), px * 1.0));

    // İç namlu: mat siyah, ince oluklar.
    c.drawCircle(
      o,
      r * LensRadii.barrel,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14181E), Color(0xFF080A0D), Color(0xFF0D1014)],
        ).createShader(Rect.fromCircle(center: o, radius: r * LensRadii.barrel)),
    );
    for (final f in const [0.755, 0.728, 0.70]) {
      c.drawCircle(o, r * f, _stroke(const Color(0x0AFFFFFF), px * 0.8));
    }

    // Ön cam çerçevesi (bilezik): gölge + cilalı kenar.
    c.drawCircle(o, r * (LensRadii.bezel + 0.01), _stroke(const Color(0x99000000), r * 0.02));
    c.drawCircle(o, r * LensRadii.bezel, _stroke(const Color(0xFFFFFFFF), px * 1.3)..shader = _bevelShader(r * LensRadii.bezel, hi: 0.30, lo: 0.12));

    // Yaprakların arkasındaki koyu zemin.
    c.drawCircle(o, r * LensRadii.blades, Paint()..color = const Color(0xFF07090C));
  }

  /// Skala: üstte simetrik ±112° yay, 8 rakam, ince işaretler, üstte indeks çizgisi. "Kazınmış" etki:
  /// ana çizgi düşük kontrastlı, 1 px aşağıda daha da soluk bir ışık kenarı.
  void _paintScale(Canvas c, double r, double px) {
    const labels = ['1.4', '2', '2.8', '4', '5.6', '8', '11', '16'];
    const stepDeg = 8.0;
    const half = 112.0;
    final ticks = Path();
    final ticksLight = Path();
    final rIn = r * (LensRadii.scaleInner + 0.012);
    for (var j = 0; j <= 28; j++) {
      final deg = -half + stepDeg * j;
      if (j == 14) continue; // indeks çizgisi ayrı çizilir
      final a = (-90 + deg) * math.pi / 180;
      final major = j % 4 == 0;
      final rOut = r * (LensRadii.scaleInner + (major ? 0.042 : 0.026));
      ticks
        ..moveTo(math.cos(a) * rIn, math.sin(a) * rIn)
        ..lineTo(math.cos(a) * rOut, math.sin(a) * rOut);
    }
    ticksLight.addPath(ticks, Offset(px * 0.6, px * 0.8));
    c.drawPath(ticksLight, _stroke(const Color(0x0AFFFFFF), px));
    c.drawPath(ticks, _stroke(const Color(0x6B8D98A6), px));

    // Üstte indeks çizgisi (kırık beyaz, biraz daha belirgin).
    const idxA = -math.pi / 2;
    c.drawLine(
      Offset(math.cos(idxA) * rIn, math.sin(idxA) * rIn),
      Offset(math.cos(idxA) * r * (LensRadii.scaleOuter - 0.012), math.sin(idxA) * r * (LensRadii.scaleOuter - 0.012)),
      _stroke(const Color(0x8CF3F5F8), px * 1.4),
    );

    final fontSize = (r * 0.042).clamp(7.5, 11.0).toDouble();
    final rText = r * 0.872;
    for (var i = 0; i < labels.length; i++) {
      final deg = -half + stepDeg * (i * 4);
      final a = (-90 + deg) * math.pi / 180;
      TextPainter tp(Color color) => TextPainter(
            text: TextSpan(
              text: labels[i],
              style: TextStyle(
                fontFamily: AppText.family,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation('wght', 600)],
                letterSpacing: 0.2,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
      final dark = tp(const Color(0x7A8D98A6));
      final light = tp(const Color(0x0DFFFFFF));
      c.save();
      c.translate(math.cos(a) * rText, math.sin(a) * rText);
      c.rotate(a + math.pi / 2);
      light.paint(c, Offset(-light.width / 2 + px * 0.5, -light.height / 2 + px * 0.9));
      dark.paint(c, Offset(-dark.width / 2, -dark.height / 2));
      c.restore();
      dark.dispose();
      light.dispose();
    }
  }

  /// Yapraklardan sonra çizilen cam katmanı: koyu mavi-mor kaplama yansıması, eş merkezli eleman kenarları,
  /// ince beyaz parlama yayları ve kenarlara doğru kararma.
  void _paintGlass(Canvas c, double r) {
    const o = Offset.zero;
    final px = math.max(1.0, r * 0.0042);
    final disc = Rect.fromCircle(center: o, radius: r * LensRadii.blades);

    // Kenarlara doğru kararma (derinlik).
    c.drawCircle(
      o,
      r * LensRadii.blades,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x66000000)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(disc),
    );

    // Kaplama yansıması: düşük doygunluklu mavi-mor halkalar.
    c.drawCircle(
      o,
      r * LensRadii.blades,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x00000000), Color(0x0F3F4AA8), Color(0x165B4AA0), Color(0x0E344E9A), Color(0x00000000)],
          stops: [0.0, 0.45, 0.68, 0.88, 1.0],
        ).createShader(disc),
    );

    // Eleman kenarları.
    for (final f in const [0.62, 0.52, 0.41]) {
      c.drawCircle(o, r * f, _stroke(const Color(0x0DFFFFFF), px * 0.9));
    }
    c.drawCircle(o, r * 0.57, _stroke(const Color(0x143F4AA8), r * 0.05));
    c.drawCircle(o, r * 0.465, _stroke(const Color(0x105B4AA0), r * 0.035));

    // Çapraz yumuşak ışık süpürmesi.
    c.save();
    c.clipPath(Path()..addOval(disc));
    c.drawRect(
      disc,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x14FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0x08FFFFFF)],
          stops: [0.0, 0.42, 0.7, 1.0],
        ).createShader(disc),
    );
    c.restore();

    // İnce beyaz parlama yayları.
    void arc(double f, double startDeg, double sweepDeg, double alpha, double w) {
      c.drawArc(
        Rect.fromCircle(center: o, radius: r * f),
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        _stroke(Color.fromRGBO(255, 255, 255, alpha), w)..strokeCap = StrokeCap.round,
      );
    }

    arc(0.605, 200, 52, 0.30, px * 1.6);
    arc(0.605, 18, 22, 0.12, px * 1.2);
    arc(0.505, 212, 30, 0.18, px * 1.2);
    arc(0.505, 34, 14, 0.08, px);

    // Küçük belirgin parlama noktası.
    final spec = Offset(-r * 0.30, -r * 0.36);
    c.drawCircle(
      spec,
      r * 0.07,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)]).createShader(Rect.fromCircle(center: spec, radius: r * 0.07)),
    );
  }
}
