import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../core/core.dart';
import '../widgets/reveal.dart';

/// Ekranlı ürün, Teklif bandı ve İletişim sahnelerinin ortak yardımcıları: tek çizgi dilinde ikonlar ve
/// "hareketi azalt"a saygılı giriş animasyonu. Material ikonları dolgulu göründüğü ve sade çizgi diliyle
/// uyuşmadığı için bu sahnelerin bütün ikonları (oklar dahil) tek yerden, aynı 24x24 ızgarada elle çizilir.

/// Çizgi ikon şekilleri.
enum LineGlyph {
  /// Karekod (üç köşe karesi ve noktalar).
  qr,

  /// Cep telefonu (mobil uygulama).
  mobile,

  /// Üstü çizili Wi-Fi (internet kesintisinde çalışma).
  wifiOff,

  /// Tepsiye inen ok (güncelleme).
  update,

  /// Düğme: halka içinde nokta ("butona basın" ipucu).
  press,

  /// Telefon ahizesi.
  phone,

  /// Zarf.
  mail,

  /// Konum iğnesi.
  pin,

  /// Sağ üste giden ok (dış bağlantı / tıklanabilir satır).
  arrowUpRight,
}

/// [glyph] şeklini [color] renginde, [size] kenarlı kutuya çizer. Çizgi kalınlığı [strokePx] mantıksal pikseldir;
/// ikon küçüldüğünde de aynı kalır. Renk temadan alınıp verilir (bkz. docs/THEMING.md).
class LineIcon extends StatelessWidget {
  const LineIcon(this.glyph, {super.key, required this.color, this.size = 24, this.strokePx = LineIconPainter.defaultStroke});

  final LineGlyph glyph;
  final Color color;
  final double size;
  final double strokePx;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: LineIconPainter(glyph, color, strokePx)),
    );
  }
}

/// [LineIcon]'un çizicisi. Tema renkleri kurucu alanıdır ve [shouldRepaint]'e katılır; böylece tema geçişinde yeniden boyanır.
class LineIconPainter extends CustomPainter {
  const LineIconPainter(this.glyph, this.color, [this.strokePx = defaultStroke]);

  static const defaultStroke = 1.5;
  static const _grid = 24.0;

  final LineGlyph glyph;
  final Color color;
  final double strokePx;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _grid;
    canvas.scale(scale);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokePx / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    switch (glyph) {
      case LineGlyph.qr:
        for (final o in const [Offset(3, 3), Offset(14, 3), Offset(3, 14)]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, 7, 7), const Radius.circular(1.5)), p);
        }
        canvas.drawPoints(PointMode.points, const [
          Offset(6.5, 6.5),
          Offset(17.5, 6.5),
          Offset(6.5, 17.5),
          Offset(14.5, 14.5),
          Offset(20.5, 14.5),
          Offset(17.5, 17.5),
          Offset(14.5, 20.5),
          Offset(20.5, 20.5),
        ], p);
      case LineGlyph.mobile:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(6.5, 2.5, 11, 19), const Radius.circular(2.5)), p);
        canvas.drawLine(const Offset(10.5, 18.3), const Offset(13.5, 18.3), p);
      case LineGlyph.wifiOff:
        for (final r in const [4.5, 8.5, 12.5]) {
          canvas.drawArc(Rect.fromCircle(center: const Offset(12, 19), radius: r), -math.pi * 3 / 4, math.pi / 2, false, p);
        }
        canvas.drawPoints(PointMode.points, const [Offset(12, 19.5)], p);
        canvas.drawLine(const Offset(3.5, 3.5), const Offset(20.5, 20.5), p);
      case LineGlyph.update:
        final tray = Path()
          ..moveTo(4, 14.5)
          ..lineTo(4, 19)
          ..arcToPoint(const Offset(5, 20), radius: const Radius.circular(1), clockwise: false)
          ..lineTo(19, 20)
          ..arcToPoint(const Offset(20, 19), radius: const Radius.circular(1), clockwise: false)
          ..lineTo(20, 14.5);
        canvas
          ..drawPath(tray, p)
          ..drawLine(const Offset(12, 3.5), const Offset(12, 15), p)
          ..drawPath(
            Path()
              ..moveTo(7.5, 10.5)
              ..lineTo(12, 15)
              ..lineTo(16.5, 10.5),
            p,
          );
      case LineGlyph.press:
        canvas
          ..drawCircle(const Offset(12, 12), 9, p)
          ..drawCircle(const Offset(12, 12), 2.4, Paint()..color = color);
      case LineGlyph.phone:
        // Ahize: iki ucu yuvarlak, ortası içe kıvrık klasik telefon şekli.
        const r2 = Radius.circular(2);
        final path = Path()
          ..moveTo(22, 16.92)
          ..lineTo(22, 19.92)
          ..arcToPoint(const Offset(19.82, 21.92), radius: r2)
          ..arcToPoint(const Offset(11.19, 18.85), radius: const Radius.circular(19.79))
          ..arcToPoint(const Offset(5.19, 12.85), radius: const Radius.circular(19.5))
          ..arcToPoint(const Offset(2.12, 4.18), radius: const Radius.circular(19.79))
          ..arcToPoint(const Offset(4.11, 2), radius: r2)
          ..lineTo(7.11, 2)
          ..arcToPoint(const Offset(9.11, 3.72), radius: r2)
          ..arcToPoint(const Offset(9.81, 6.53), radius: const Radius.circular(12.84), clockwise: false)
          ..arcToPoint(const Offset(9.36, 8.64), radius: r2)
          ..lineTo(8.09, 9.91)
          ..arcToPoint(const Offset(14.09, 15.91), radius: const Radius.circular(16), clockwise: false)
          ..lineTo(15.36, 14.64)
          ..arcToPoint(const Offset(17.47, 14.19), radius: r2)
          ..arcToPoint(const Offset(20.28, 14.89), radius: const Radius.circular(12.84), clockwise: false)
          ..arcToPoint(const Offset(22, 16.92), radius: r2)
          ..close();
        canvas.drawPath(path, p);
      case LineGlyph.mail:
        canvas
          ..drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 4.5, 19, 15), const Radius.circular(2)), p)
          ..drawPath(
            Path()
              ..moveTo(3, 7)
              ..lineTo(12, 13.5)
              ..lineTo(21, 7),
            p,
          );
      case LineGlyph.pin:
        final path = Path()
          ..moveTo(20.5, 10)
          ..cubicTo(20.5, 17, 12, 22.5, 12, 22.5)
          ..cubicTo(12, 22.5, 3.5, 17, 3.5, 10)
          ..arcToPoint(const Offset(20.5, 10), radius: const Radius.circular(8.5))
          ..close();
        canvas
          ..drawPath(path, p)
          ..drawCircle(const Offset(12, 10), 3, p);
      case LineGlyph.arrowUpRight:
        canvas
          ..drawLine(const Offset(6.5, 17.5), const Offset(17.5, 6.5), p)
          ..drawPath(
            Path()
              ..moveTo(8.5, 6.5)
              ..lineTo(17.5, 6.5)
              ..lineTo(17.5, 15.5),
            p,
          );
    }
  }

  @override
  bool shouldRepaint(LineIconPainter old) => old.glyph != glyph || old.color != color || old.strokePx != strokePx;
}

/// Giriş animasyonu: normalde [Reveal]; "hareketi azalt" açıkken içerik animasyonsuz, anında görünür
/// (DESIGN_SPEC §3.7: geçişler anlık olur). [Reveal] kendisi bu tercihi okumadığından sarmalayıcı burada durur.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => reduceMotionOf(context) ? child : Reveal(delay: delay, child: child);
}
