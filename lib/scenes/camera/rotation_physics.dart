import 'dart:math' as math;

import '../../camera3d/camera_pose.dart';
import '../../core/motion.dart';

/// Ürünün dönüş durumu.
enum RotationPhase {
  /// Ana pozda; yalnızca çok küçük boşta salınım var.
  rest,

  /// Kullanıcı tutup sürüklüyor: açı doğrudan parmak/fareyi izler.
  dragging,

  /// Bırakıldı; açısal hız sürtünmeyle üstel olarak sönüyor (momentum).
  coasting,

  /// Klavye ile döndürüldü; hedef açıda kısa süre bekler, sonra ana poza döner.
  holding,

  /// Yay fiziğiyle ana poza (en yakın eşdeğer açıya) dönüyor.
  returning,
}

/// 360° dönen ürünün fiziği. Widget'tan bağımsızdır, yalnızca sayı üretir (birim testi kolay).
///
/// Akış: sürükleme → bırakma → momentum (hız üstel söner) → hız eşiğin altına inince yay (ζ≈0.65) başlar ve
/// ürün ana poza **en kısa yoldan** döner (birden çok tur atıldıysa geri sarmaz; açı farkı 2π'nin katlarıyla
/// en yakın eşdeğer ana poza indirgenir), hedefi hafif aşıp oturur. Anında atlama yoktur.
class RotationPhysics {
  RotationPhysics({
    this.dragSign = -1,
    this.maxOmega = 10,
    this.halfLife = 0.35,
    this.handoffOmega = 1.1,
    this.minFlingOmega = 0.45,
    this.holdSeconds = 2.4,
    this.idleYawAmplitude = 5 * math.pi / 180,
    this.idleYawPeriod = 14,
    this.idlePitchAmplitude = 1.5 * math.pi / 180,
    this.idlePitchPeriod = 9,
  }) : _spring = Spring1D(x: kCameraHomeYaw, stiffness: _stiffness, damping: 2 * _damping * math.sqrt(_stiffness));

  /// Yay sertliği ve sönüm oranı (ζ). ζ=0.65 → hedefi yaklaşık %7 aşar; 1–2 küçük salınımla oturur.
  static const _stiffness = 24.0;
  static const _damping = 0.65;

  /// Parmak/fare sağa giderken ürünün ön yüzü de sağa dönsün (yaw azalır).
  final double dragSign;

  /// Açısal hız üst sınırı (rad/sn). Sert bir fırlatmada bile ürün çılgınca dönmez.
  final double maxOmega;

  /// Momentumun yarı ömrü (sn): hız her [halfLife] saniyede yarıya iner.
  final double halfLife;

  /// Hız bu değerin altına inince yay devralır (hız ve konum süreklidir, sıçrama olmaz).
  final double handoffOmega;

  /// Bırakma hızı bundan küçükse momentum atlanır, yay hemen başlar.
  final double minFlingOmega;

  /// Klavye döndürmesinden sonra ana poza dönmeden önce beklenen süre (sn).
  final double holdSeconds;

  /// Boşta salınım (şartname: yaw ±5° / ~14 sn, pitch ±1.5° / ~9 sn).
  final double idleYawAmplitude;
  final double idleYawPeriod;
  final double idlePitchAmplitude;
  final double idlePitchPeriod;

  final Spring1D _spring;

  RotationPhase _phase = RotationPhase.rest;
  double _omega = 0;
  double _time = 0;
  double _idleBlend = 0;
  double _restHome = kCameraHomeYaw;
  double _holdTarget = kCameraHomeYaw;
  double _holdLeft = 0;
  bool _reduceMotion = false;

  /// Güncel yaw (radyan, sınırsız: birden çok tur dönebilir).
  double get yaw => _spring.x;

  /// Momentum sırasındaki açısal hız (rad/sn); diğer evrelerde yay hızı.
  double get omega => _phase == RotationPhase.coasting ? _omega : _spring.v;

  RotationPhase get phase => _phase;

  /// Yay şu an hangi açıya gidiyor.
  double get target => _spring.target;

  /// 0..1: boşta salınımın ne kadarının uygulandığı. Etkileşimde hızla 0'a iner, dinlenmede yavaşça 1'e çıkar.
  double get idleBlend => _idleBlend;

  /// Kare üretmek gerekiyor mu? Dinlenmedeyken yalnızca boşta salınım için gerekir (hareketi azalt açıkken gerekmez).
  bool get needsFrames => _phase != RotationPhase.rest || !_reduceMotion;

  /// Etkileşim sürüyor mu (sürükleme, momentum, dönüş, bekleme)?
  bool get isInteracting => _phase != RotationPhase.rest;

  /// Boşta salınımın o anki pitch katkısı (radyan).
  double get idlePitch => _reduceMotion ? 0 : _idleBlend * idlePitchAmplitude * math.sin(2 * math.pi * _time / idlePitchPeriod + 1.3);

