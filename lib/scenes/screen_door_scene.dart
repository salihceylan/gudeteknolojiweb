import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/core.dart';
import '../theme.dart';
import '../widgets/ahbu_device.dart';
import '../widgets/common.dart';
import 'line_icons.dart';

/// AHBU Akıllı Kapı Kontrol (ekranlı cihaz) sahnesi.
///
/// Kahraman, kodla çizilmiş etkileşimli [AhbuDevice]'tır; sahne onu yumuşak bir spot parıltısı içinde
/// gösterir ve yalnızca metin + dört maddeyle destekler. Cihazın yüzme döngüsü ve karekod sayacı sahne ekran
/// dışındayken ya da "hareketi azalt" açıkken durur (`paused`); cihaz yine de görünür ve dokunulabilir kalır.
///
/// Düzen genişliğe göre üç kademelidir: masaüstü ve tablet dikeyde (>= 720 px) cihaz solda, metin sağda;
/// 600-720 px arası cihaz başlık ile maddelerin arasında; telefonda metin üstte, cihaz altta.
class ScreenDoorScene extends StatelessWidget {
  const ScreenDoorScene({super.key, this.onContact});

  /// Verilirse maddelerin altında "Teklif İsteyin" düğmesi görünür.
  final VoidCallback? onContact;

  static const _features = <_Feature>[
    _Feature(
      LineGlyph.qr,
      'Dinamik karekod',
      'Ekrandaki karekod 30 saniyede bir yenilenir; kopyalanan kod işe yaramaz.',
    ),
    _Feature(
      LineGlyph.mobile,
      'Mobil uygulama',
      'Kapı telefondan uzaktan açılır; misafirlere süreli bağlantı gönderilir.',
    ),
    _Feature(
      LineGlyph.wifiOff,
      'İnternet kesilse de çalışır',
      'Yerel ağ üzerinden açma ve çevrimdışı kayıtların sonradan eşitlenmesi.',
    ),
    _Feature(
      LineGlyph.update,
      'Uzaktan güncelleme',
      'Cihaz yazılımı sahaya gitmeden, güvenli şekilde güncellenir.',
    ),
  ];

  /// Bu genişlikten itibaren cihaz ve metin yan yana durur (tablet dikey dahil).
  static const sideBySideFrom = 720.0;

  /// Tablet iki sütununda cihaz sütununun genişliği (cihaz + spotun nefes payı).
  static const _tabletDeviceColumn = 276.0;
  static const _tabletGap = 32.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final cta = onContact;

    const header = _Header();
    final details = _Details(features: _features, onContact: cta);

    final Widget layout;
    if (width >= sideBySideFrom) {
      final wide = isWide(context);
      layout = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Tablette cihaz sütunu sabit dar; masaüstünde metne göre orantılıdır.
          if (wide)
            const Expanded(flex: 5, child: _DeviceStage(bleed: _DeviceStage.bleedBeside))
          else
            const SizedBox(width: _tabletDeviceColumn, child: _DeviceStage(bleed: _DeviceStage.bleedBeside)),
          SizedBox(width: wide ? fluid(context, 32, 72) : _tabletGap),
          Expanded(
            flex: 6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _Header.maxWidthSideBySide),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, SizedBox(height: fluid(context, 28, 36)), details],
              ),
            ),
          ),
        ],
      );
    } else if (isPhone(context)) {
      layout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, SizedBox(height: fluid(context, 28, 36)), details, SizedBox(height: fluid(context, 56, 72)), const _DeviceStage(bleed: _DeviceStage.bleedStacked)],
      );
    } else {
      // Dar tablet: cihaz başlık ile maddeler arasında, ilk ekranda metne yakın görünür.
      layout = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, SizedBox(height: fluid(context, 28, 36)), const _DeviceStage(bleed: _DeviceStage.bleedStacked), SizedBox(height: fluid(context, 28, 36)), details],
      );
    }
    return Section(color: c.bg, child: layout);
  }
}

