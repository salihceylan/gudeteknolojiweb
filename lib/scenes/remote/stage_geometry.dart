import 'dart:ui';

import 'ad_timeline.dart';
import 'box_asset.dart';

/// Sahnenin yerleşimi. Tüm ölçüler "tasarım birimi"dir; çizim katmanları tasarım boyutunu gerçek boyuta
/// tek bir ölçekle (genişlik / tasarım genişliği) büyütüp küçültür. Böylece telefon, kutu, kapı ve sinyal
/// eğrisi her ekranda aynı oranda kalır.
///
/// İki ayrı kompozisyon vardır; mobil, masaüstünün küçültülmüşü değildir:
/// [wide]: kutu solda önde, telefon sağ-önde, kapı arkada ortada; sinyal telefonun solundan kutuya uzanır.
/// [tall]: telefon sol üstte, kapı sağ üstte, kutu altta; sinyal kapının altından geçip kutuya iner.
class StageGeometry {
  StageGeometry._({
    required this.design,
    required this.box,
    required this.door,
    required this.phone,
    required this.phoneFrom,
    required this.phoneTilt,
    required this.signalStart,
    required this.signalC1,
    required this.signalC2,
    required this.glowCenter,
    required this.glowRadius,
    required this.horizonY,
  });

  /// Telefon çiziminin kendi (ölçeksiz) boyutu.
  static const phoneBaseSize = Size(176, 360);

  /// Telefonun düğme merkezinin (telefon uzayında) yüksekliği; sinyal bu hizadan çıkar.
  static const _phoneButtonY = 214.0;

  /// Kutu girişte bu kadar aşağıdan yükselir (tasarım birimi).
  static const boxRiseDistance = 30.0;

  /// Boşta yüzme genliği; periyot bir döngüdür (9 sn), yani DESIGN_SPEC §3'ün "≥ 8 sn" sınırının içinde.
  static const boxDriftAmplitude = 2.4;

  /// Tasarım boyutları: masaüstü 620x520 (şartname), mobil dikey.
  static const _wideDesign = Size(620, 520);
  static const _tallDesign = Size(360, 566);

  /// Kapının zemine bastığı çizginin kapı altına uzaklığı.
  static const _horizonBelowDoor = 2.0;

  final Size design;

  /// Kutu görselinin yerleştiği dikdörtgen (en-boy oranı görselinki).
  final Rect box;

  /// Kapı çerçevesinin dış dikdörtgeni.
  final Rect door;

  /// Telefonun yerindeki dikdörtgeni.
  final Rect phone;

  /// Telefon girişte bu kadar uzaktan gelir (phoneIn = 0 iken ofset) ve bu kadar eğik başlar (radyan).
  final Offset phoneFrom;
  final double phoneTilt;

  /// Sinyal eğrisi (kübik Bézier): başlangıç, iki kontrol noktası; bitiş her zaman LED'dir.
  final Offset signalStart;
  final Offset signalC1;
  final Offset signalC2;

  /// Ürünün arkasındaki stüdyo ışığının merkezi ve yarıçapı.
  final Offset glowCenter;
  final double glowRadius;

  /// Kapının zemine bastığı çizgi (uzak duvar-zemin birleşimi).
  final double horizonY;

  /// Kutu görselinin LED deliğinin tasarım koordinatı.
  Offset get led => _ledOf(box);

  static Offset _ledOf(Rect box) => box.topLeft + Offset(box.width * BoxAsset.ledBlue.dx, box.height * BoxAsset.ledBlue.dy);

  /// Kutunun o anki dikey ofseti: girişte aşağıdan yükselir, sonra çok hafif yüzer.
  Offset boxOffset(AdState s) => Offset(0, (1 - s.boxIn) * boxRiseDistance + s.drift * boxDriftAmplitude);

  static final StageGeometry wide = _buildWide();
  static final StageGeometry tall = _buildTall();

  static StageGeometry _buildWide() {
    const phoneScale = 0.92;
    final box = Rect.fromLTWH(4, 236, 356, 356 / BoxAsset.aspect);
    final phone = Rect.fromLTWH(452, 132, phoneBaseSize.width * phoneScale, phoneBaseSize.height * phoneScale);
    const door = Rect.fromLTWH(262, 26, 120, 190);
    final led = _ledOf(box);
    return StageGeometry._(
      design: _wideDesign,
      box: box,
      door: door,
      phone: phone,
      phoneFrom: const Offset(150, 36),
      phoneTilt: 0.05,
      // Telefonun sol kenarından çıkar, kutunun ön yüzüne sağdan girer.
      signalStart: Offset(phone.left + 6, phone.top + _phoneButtonY * phoneScale),
      signalC1: Offset(phone.left - 100, phone.top + 236 * phoneScale),
      signalC2: led + const Offset(154, 62),
      glowCenter: const Offset(240, 300),
      glowRadius: 300,
      horizonY: door.bottom + _horizonBelowDoor,
    );
  }

  static StageGeometry _buildTall() {
    const phoneScale = 0.84;
    final box = Rect.fromLTWH(26, 332, 308, 308 / BoxAsset.aspect);
    final phone = Rect.fromLTWH(14, 14, phoneBaseSize.width * phoneScale, phoneBaseSize.height * phoneScale);
    const door = Rect.fromLTWH(226, 24, 108, 170);
    final led = _ledOf(box);
    // Sinyal telefonun sağ kenarından, kapının ALTINDAN geçerek (kapıyla kesişmeden) LED'e iner.
    final start = Offset(phone.right - 4, phone.top + 246 * phoneScale);
    return StageGeometry._(
      design: _tallDesign,
      box: box,
      door: door,
      phone: phone,
      phoneFrom: const Offset(-120, 70),
      phoneTilt: -0.05,
      signalStart: start,
      signalC1: start + const Offset(114, -6),
      signalC2: led + const Offset(150, 30),
      glowCenter: const Offset(190, 340),
      glowRadius: 250,
      horizonY: door.bottom + _horizonBelowDoor,
    );
  }
}
