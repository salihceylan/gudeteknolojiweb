import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/motion.dart';
import '../../theme.dart';
import 'camera_layout.dart';

/// Sahne zemini: [AppColors.stage] düz zemin + ürünün arkasında yumuşak radyal parıltı ([AppColors.stageGlow]).
/// Koyu temada parıltı %5 beyaz, açık temada güçlü bir "stüdyo vurgusu"dur. Hareketsizdir, ayrı bir
/// RepaintBoundary içinde bir kez çizilir.
class StagePainter extends CustomPainter {
  StagePainter({required this.colors, required this.glowCenter, required this.glowRadius});

  final AppColors colors;
  final Offset glowCenter;
  final double glowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.stage);

    final glow = colors.stageGlow;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        glowCenter,
        glowRadius,
        [glow, glow.withValues(alpha: glow.a * 0.42), glow.withValues(alpha: glow.a * 0.12), glow.withValues(alpha: 0)],
        const [0, 0.38, 0.72, 1],
      );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(StagePainter old) => old.colors != colors || old.glowCenter != glowCenter || old.glowRadius != glowRadius;
}

/// Üç çizgi-notunun ince çizgileri ve uç noktaları. Giriş sırasında çizgiler ürünün yanından dışarı doğru
/// "çizilir" (her not kendi aralığında); ilerleme [reveal]'dan gelir, böylece widget ağacı yeniden kurulmaz.
/// [fade] (0..1), ürün ana pozdan döndükçe çizgileri siler: notlar ana poz siluetine göre konumlandığından
/// yan görünüşlerde gövdeye binerdi ([noteVisibilityForYaw]).
class NoteLinesPainter extends CustomPainter {
  NoteLinesPainter({required this.notes, required this.reveal, required this.fade, required this.lineColor, required this.dotColor})
      : super(repaint: Listenable.merge([reveal, fade]));

  final List<NoteGeometry> notes;
  final ValueListenable<double> reveal;
  final ValueListenable<double> fade;
  final Color lineColor;
  final Color dotColor;

  /// i. notun giriş ilerlemesi (0..1): notlar küçük gecikmelerle sırayla belirir.
  static double progressOf(double reveal, int i) => smooth01(remap01(reveal, 0.66 + 0.06 * i, 0.94 + 0.02 * i));

  @override
  void paint(Canvas canvas, Size size) {
    final visible = fade.value;
    if (visible <= 0) return;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = lineColor.withValues(alpha: lineColor.a * visible);
    final dot = Paint()..color = dotColor.withValues(alpha: dotColor.a * visible);
    for (var i = 0; i < notes.length; i++) {
      final p = progressOf(reveal.value, i);
      if (p <= 0) continue;
      final n = notes[i];
      final path = Path()
        ..moveTo(n.dot.dx, n.dot.dy)
        ..lineTo(n.elbow.dx, n.elbow.dy)
        ..lineTo(n.end.dx, n.end.dy);
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * p), line);
      }
      canvas.drawCircle(n.dot, 2.6 * math.min(1.0, p * 3), dot);
    }
  }

  @override
  bool shouldRepaint(NoteLinesPainter old) =>
      old.notes != notes || old.lineColor != lineColor || old.dotColor != dotColor || old.reveal != reveal || old.fade != fade;
}

/// "Sürükleyerek döndürün" ipucunun yayı: ürünün altında, iki ucunda küçük ok uçları olan ince bir yörünge çizgisi.
/// Üzerinde çok yavaş (~9 sn) gidip gelen küçük bir nokta dönme yönünü anlatır; [phase] saniye cinsindendir.
class RotateHintArcPainter extends CustomPainter {
  RotateHintArcPainter({required this.phase, required this.lineColor, required this.dotColor, required this.animate}) : super(repaint: phase);

  final ValueListenable<double> phase;
  final Color lineColor;
  final Color dotColor;
  final bool animate;

