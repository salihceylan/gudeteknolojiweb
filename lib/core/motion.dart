import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Sönümlü yay (damped spring) adım yanıtı. Hedefi çok az aşıp yerine oturur.
/// [damping] (ζ) 1'e yaklaştıkça aşma azalır; 0.6–0.8 arası "fiziksel" his verir
/// (ζ=0.72 → yaklaşık %3.8 aşma). Eğri t=1'de tam 1 döner.
class SpringCurve extends Curve {
  const SpringCurve({this.damping = 0.72});

  final double damping;

  @override
  double transformInternal(double t) {
    if (t >= 1) return 1;
    final z = damping.clamp(0.05, 0.999);
    // Süre sonunda genlik ~%1'e inecek şekilde: ζ·ωn·1 = ln(100)
    final wn = 4.605 / z;
    final root = math.sqrt(1 - z * z);
    final wd = wn * root;
    final y = 1 - math.exp(-z * wn * t) * (math.cos(wd * t) + (z / root) * math.sin(wd * t));
    // Bitişte kalan ~%1'lik sıçramayı yumuşakça kapat.
    final edge = smooth01((t - 0.9) / 0.1);
    return y * (1 - edge) + edge;
  }
}

/// Tek boyutlu yay. [x] değeri [target]'a doğru kütle-yay-sönüm dinamiğiyle gider.
/// Sürükleme bırakıldıktan sonra "ana konuma dönüş" için kullanılır.
class Spring1D {
  Spring1D({this.x = 0, this.v = 0, double? target, this.stiffness = 90, this.damping = 12}) : target = target ?? x;

  double x;
  double v;
  double target;

  /// Sertlik (k). Büyüdükçe daha hızlı döner.
  double stiffness;

  /// Sönüm (c). Kritik sönüm = 2*sqrt(k). Daha küçük = daha fazla salınım.
  double damping;

  /// Sönüm oranı ζ = c / (2 sqrt(k)). 0.6–0.8 hafif aşma, 1.0 aşmasız.
  double get dampingRatio => damping / (2 * math.sqrt(stiffness));

  set dampingRatio(double zeta) => damping = zeta * 2 * math.sqrt(stiffness);

  bool get settled => (x - target).abs() < 0.0005 && v.abs() < 0.0005;

  /// [dt] saniye cinsinden. Kararlılık için küçük alt adımlara bölünür.
  void step(double dt) {
    var remaining = dt.clamp(0.0, 0.1);
    while (remaining > 0) {
      final h = math.min(remaining, 1 / 240);
      final a = -stiffness * (x - target) - damping * v;
      v += a * h;
      x += v * h;
      remaining -= h;
    }
    if (settled) {
      x = target;
      v = 0;
    }
  }
}

/// Karelere bağlı döngü: [onFrame] her karede geçen süreyi (saniye, en çok 1/20) alır.
/// Sahne ekranda değilken [stop] çağrılarak CPU/GPU harcaması durdurulur.
class FrameLoop {
  FrameLoop(TickerProvider vsync, this.onFrame) {
    _ticker = vsync.createTicker(_tick);
  }

  final void Function(double dt, double elapsedSeconds) onFrame;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  bool get isRunning => _ticker.isActive;

  void start() {
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void dispose() => _ticker.dispose();

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    onFrame(dt.clamp(0.0, 0.05), elapsed.inMicroseconds / 1e6);
  }
}

/// Kullanıcı "hareketi azalt" tercihini açtıysa true.
bool reduceMotionOf(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// [0,1] aralığında yumuşak başlangıç/bitiş (smootherstep).
double smooth01(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

/// [value]'yu [a,b] aralığından [0,1]'e eşler ve sıkıştırır.
double remap01(double value, double a, double b) => ((value - a) / (b - a)).clamp(0.0, 1.0);
