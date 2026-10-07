import 'package:flutter/foundation.dart';

/// Lensin boşta mikro hareketlerinin anlık değerleri (zaman ve fare paralaksı).
/// Çizici bu nesneyi dinler; widget ağacı yeniden kurulmaz.
class IrisMotion extends ChangeNotifier {
  /// Saniye cinsinden akış süresi. Hareket kapalıyken sabit kalır.
  double time = 0;

  /// Lensin fare paralaksı kayması (piksel).
  double dx = 0;
  double dy = 0;

  void update({required double time, required double dx, required double dy}) {
    this.time = time;
    this.dx = dx;
    this.dy = dy;
    notifyListeners();
  }
}