  static const double period = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final left = Offset(size.width * 0.12, 4);
    final right = Offset(size.width * 0.88, 4);
    final ctrl = Offset(size.width / 2, 4 + 16);
    final path = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, right.dx, right.dy);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = lineColor;
    canvas.drawPath(path, stroke);

    // Ok uçları: yayın uçlarındaki teğet yönünde, dışarıya bakan küçük "V".
    void chevron(Offset p, Offset towards) {
      final d = (p - towards);
      final len = d.distance;
      if (len == 0) return;
      final u = d / len;
      for (final a in const [0.62, -0.62]) {
        final c = math.cos(a), s = math.sin(a);
        final r = Offset(u.dx * c - u.dy * s, u.dx * s + u.dy * c);
        canvas.drawLine(p, p - r * 5.5, stroke);
      }
    }

    chevron(left, ctrl);
    chevron(right, ctrl);

    // Yavaş giden nokta (hareketi azalt açıkken ortada durur).
    final t = animate ? 0.5 + 0.38 * math.sin(2 * math.pi * phase.value / period) : 0.5;
    final u = 1 - t;
    final pos = Offset(
      u * u * left.dx + 2 * u * t * ctrl.dx + t * t * right.dx,
      u * u * left.dy + 2 * u * t * ctrl.dy + t * t * right.dy,
    );
    canvas.drawCircle(pos, 2.2, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(RotateHintArcPainter old) =>
      old.lineColor != lineColor || old.dotColor != dotColor || old.animate != animate || old.phase != phase;
}

/// Klavye odak işareti: ürün kutusunun dört köşesinde "vizör" ayraçları. Eskiden kutunun tamamını çevreleyen bir
/// dikdörtgendi; çizgi-notlarının etiketleri kutunun kenarlarına yakın durduğundan halka etiketlerin üstünden geçiyordu.
/// Ayraçlar yalnızca köşelerde durur, kenar ortalarındaki notlara değmez.
class FocusBracketsPainter extends CustomPainter {
  FocusBracketsPainter({required this.color});

  final Color color;

  static const double strokeWidth = 2;

  /// Köşe yuvarlaklığı ve kolun uzunluğu (kutunun kısa kenarının oranı).
  static const double cornerRadius = 12;
  static const double armFraction = 0.08;

  /// Ürün kutusuna göre ayraçların konumu: ürünün siluetine yaklaşmak için kutu biraz içeri çekilir.
  static Rect frameFor(Size size) => (Offset.zero & size).deflate(size.shortestSide * 0.04);

  /// Ayraçların kapladığı sekiz küçük dikdörtgen (köşe başına yatay + dikey kol), çizgi kalınlığı dahil.
  /// Testler ve çakışma denetimi için; çizim de aynı geometriyi kullanır.
  static List<Rect> armRects(Size size) {
    final f = frameFor(size);
    final arm = size.shortestSide * armFraction;
    const t = strokeWidth;
    return [
      for (final x in [f.left, f.right])
        for (final y in [f.top, f.bottom]) ...[
          Rect.fromLTRB(math.min(x, x + (x == f.left ? arm : -arm)), y - t / 2, math.max(x, x + (x == f.left ? arm : -arm)), y + t / 2),
          Rect.fromLTRB(x - t / 2, math.min(y, y + (y == f.top ? arm : -arm)), x + t / 2, math.max(y, y + (y == f.top ? arm : -arm))),
        ],
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = frameFor(size);
    final arm = size.shortestSide * armFraction;
    const r = cornerRadius;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    // Her köşe: dik kol, yuvarlak dönüş, yatay kol (köşeden içeri doğru).
    Path corner(double x, double y, double sx, double sy) => Path()
      ..moveTo(x, y + sy * arm)
      ..lineTo(x, y + sy * r)
      ..arcToPoint(Offset(x + sx * r, y), radius: const Radius.circular(r), clockwise: sx * sy > 0)
      ..lineTo(x + sx * arm, y);
    canvas.drawPath(corner(f.left, f.top, 1, 1), paint);
    canvas.drawPath(corner(f.right, f.top, -1, 1), paint);
    canvas.drawPath(corner(f.left, f.bottom, 1, -1), paint);
    canvas.drawPath(corner(f.right, f.bottom, -1, -1), paint);
  }

  @override
  bool shouldRepaint(FocusBracketsPainter old) => old.color != color;
}