class _Feature {
  const _Feature(this.glyph, this.title, this.text);
  final LineGlyph glyph;
  final String title;
  final String text;
}

/// Etiket + başlık + gövde.
class _Header extends StatelessWidget {
  const _Header();

  static const maxWidthSideBySide = 580.0;
  static const _leadMaxWidth = 540.0;

  @override
  Widget build(BuildContext context) {
    return const Entrance(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('YENİ NESİL'),
          SizedBox(height: 16),
          SectionTitle('AHBU Akıllı Kapı Kontrol'),
          SizedBox(height: 16),
          Lead(
            'Site ve apartman girişleri için geliştirdiğimiz, ekranlı kapı kontrol cihazı. '
            'Şifre ve kart taşımadan, telefonla güvenli giriş.',
            maxWidth: _leadMaxWidth,
          ),
        ],
      ),
    );
  }
}

/// Dört madde + (varsa) "Teklif İsteyin" düğmesi.
class _Details extends StatelessWidget {
  const _Details({required this.features, required this.onContact});

  static const _revealStepMs = 80; // maddeler arası kademe
  static const _ctaDelay = Duration(milliseconds: 420);
  static const _ctaGap = 32.0;
  static const _buttonMaxTextScale = 1.5; // düğme, çok büyük yazı ölçeğinde taşmasın

