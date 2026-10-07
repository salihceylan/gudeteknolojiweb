import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Kameranın "ana poz"daki dönüş açısı (radyan, ≈ 40°).
///
/// Model ekseni (objektif yönü) bu açıda ekranın soluna ve öne bakar: objektif yüzü, ince lens kaplaması ve
/// IR LED halkası net okunur; gövde ve güneşlik sağa doğru uzaklaşarak ürünün uzun, zarif siluetini verir.
/// yaw = 0 → objektif doğrudan izleyiciye bakar; yaw arttıkça objektif sola döner; yaw = π → arkadan görünüm.
const double kCameraHomeYaw = 0.70;

/// Ana pozdaki bakış yüksekliği (radyan). Negatif: izleyici ürüne hafif aşağıdan bakar.
/// Pozitif pitch izleyicinin ürüne yukarıdan bakması demektir (üst yüzey ve güneşlik görünür).
const double kCameraHomePitch = -0.05;

/// [from] açısına en yakın "ana poz eşdeğeri" (kCameraHomeYaw + 2πk). Bırakılan ürünün başlangıç açısına
/// en kısa yoldan dönmesi için kullanılır.
double nearestHomeYaw(double from) {
  const tau = math.pi * 2;
  final k = ((from - kCameraHomeYaw) / tau).roundToDouble();
  return kCameraHomeYaw + k * tau;
}

/// Kameranın dönüş/ışık durumu. Painter bunu dinler; değer değişince yalnızca yeniden çizim olur
/// (widget ağacı yeniden kurulmaz).
///
/// * [yaw] / [pitch]: radyan. Sınırsızdır (yaw birden çok tur dönebilir); painter açıyı kendisi sarar.
/// * [lightPhase]: 0..2π. Ana ışığın / yansımanın çok yavaş kayması için (boşta mikro hareket).
/// * [scale]: ürünün kutu içindeki ölçeği (1 = kenarlardan pay bırakarak sığdırılmış boyut).
///
/// Sonlu olmayan (NaN, ∞) değerler yok sayılır; böylece hatalı bir yay hesabı çizimi bozamaz.
class CameraPose extends ChangeNotifier {
  CameraPose({
    double yaw = kCameraHomeYaw,
    double pitch = kCameraHomePitch,
    double lightPhase = 0,
    double scale = 1,
  })  : _yaw = yaw.isFinite ? yaw : kCameraHomeYaw,
        _pitch = pitch.isFinite ? pitch : kCameraHomePitch,
        _lightPhase = lightPhase.isFinite ? lightPhase : 0,
        _scale = scale.isFinite ? scale : 1;

  double _yaw;
  double _pitch;
  double _lightPhase;
  double _scale;

  double get yaw => _yaw;
  set yaw(double v) => set(yaw: v);

  double get pitch => _pitch;
  set pitch(double v) => set(pitch: v);

  double get lightPhase => _lightPhase;
  set lightPhase(double v) => set(lightPhase: v);

  double get scale => _scale;
  set scale(double v) => set(scale: v);

  /// Birden çok alanı tek seferde günceller; en az biri gerçekten değiştiyse tek bir bildirim gönderir.
  void set({double? yaw, double? pitch, double? lightPhase, double? scale}) {
    var changed = false;
    if (yaw != null && yaw.isFinite && yaw != _yaw) {
      _yaw = yaw;
      changed = true;
    }
    if (pitch != null && pitch.isFinite && pitch != _pitch) {
      _pitch = pitch;
      changed = true;
    }
    if (lightPhase != null && lightPhase.isFinite && lightPhase != _lightPhase) {
      _lightPhase = lightPhase;
      changed = true;
    }
    if (scale != null && scale.isFinite && scale != _scale) {
      _scale = scale;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Ana poza döner (yaw en yakın eşdeğer açıya, diğerleri varsayılana).
  void reset() => set(yaw: nearestHomeYaw(_yaw), pitch: kCameraHomePitch, lightPhase: 0, scale: 1);

  @override
  String toString() => 'CameraPose(yaw: ${_yaw.toStringAsFixed(3)}, pitch: ${_pitch.toStringAsFixed(3)}, '
      'lightPhase: ${_lightPhase.toStringAsFixed(3)}, scale: ${_scale.toStringAsFixed(3)})';
}
