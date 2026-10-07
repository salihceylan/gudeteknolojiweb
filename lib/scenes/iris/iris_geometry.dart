import 'dart:math' as math;
import 'dart:ui';

import '../../core/motion.dart';

/// Diyaframdaki yaprak sayısı. Açıklık düzgün bir 9-gendir.
const int kBladeCount = 9;

/// Açılış → kamera geçişinin kaydırma ilerlemesine (p: 0..1) bağlı koreografisi.
/// Tüm fonksiyonlar saftır; çizim ve testler aynı sayıları kullanır.
class IrisChoreography {
  IrisChoreography._();

  /// Dinlenmede açıklığın dış yarıçapı (lens yarıçapının oranı).
  static const double restAperture = 0.07;

  /// Geçişin sonunda (ölçeklenmeden önce) açıklığın dış yarıçapı.
  static const double openAperture = 0.60;

  /// Başlangıç dönüş açısı: bir köşe yukarıda.
  static const double baseRotation = -math.pi / 2;

  /// Yaprakların p = 1'deki toplam ek dönüşü (radyan).
  static const double bladeTurn = 0.5;

  /// Kamera sahnesinin görünmeye başladığı ilerleme.
  static const double sceneStart = 0.35;

  /// Bu ilerlemeden sonra üst katman hiç çizilmez; kamera sahnesi etkileşime açılır.
  static const double coverEnd = 0.98;

  /// Açılış metninin etkileşime kapandığı ilerleme. Şartname en geç 0.3 der; ama metin p = 0.22'de zaten
  /// tamamen solmuş olur, görünmez düğmeye tıklanıp odaklanabilmesi yanıltıcı olurdu. Bu yüzden opaklık ~%5'e
  /// düştüğünde (p = 0.18) kapanır.
  static const double textInteractiveEnd = 0.18;

  /// Metin bloğunun tamamen kaybolduğu ilerleme.
  static const double textFadeEnd = 0.22;

  static double easeOut(double t) {
    final x = 1 - t.clamp(0.0, 1.0);
    return 1 - x * x * x;
  }

  /// Açıklık poligonunun (9-gen) dış yarıçapı: lens yarıçapı biriminde.
  static double aperture(double p) => restAperture + (openAperture - restAperture) * easeOut(remap01(p, 0, 0.8));

  /// Yaprakların dönüşü (radyan).
  static double rotation(double p) => baseRotation + bladeTurn * p;

  /// Lens ölçeği: 1'den [endScale]'e üstel (algısal olarak düzgün) büyür.
  static double lensScale(double p, double endScale) => math.exp(math.log(endScale) * smooth01(remap01(p, 0.05, 1)));

  /// Metin bloğu: 1 → 0.
  static double textOpacity(double p) => 1 - smooth01(remap01(p, 0, textFadeEnd));

  /// Metin bloğunun yukarı kayması (piksel, 0 → 40).
  static double textLift(double p) => 40 * smooth01(remap01(p, 0, textFadeEnd));

  /// Kaydırma ipucu p = 0.1'de kaybolur.
  static double hintOpacity(double p) => 1 - smooth01(remap01(p, 0, 0.1));

  /// Kamera sahnesine verilen `reveal`.
  static double reveal(double p) => remap01(p, sceneStart, 1.0);
}

/// Bir sahne boyutu için lensin yerleşimi ve p = 1'de görünür alanı kaplayan ölçek.
class IrisLayout {
  const IrisLayout._(this.size, this.wide, this.center, this.radius, this.endScale);

  /// [mobileTextBottom]: mobilde açılış metninin alt kenarı (piksel); lens bunun altında kalacak
  /// biçimde (gerekirse küçülerek) yerleşir. Masaüstünde yok sayılır.
  factory IrisLayout.compute(Size size, {double mobileTextBottom = 0}) {
    final wide = isWideSize(size);
    final Offset center;
    final double radius;
    if (wide) {
      center = Offset(size.width * 0.70, size.height * 0.52);
      radius = math.min(size.width * 0.22, size.height * 0.30);
    } else {
      // Metin ile alttaki kaydırma ipucu arasındaki boşluğa sığdır; tercih edilen merkez 0.68H.
      final top = mobileTextBottom + 20;
      final bottom = size.height - 92;
      final space = math.max(120.0, bottom - top);
      radius = math.min(size.width * 0.36, space / 2);
      final lo = top + radius;
      final hi = math.max(lo, bottom - radius);
      center = Offset(size.width * 0.5, (size.height * 0.68).clamp(lo, hi));
    }
    return IrisLayout._(size, wide, center, radius, coverScale(size, center, radius));
  }

  /// Masaüstü (yan yana) yerleşimi: genişlik >= 900 ya da yatay tutulmuş telefon (geniş ve kısa ekran).
  /// Yatay telefonda mobil yerleşim (metin üstte, lens altta) lensi ekran dışına iterdi.
  static bool isWideSize(Size size) => size.width >= 900 || (size.width >= 560 && size.width > size.height * 1.35);

  final Size size;
  final bool wide;
  final Offset center;

  /// Lensin dış yarıçapı (piksel).
  final double radius;

  /// p = 1'de açıklık poligonunun görünür alanı tamamen kapladığı ölçek.
  final double endScale;

  /// Verilen p için lens ölçeği.
  double scaleAt(double p) => IrisChoreography.lensScale(p, endScale);

  /// Verilen p için açıklık poligonunun dış yarıçapı (piksel, ölçeklenmiş).
  double apertureRadiusAt(double p) => IrisChoreography.aperture(p) * radius * scaleAt(p);

  @override
  bool operator ==(Object other) => other is IrisLayout && other.size == size && other.center == center && other.radius == radius;

  @override
  int get hashCode => Object.hash(size, center, radius);
}

/// p = 1'de (açıklık 0.60R, dönüş [IrisChoreography.rotation]) 9-gen açıklığın [size] dikdörtgenini
/// tamamen kaplaması için gereken ölçek; en uzak köşe için %4 pay bırakılır.
///
/// Düzgün çokgenin her kenarı için kenar normali n_i ve içteki yarıçap ρ·cos(π/9) kullanılır:
/// köşe v çokgenin içindedir ⇔ her i için v·n_i ≤ ρ·cos(π/9). Gereken ρ böylece birebir bulunur.
double coverScale(Size size, Offset center, double radius) {
  final d = IrisChoreography.openAperture * radius;
  if (d <= 0) return 1; // sıfır boyutlu sahne (ör. gizli çerçeve): bölme yok, NaN üretme
  final rot = IrisChoreography.rotation(1);
  final inner = math.cos(math.pi / kBladeCount);
  var need = 0.0;
  for (final corner in [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)]) {
    final v = corner - center;
    for (var i = 0; i < kBladeCount; i++) {
      final a = rot + (2 * i + 1) * math.pi / kBladeCount;
      final dot = v.dx * math.cos(a) + v.dy * math.sin(a);
      need = math.max(need, dot / inner);
    }
  }
  return 1.04 * need / d;
}

/// Düzgün 9-genin ([radius] dış yarıçap, [rotation] dönüş) [p] noktasını içerip içermediği. Testler için.
bool irisPolygonContains(Offset center, double radius, double rotation, Offset p) {
  final v = p - center;
  final inner = radius * math.cos(math.pi / kBladeCount);
  for (var i = 0; i < kBladeCount; i++) {
    final a = rotation + (2 * i + 1) * math.pi / kBladeCount;
    if (v.dx * math.cos(a) + v.dy * math.sin(a) > inner) return false;
  }
  return true;
}