  final List<_Feature> features;
  final VoidCallback? onContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < features.length; i++)
          Entrance(
            delay: Duration(milliseconds: _revealStepMs * (i + 1)),
            child: _FeatureRow(feature: features[i]),
          ),
        const HairlineDivider(),
        if (onContact != null) ...[
          const SizedBox(height: _ctaGap),
          Entrance(
            delay: _ctaDelay,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: _buttonMaxTextScale,
              child: PillButton(label: 'Teklif İsteyin', onTap: onContact!),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tek madde: çizgi ikon + başlık + tek cümlelik açıklama. Maddeler arası ince çizgi.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  static const _rowPadding = 18.0;
  static const _iconGap = 18.0;
  static const _iconNudge = 1.0; // ikonu başlığın ilk satırıyla hizalar
  static const _iconAlpha = 0.9; // ikon çok hafif: vurgu rengi tam yoğunlukta değil

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final desc = AppText.body(context).copyWith(fontSize: fluid(context, 14, 15), height: 1.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HairlineDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: _rowPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: _iconNudge),
                // Küçük çizgi ikon: açık temada kontrastı yüksek vurgu sürümü.
                child: LineIcon(feature.glyph, color: c.accentText.withValues(alpha: _iconAlpha)),
              ),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(feature.title, style: AppText.h3(context)),
                    const SizedBox(height: 4),
                    Text(feature.text, style: desc),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cihaz + arkasındaki spot parıltısı + zemin gölgesi + "Butona basarak deneyin" ipucu.
///
/// Giriş animasyonu ([Entrance]) en dışta durur ve cihazla ilgili hiçbir ticker kısıtına girmez; "hareketi azalt"
/// açıkken cihaz ve ipucu anında görünür. Cihaz yalnızca ekrandayken ve hareket serbestken canlıdır.
class _DeviceStage extends StatelessWidget {
  /// [bleed]: parıltının cihaz sahnesinin üstüne ve altına taşabileceği en çok yükseklik. Parıltı sonradan
  /// çizildiği için komşu yazının üstüne binip onu soldurmasın diye metinle üst üste dizilen düzenlerde küçük tutulur.
  const _DeviceStage({required this.bleed});

  /// Cihaz metnin yanındayken: bölümün dikey boşluğu içinde kalan taşma payı.
  static const bleedBeside = 56.0;

  /// Cihaz metnin altında/üstünde dizildiğinde: yalnızca araya konan boşluğun içi.
  static const bleedStacked = 24.0;

  final double bleed;

  static const deviceWidth = 250.0;
  static const _deviceAspect = 1.62; // AhbuDevice yükseklik/genişlik oranı
  static const _topGap = 20.0;
  static const _hintGap = 44.0;
  static const _glowMin = 440.0;
  static const _glowMax = 600.0;
  static const _glowSpread = 1.15; // sütun genişliğine göre parıltı genişliği
  static const _glowTall = 1.12; // dikey cihaza uyması için elips biraz uzun
  static const _glowMaxHeight = 640.0;
  static const _accentTint = 0.06; // koyu temada merkezdeki vurgu tonu (şartname sınırı: ≤ %8)
  static const _floorWidthFactor = 1.7; // zemin gölgesi genişliği / cihaz genişliği
  static const _floorColumnFactor = 1.2; // ...ama sütun genişliğinin en çok bu katı
  static const _floorHeight = 84.0;
  static const _floorDrop = 14.0; // gölge merkezi cihaz tabanının bu kadar altında
  static const _revealDelay = Duration(milliseconds: 120);
  /// Görünürlük payı yok: sahne gerçekten ekranla kesişmiyorsa döngüler durur. [VisibilityProbe] payı üst ve alt
  /// kenarda simetriktir; sıfırdan büyük pay, sahne ekranın üstünden o kadar çıkmışken de cihazı canlı tutardı.
  static const _probeMargin = 0.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = reduceMotionOf(context);
    const deviceHeight = deviceWidth * _deviceAspect;
    return VisibilityProbe(
      margin: _probeMargin,
      builder: (context, visible) => Entrance(
        delay: _revealDelay,
        child: LayoutBuilder(
          builder: (context, box) {
            final glowWidth = (math.max(box.maxWidth, _glowMin) * _glowSpread).clamp(_glowMin, _glowMax);
            // Zemin gölgesi sütundan çok taşmaz (tablette ekran kenarına yapışmasın).
            final floorWidth = math.min(deviceWidth * _floorWidthFactor, box.maxWidth * _floorColumnFactor);
            // Elips cihaz merkezinde durur; üst ve alttan sahne dışına en çok [bleed] taşar.
            final glowHeight = math.min(glowWidth * _glowTall, math.min(_glowMaxHeight, 2 * (_topGap + deviceHeight / 2 + bleed)));
            return Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // Spot: cihazın merkezinde, durağan (yeniden çizilmez). Merkezde yoğun, kenarda saydam.
                Positioned(
                  top: _topGap + deviceHeight / 2 - glowHeight / 2,
                  left: (box.maxWidth - glowWidth) / 2,
                  width: glowWidth,
                  height: glowHeight,
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SpotPainter(
                          stage: c.stage,
                          glow: c.stageGlow,
                          accent: c.accent,
                          accentTint: c.isDark ? _accentTint : 0,
                        ),
                      ),
                    ),
                  ),
                ),
                // Zemin gölgesi: cihazın altında geniş, yumuşak elips.
                Positioned(
                  top: _topGap + deviceHeight + _floorDrop - _floorHeight / 2,
                  left: (box.maxWidth - floorWidth) / 2,
                  width: floorWidth,
                  height: _floorHeight,
                  child: IgnorePointer(
                    child: RepaintBoundary(child: CustomPaint(painter: _FloorShadowPainter(shadow: c.shadow))),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: double.infinity, height: _topGap),
                    // Cihaz bir ürün çizimidir, okunan metin değil: yazı ölçeği ekranındaki sabit yerleşimi bozmasın.
                    MediaQuery.withNoTextScaling(
                      child: Semantics(
                        label: 'AHBU Akıllı Kapı Kontrol cihazı. Butona basarak deneyebilirsiniz.',
                        child: AhbuDevice(width: deviceWidth, paused: reduce || !visible, shadowColor: c.shadow),
                      ),
                    ),
                    const SizedBox(height: _hintGap),
                    const _TryHint(),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cihazın arkasındaki yumuşak spot: merkezde vurgulu parıltı, dışında hafif koyu stüdyo zemini (vinyet), sonra saydam.
/// Koyu temada [stage] zemin rengiyle aynıdır (yalnızca beyaz parıltı + hafif vurgu görünür); açık temada cihazın
/// çevresi parlak bir havuz, onun dışı biraz daha koyu stüdyo zeminidir. Cihaz merkezi kapattığından asıl görünen
/// bölge 0.4-0.9 yarıçap arasıdır: yoğunluk orada tutulur, sonra yumuşakça söner. Elips, dikey cihaza uyar.
/// Renkler tema jetonlarıdır, kurucudan gelir ve [shouldRepaint]'e katılır.
class _SpotPainter extends CustomPainter {
  const _SpotPainter({required this.stage, required this.glow, required this.accent, required this.accentTint});

  /// Gradyan durakları: yarıçap oranı -> parıltı yoğunluğu (1 = tam). Merkezi yoğun, kenarı yumuşak.
  static const _stops = <double>[0.0, 0.3, 0.5, 0.7, 0.85, 1.0];
  static const _glow = <double>[1.0, 0.95, 0.8, 0.5, 0.2, 0.0];

  /// Aynı duraklarda stüdyo zemininin (vinyet) opaklığı: merkezde yok, 0.7-0.85 civarında en yoğun, dışta yine yok.
  static const _vignette = <double>[0.0, 0.35, 0.8, 1.0, 0.6, 0.0];
  static const _glowBoost = 1.2; // stageGlow'un şartname sınırı içinde (beyaz %4-6) merkezde biraz güçlendirilmesi

  final Color stage;
  final Color glow;
  final Color accent;

  /// Merkezdeki vurgu tonunun alfası (şartname sınırı: ≤ %8). Açık temada nötr beyaz kalması için 0 verilir.
  final double accentTint;

  @override
  void paint(Canvas canvas, Size size) {
    // Parıltıyı stüdyo zemini üzerine bileştirip birlikte gradyana vermek, saydama giderken gri kenar oluşmasını önler.
    final colors = <Color>[
      for (var i = 0; i < _stops.length; i++)
        Color.alphaBlend(
          accent.withValues(alpha: accentTint * _glow[i]),
          Color.alphaBlend(
            glow.withValues(alpha: (glow.a * _glowBoost * _glow[i]).clamp(0.0, 1.0)),
            stage.withValues(alpha: _vignette[i]),
          ),
        ),
    ];
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = RadialGradient(colors: colors, stops: _stops).createShader(rect));
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.stage != stage || old.glow != glow || old.accent != accent || old.accentTint != accentTint;
}

/// Cihazın altına yayılan yassı, yumuşak zemin gölgesi (dairesel gradyanı dikeyde ezerek çizer).
class _FloorShadowPainter extends CustomPainter {
  const _FloorShadowPainter({required this.shadow});

  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final shader = RadialGradient(
      colors: [shadow, shadow.withValues(alpha: shadow.a * 0.4), shadow.withValues(alpha: 0)],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(1, size.height / size.width)
      ..drawCircle(Offset.zero, r, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_FloorShadowPainter old) => old.shadow != shadow;
}

class _TryHint extends StatelessWidget {
  const _TryHint();

  static const _iconSize = 16.0;
  static const _iconStroke = 1.25;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LineIcon(LineGlyph.press, color: c.textDim, size: _iconSize, strokePx: _iconStroke),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Butona basarak deneyin',
            textAlign: TextAlign.center,
            // Büyük yazı ölçeğinde satır kırılırsa metin kutusu en uzun satıra daralır; ikon metnin yanında kalır.
            textWidthBasis: TextWidthBasis.longestLine,
            style: AppText.small(context, color: c.textDim),
          ),
        ),
      ],
    );
  }
}
