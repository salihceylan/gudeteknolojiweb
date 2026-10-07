import 'package:flutter/widgets.dart';

import '../../camera3d/camera_painter.dart';
import '../../camera3d/camera_pose.dart';

/// Ürünün (3B kamera) çizicisine tek geçiş noktası. Sahnenin geri kalanı çiziciyi tanımaz.
///
/// YER TUTUCU: ürün, kodla üretilen genel bir "bullet" kameradır (bkz. lib/camera3d). Gerçek ürün görseli/modeli
/// gelince yalnızca burası (çizici) değişir; sahne, fizik ve yerleşim aynı kalır.
///
/// Çiziciler kurucuya aldıkları değerleri `shouldRepaint`'te karşılaştırır; yaw/pitch ise [CameraPose]
/// üzerinden (repaint dinleyicisi) gelir, yani her karede yeni painter üretmek gerekmez.
CustomPainter buildProductPainter({
  required CameraPose pose,
  required double quality,
  required Color shadowColor,
  required double rimStrength,
}) {
  return CameraProductPainter(pose: pose, quality: quality, shadowColor: shadowColor, rimStrength: rimStrength);
}

/// Ürün kutusunun en/boy önerisi (çizici tüm açılarda ürünü bu orandaki kutuya kenar payı bırakarak sığdırır).
const double kProductAspect = CameraProductPainter.aspect;
