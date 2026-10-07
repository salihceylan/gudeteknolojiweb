import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'gude_logo_data.dart';
import 'logo_model.dart';

/// Güde Teknoloji logosu: vektör, şeffaf zeminli; renkleri `AppColors.logo` (lib/theme.dart) belirler.
/// Plaka yoktur; koyu temada koyu, açık temada açık zeminin üstünde doğrudan çizilir.
/// En/boy oranı [kLogoViewWidth] / [kLogoViewHeight]; boyut yalnızca [height] ile verilir.
class GudeLogo extends StatelessWidget {
  const GudeLogo({super.key, required this.height, this.semanticLabel});

  final double height;

  /// Verilirse görsel olarak okunur; null ise (ör. etiketli bir düğmenin içinde) anlamsal ağaçtan çıkarılır.
  final String? semanticLabel;

  static double get aspect => kLogoViewWidth / kLogoViewHeight;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors.logo;
    Widget art = SizedBox(
      width: height * aspect,
      height: height,
      child: CustomPaint(painter: GudeLogoPainter(palette), isComplex: true),
    );
    art = semanticLabel == null ? ExcludeSemantics(child: art) : Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: art));
    return RepaintBoundary(child: art);
  }
}

/// Yol verisi bir kez çözülür ve bütün logolarca paylaşılır ([Path] değişmez olarak kullanılır).
class _ParsedShape {
  _ParsedShape(this.shape) : path = parseLogoPath(shape.d);
  final LogoShape shape;
  final Path path;
}

class _ParsedLogo {
  _ParsedLogo._()
      : shadow = [for (final s in kLogoShadow) _ParsedShape(s)],
        leaves = [for (final s in kLogoLeaves) _ParsedShape(s)],
        wordmark = [for (final s in kLogoWordmark) _ParsedShape(s)],
        tagline = [for (final s in kLogoTagline) _ParsedShape(s)];

  static final instance = _ParsedLogo._();

  final List<_ParsedShape> shadow;
  final List<_ParsedShape> leaves;
  final List<_ParsedShape> wordmark;
  final List<_ParsedShape> tagline;
}

@visibleForTesting
const wordmarkFillId = 'wordmark-fill';

class GudeLogoPainter extends CustomPainter {
  const GudeLogoPainter(this.palette);

  final LogoPalette palette;

  /// Gölge yumuşaklığı (logo çizim uzayı birimi; 1600 birim genişlikte).
  static const shadowBlur = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    final parsed = _ParsedLogo.instance;
    canvas.save();
    canvas.scale(size.width / kLogoViewWidth, size.height / kLogoViewHeight);

    if (palette.shadow.a > 0) {
      for (final p in parsed.shadow) {
        final paint = Paint()
          ..isAntiAlias = true
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadowBlur)
          ..color = palette.shadow.withValues(alpha: palette.shadow.a * p.shape.opacity * _solidAlpha(p.shape.fill));
        canvas.drawPath(p.path, paint);
      }
    }

    for (final p in parsed.leaves) {
      canvas.drawPath(p.path, _paintFor(p.shape));
    }

    for (final p in parsed.wordmark) {
      canvas.drawPath(p.path, _wordmarkPaint(p.shape, p.path));
    }

    for (final p in parsed.tagline) {
      final isOutline = p.shape.id.endsWith('outline');
      canvas.drawPath(
        p.path,
        Paint()
          ..isAntiAlias = true
          ..color = isOutline ? palette.taglineEdge : palette.tagline,
      );
    }
    canvas.restore();
  }

  /// SVG'deki özgün dolgu (gradyan ya da düz renk), şeklin kendi saydamlığıyla.
  static Paint _paintFor(LogoShape s) {
    final paint = Paint()..isAntiAlias = true;
    final fill = s.fill;
    if (fill is LogoSolid) {
      paint.color = fill.color.withValues(alpha: fill.color.a * s.opacity);
    } else {
      paint.shader = fill.shader(s.opacity);
    }
    return paint;
  }

  static double _solidAlpha(LogoFill f) => f is LogoSolid ? f.color.a : 1.0;

  /// Harf yüzleri: SVG'deki gradyan geometrisi (yön/uzunluk) korunur, renk durakları temadan gelir.
  /// Koyu kenar: tek düz renk.
  Paint _wordmarkPaint(LogoShape s, Path path) {
    final paint = Paint()..isAntiAlias = true;
    if (s.id != wordmarkFillId) {
      paint.color = palette.wordOutline;
      return paint;
    }
    final fill = s.fill;
    final b = path.getBounds();
    final from = fill is LogoLinear ? Offset(fill.x1, fill.y1) : b.centerLeft;
    final to = fill is LogoLinear ? Offset(fill.x2, fill.y2) : b.centerRight;
    paint.shader = ui.Gradient.linear(from, to, [palette.wordStart, palette.wordMid, palette.wordEnd], const [0.0, 0.5, 1.0]);
    return paint;
  }

  @override
  bool shouldRepaint(GudeLogoPainter old) => old.palette != palette;
}
