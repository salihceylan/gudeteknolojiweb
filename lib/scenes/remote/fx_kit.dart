import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../theme.dart';

/// Reklamda kullanılan, temadan bağımsız renkler: ürünün kendi ışığı. İki temada da aynıdır.
abstract final class AdColors {
  /// Kutudaki LED'in mavisi (görseldeki delikle uyumlu).
  static const ledBlue = Color(0xFF58A8FF);

  /// Işık sızması, kenar ışığı ve parıltı çekirdekleri için soğuk beyaz.
  static const coolWhite = Color(0xFFDCE9FF);

  /// Sinyal darbesinin parlak çekirdeği (koyu zeminde).
  static const pulseCore = Color(0xFFE9FFFC);
}

/// Temaya göre değişen çizim ayarları.
extension AdTheme on AppColors {
  /// (koyu, açık) değer çiftinden geçerli temanınkini seçer. Çizimde temaya bağlı her sayı, adlandırılmış
  /// bir çift olarak tutulur; böylece iki temanın ayarı yan yana okunur.
  T pick<T>((T, T) pair) => isDark ? pair.$1 : pair.$2;

  /// Işığın zeminle karışım biçimi. Koyu zeminde ışık toplanır (additive). Açık zeminde toplamalı karışım beyaza doyar ve ışık görünmez olur;
  /// orada ışık normal alfa ile (halka/gölge ağırlıklı) çizilir.
  BlendMode get glowMode => isDark ? BlendMode.plus : BlendMode.srcOver;
}

/// Yumuşak radyal ışık "sprite"ı. Yarıçapı 1 olan tek bir gradyan gölgelendirici bir kez üretilir;
/// çizimde tuval ölçeklenerek istenen boyda ve opaklıkta kullanılır, böylece karede yeni Shader üretilmez.
class GlowSprite {
  GlowSprite(Color color, {List<double> stops = _softStops, List<double> alphas = _softAlphas}) {
    _paint.shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [for (final a in alphas) color.withValues(alpha: color.a * a)],
      stops,
    );
  }

  /// Tema gölgesi ([AppColors.shadow]) renginde, kenarı yumuşakça kaybolan leke. Alfa çizimde verilir.
  GlowSprite.shadow(AppColors c)
      : this(c.shadow.withValues(alpha: 1), stops: const [0.0, 0.55, 1.0], alphas: const [1.0, 0.5, 0.0]);

  /// Merkezde yoğun, kenarda sıfıra inen varsayılan profil.
  static const _softStops = [0.0, 0.32, 1.0];
  static const _softAlphas = [1.0, 0.3, 0.0];

  final Paint _paint = Paint()..isAntiAlias = true;

  /// Kutudaki LED'in mavi ışığı (ürünün kendi ışığı: temadan bağımsız).
  static final ledBlue = GlowSprite(AdColors.ledBlue);

  /// Soğuk beyaz ışık (ışık sızması, LED çekirdeği, parmak noktası).
  static final coolWhite = GlowSprite(AdColors.coolWhite);

  /// [center] çevresinde [radius] yarıçaplı ışık. [alpha] 0..1; [mode] ışıkta genellikle `plus`/`screen`.
  void draw(Canvas canvas, Offset center, double radius, double alpha, {BlendMode mode = BlendMode.srcOver}) {
    if (alpha <= _minAlpha || radius <= 0) return;
    _paint
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
      ..blendMode = mode;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius);
    canvas.drawCircle(Offset.zero, 1, _paint);
    canvas.restore();
  }

  /// Dönük, yassı elips ışık (zemindeki ışık havuzu ve gölge için).
  void drawEllipse(Canvas canvas, Offset center, double rx, double ry, double angle, double alpha,
      {BlendMode mode = BlendMode.srcOver}) {
    if (alpha <= _minAlpha) return;
    _paint
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
      ..blendMode = mode;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(rx, ry);
    canvas.drawCircle(Offset.zero, 1, _paint);
    canvas.restore();
  }

  /// Bundan silik ışık hiç çizilmez.
  static const _minAlpha = 0.002;
}

/// Telefon ekranındaki yazılar için önbellek: her metin bir kez ölçülür, sonraki karelerde yalnızca boyanır.
/// Telefon ekranı ürünün kendi yüzeyi olduğundan renkler temadan bağımsızdır; anahtar rengi içerir.
class TextCache {
  final Map<String, TextPainter> _cache = {};

  TextPainter get(String text, {required double size, required double weight, required Color color, double spacing = 0}) {
    final key = '$text|$size|$weight|${color.toARGB32()}|$spacing';
    return _cache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppText.family,
            fontSize: size,
            fontWeight: FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)],
            fontVariations: [FontVariation('wght', weight)],
            letterSpacing: spacing,
            height: 1.0,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// [tp]'yi [center] etrafında ortalayarak çizer; [alpha] < 1 ise küçük bir katmanla soldurur.
  static void paintCentered(Canvas canvas, TextPainter tp, Offset center, {double alpha = 1}) {
    paintAt(canvas, tp, center - Offset(tp.width / 2, tp.height / 2), alpha: alpha);
  }

  /// [tp]'yi sol-üst köşesi [topLeft] olacak biçimde çizer.
  static void paintAt(Canvas canvas, TextPainter tp, Offset topLeft, {double alpha = 1}) {
    if (alpha <= _hidden) return;
    if (alpha >= _opaque) {
      tp.paint(canvas, topLeft);
      return;
    }
    canvas.saveLayer(topLeft & tp.size, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    tp.paint(canvas, topLeft);
    canvas.restore();
  }

  static const _hidden = 0.01;
  static const _opaque = 0.99;
}

/// Telefon ekranı için bir kez kurulan yazı önbelleği (tasarım biriminde ölçülür).
final TextCache adTextCache = TextCache();
