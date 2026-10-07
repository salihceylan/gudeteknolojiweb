import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';
import 'iris_motion.dart';

/// Alt ortadaki küçük kaydırma ipucu: "Aşağı kaydırın" + 1 px dikey çizgi içinde çok yavaş akan ışık noktası.
/// Nokta [motion] zamanıyla hareket eder; hareket durunca (ör. hareketi azalt) çizgi üzerinde sabit kalır.
class ScrollHint extends StatelessWidget {
  const ScrollHint({super.key, required this.motion, required this.animated});

  final IrisMotion motion;

  /// false ise nokta akmaz.
  final bool animated;

  static const _lineHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Aşağı kaydırın', textScaler: TextScaler.noScaling, style: AppText.small(context, color: c.textDim).copyWith(fontSize: 12, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(1, _lineHeight),
              painter: _HintLinePainter(motion, animated, c.lineStrong, c.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintLinePainter extends CustomPainter {
  _HintLinePainter(this.motion, this.animated, this.lineColor, this.dotColor)
      : _line = Paint()
          ..color = lineColor
          ..strokeWidth = 1,
        super(repaint: motion);

  final IrisMotion motion;
  final bool animated;

  /// Tema renkleri: çizgi ve ışık noktası (painter içinde `context` yok; bkz. docs/THEMING.md).
  final Color lineColor;
  final Color dotColor;

  final Paint _line;
  final _dot = Paint()..isAntiAlias = true;

  /// Bir geçişin süresi (sn). Çok yavaş.
  static const _period = 4.4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset.zero, Offset(0, size.height), _line);
    final u = animated ? (motion.time / _period) % 1.0 : 0.35;
    final eased = u * u * (3 - 2 * u);
    final y = eased * size.height;
    final a = animated ? math.sin(math.pi * u) : 0.8;
    // Işık noktası ve arkasında kısa, soluk bir iz.
    for (var i = 3; i >= 0; i--) {
      final ty = y - i * 4.0;
      if (ty < 0) continue;
      _dot.color = dotColor.withValues(alpha: (i == 0 ? 0.9 : 0.22 / i) * a);
      canvas.drawCircle(Offset(0.5, ty), i == 0 ? 1.7 : 1.2, _dot);
    }
  }

  @override
  bool shouldRepaint(_HintLinePainter old) =>
      old.motion != motion || old.animated != animated || old.lineColor != lineColor || old.dotColor != dotColor;
}