  /// Hareketi azalt: boşta salınım ve momentum kapanır, ana poza dönüş anlık olur.
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool v) {
    if (v == _reduceMotion) return;
    _reduceMotion = v;
    if (v) {
      _idleBlend = 0;
      if (_phase == RotationPhase.coasting || _phase == RotationPhase.returning) _snapHome();
    }
  }

  /// Doğrudan yaw verir (örn. başlangıç ya da test).
  void reset({double? yaw}) {
    _spring
      ..x = yaw ?? kCameraHomeYaw
      ..v = 0;
    _spring.target = nearestHomeYaw(_spring.x);
    _restHome = _spring.target;
    _omega = 0;
    _holdLeft = 0;
    _phase = RotationPhase.rest;
  }

  // ---- Sürükleme ----------------------------------------------------------------------------------------------

  /// Sürükleme başladı: yay ve momentum hemen devredilir, açı doğrudan kullanıcıyı izler.
  void dragStart() {
    _phase = RotationPhase.dragging;
    _omega = 0;
    _spring.v = 0;
    _holdLeft = 0;
  }

  /// Parmak/fare [dx] piksel hareket etti; [radPerPx] bir pikselin kaç radyan döndürdüğü.
  void dragUpdate(double dx, double radPerPx) {
    if (_phase != RotationPhase.dragging) dragStart();
    _spring.x += dragSign * dx * radPerPx;
    _spring.v = 0;
  }

  /// Sürükleme bitti. [pixelVelocity]: bırakma anındaki yatay hız (px/sn; Flutter'ın hız izleyicisi son ~100 ms'lik
  /// örneklerden hesaplar). Yeterince hızlıysa momentum başlar, değilse yay hemen devralır.
  void dragEnd(double pixelVelocity, double radPerPx) {
    if (_phase != RotationPhase.dragging) return;
    final w = (dragSign * pixelVelocity * radPerPx).clamp(-maxOmega, maxOmega).toDouble();
    if (_reduceMotion) {
      _snapHome();
    } else if (w.abs() < minFlingOmega) {
      _startReturn();
    } else {
      _omega = w;
      _phase = RotationPhase.coasting;
    }
  }

  /// Sürükleme iptal edildi (ör. işaretçi iptali): hızsız bırakma gibi davranır.
  void dragCancel() {
    if (_phase != RotationPhase.dragging) return;
    if (_reduceMotion) {
      _snapHome();
    } else {
      _startReturn();
    }
  }

  // ---- Klavye -------------------------------------------------------------------------------------------------

  /// Klavye ile [delta] radyan döndür: yay hedef açıya gider, kısa süre bekler, sonra ana poza döner.
  void nudge(double delta) {
    if (_phase == RotationPhase.dragging) return;
    final base = _phase == RotationPhase.holding ? _holdTarget : _spring.x;
    _holdTarget = base + delta;
    _holdLeft = holdSeconds;
    _omega = 0;
    _phase = RotationPhase.holding;
    _spring.target = _holdTarget;
    if (_reduceMotion) {
      _spring
        ..x = _holdTarget
        ..v = 0;
    }
  }

  // ---- Zaman adımı --------------------------------------------------------------------------------------------

  /// [dt] saniye ilerlet. Karede bir kez çağrılır.
  void step(double dt) {
    if (dt <= 0) return;
    _time += dt;
    switch (_phase) {
      case RotationPhase.dragging:
        _blendIdle(dt, 0);
      case RotationPhase.coasting:
        _blendIdle(dt, 0);
        _stepCoast(dt);
      case RotationPhase.holding:
        _blendIdle(dt, 0);
        _spring.step(dt);
        _holdLeft -= dt;
        if (_holdLeft <= 0) _startReturn();
      case RotationPhase.returning:
        _blendIdle(dt, 0);
        _spring.step(dt);
        if ((_spring.x - _spring.target).abs() < 0.0035 && _spring.v.abs() < 0.02) {
          _spring
            ..x = _spring.target
            ..v = 0;
          _restHome = _spring.target;
          _phase = RotationPhase.rest;
        }
      case RotationPhase.rest:
        _blendIdle(dt, _reduceMotion ? 0 : 1);
        _spring.target = _restHome + _idleBlend * _idleYawOffset;
        _spring.step(dt);
    }
  }

  double get _idleYawOffset => idleYawAmplitude * math.sin(2 * math.pi * _time / idleYawPeriod);

  void _blendIdle(double dt, double goal) {
    // Etkileşimde salınım hızla (~0.25 sn) kesilir, dinlenmede yavaşça (~2 sn) geri gelir.
    final rate = goal > _idleBlend ? dt / 2.0 : dt / 0.25;
    if (goal > _idleBlend) {
      _idleBlend = math.min(goal, _idleBlend + rate);
    } else {
      _idleBlend = math.max(goal, _idleBlend - rate);
    }
  }

  void _stepCoast(double dt) {
    // ω(t) = ω0 · 2^(-t/yarıömür): kare süresinden bağımsız, tam çözümle ilerletilir.
    final lambda = math.ln2 / halfLife;
    final next = _omega * math.exp(-lambda * dt);
    _spring.x += (_omega - next) / lambda;
    _omega = next;
    if (_omega.abs() < handoffOmega) {
      // Yay, momentumun bıraktığı konum ve hızla devralır: süreklilik bozulmaz.
      _spring.v = _omega;
      _startReturn(keepVelocity: true);
    }
  }

  void _startReturn({bool keepVelocity = false}) {
    if (_reduceMotion) {
      _snapHome();
      return;
    }
    if (!keepVelocity) _spring.v = 0;
    _spring.target = nearestHomeYaw(_spring.x);
    _holdLeft = 0;
    _omega = 0;
    _phase = RotationPhase.returning;
  }

  void _snapHome() {
    _spring
      ..x = nearestHomeYaw(_spring.x)
      ..v = 0;
    _spring.target = _spring.x;
    _restHome = _spring.x;
    _omega = 0;
    _holdLeft = 0;
    _phase = RotationPhase.rest;
  }
}
