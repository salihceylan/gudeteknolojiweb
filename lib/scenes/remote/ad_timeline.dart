import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../core/motion.dart';

/// Zaman çizelgesinde bir aralık (saniye). Çizelgedeki her geçiş adlandırılmış bir aralıktır;
/// böylece şartnamedeki fazlar ([AdPhase]) ile kod arasında bire bir karşılık kalır.
@immutable
class AdSpan {
  const AdSpan(this.start, this.end);

  final double start;
  final double end;

  /// [t] bu aralıkta 0'dan 1'e doğrusal ilerler; öncesinde 0, sonrasında 1 kalır.
  double of(double t) => remap01(t, start, end);

  /// [of] üzerine smootherstep.
  double smooth(double t) => smooth01(of(t));

  /// [curve] ile eğrilmiş ilerleme.
  double curved(double t, Curve curve) => curve.transform(of(t));

  /// Yalnızca aralığın içinde (başı ve sonu hariç) ilerleyen, dışında 0 olan "pencere".
  /// Döngü başı ile sonu böylece aynı durumda kalır ve çizim "0 ya da 1 ise çizme" kuralıyla basit tutulur.
  double window(double t, Curve curve) => (t > start && t < end) ? curve.transform((t - start) / (end - start)) : 0.0;
}

/// Reklamın fazları (şartname §5.3). Saniye cinsindendir; bir döngü [AdTimeline.loop] sürer.
///
/// ```
/// 0.0–1.2  kutu belirir          1.2–2.4  telefon girer       2.4–3.1  dokunuş
/// 3.1–4.5  sinyal               4.5–5.0  LED + klik           5.0–7.0  kapı açılır, ✓
/// 7.0–8.4  bekleme              8.4–9.0  başa dönüş
/// ```
abstract final class AdPhase {
  // 0.0–1.2 Kutu belirir; kapı kapalı hâliyle sahnenin gerisinde görünür.
  static const boxRise = AdSpan(0.0, 1.2);
  static const boxFadeIn = AdSpan(0.0, 0.9);
  static const doorFadeIn = AdSpan(0.6, 1.2);
  static const sweep = AdSpan(0.3, 4.6);

  // 1.2–2.4 Telefon sağ-önden kayarak girer.
  static const phoneIn = AdSpan(1.2, 2.4);

  // 2.4–3.1 Parmak düğmeye iner, dokunma dalgası çıkar, düğme basılır, "Gönderiliyor…".
  static const fingerDown = AdSpan(2.4, 2.85);
  static const fingerUp = AdSpan(3.15, 3.6);
  static const pressDown = AdSpan(2.82, 2.95);
  static const pressUp = AdSpan(3.2, 3.55);
  static const tapRing = AdSpan(2.85, 3.45);

  // Düğme etiketleri art arda değişir (üst üste binmez): "KAPIYI AÇ" söner, sonra "Gönderiliyor…" belirir.
  static const idleOut = AdSpan(2.88, 3.0);
  static const sendingIn = AdSpan(3.0, 3.15);

  // 3.1–4.5 Telefondan LED'e sinyal darbeleri, varışta Wi-Fi yayları.
  static const signal = AdSpan(3.1, 4.5);
  static const arrive = AdSpan(4.1, 4.8);

  // 4.5–5.0 LED parlar, kısa klik halkası.
  static const ledUp = AdSpan(4.5, 5.0);
  static const ledSettle = AdSpan(5.0, 5.8);
  static const clickRing = AdSpan(4.55, 4.95);

  // 5.0–7.0 Kapı açılır; telefon "Kapı açıldı" ✓ gösterir.
  static const doorOpen = AdSpan(5.0, 7.0);
  static const sendingOut = AdSpan(5.15, 5.4);
  static const success = AdSpan(5.4, 5.85);
  static const check = AdSpan(5.45, 5.95);

  // 7.0–8.4 Bekleme: hiçbir geçiş yoktur (altyazılar senkron vurgulanır). 8.4–9.0 başa dönüş.
  static const exit = AdSpan(8.4, 9.0);
  static const exitBox = AdSpan(8.5, 9.0);
  static const exitBoxFade = AdSpan(8.55, 9.0);
  static const exitDoorFade = AdSpan(8.5, 8.9);

  /// Telefon çıkarken ekranı ✓ durumunda gider; "KAPIYI AÇ" durumuna dönüş, telefon neredeyse tamamen
  /// görünmez olduğunda (son 70 ms) yapılır. Böylece iki durum hiçbir zaman üst üste görünmez.
  static const screenReset = AdSpan(8.93, 9.0);
}

/// Reklam zaman çizelgesinin tek bir andaki normalize durumu. Tüm alanlar çizim katmanlarının
/// doğrudan kullanacağı değerlerdir (çoğu 0..1); çizim kodu zaman bilmez, yalnızca bu değerleri okur.
///
/// "Pencere" alanları ([sweep], [tapRing], [signalProgress], [arrive], [clickRing]) yalnızca kendi
/// aralığında (0,1) arası ilerler; aralığın dışında 0'dır.
@immutable
class AdState {
  const AdState({
    required this.boxIn,
    required this.boxOpacity,
    required this.doorIn,
    required this.sweep,
    required this.phoneIn,
    required this.tap,
    required this.buttonState,
    required this.idle,
    required this.sending,
    required this.tapRing,
    required this.signalProgress,
    required this.arrive,
    required this.ledGlow,
    required this.clickRing,
    required this.doorOpen,
    required this.success,
    required this.check,
    required this.captionStep,
    required this.drift,
  });

  /// Kutunun aşağıdan yükselme ilerlemesi (yay; hedefi hafifçe aşabilir).
  final double boxIn;

  /// Kutunun görünürlüğü.
  final double boxOpacity;

  /// Kapının sahnede görünürlüğü (kapalı hâliyle).
  final double doorIn;

  /// Kutu yüzeyindeki ışık süpürmesinin konumu (pencere).
  final double sweep;

  /// Telefonun girişi (yay; 1 = yerinde). Çıkışta 0'a döner.
  final double phoneIn;

  /// Parmak noktasının düğmeye yaklaşması (0 = uzakta, 1 = düğmede).
  final double tap;

  /// Düğmenin basılı olma derinliği.
  final double buttonState;

  /// "KAPIYI AÇ" etiketinin ağırlığı (ekran dinlenme durumunda 1).
  final double idle;

  /// "Gönderiliyor…" durumunun ağırlığı.
  final double sending;

  /// Dokunma dalgası halkası (pencere).
  final double tapRing;

  /// Sinyal darbelerinin telefondan LED'e ilerlemesi (pencere, ease uygulanmış).
  final double signalProgress;

  /// Kutuya varışta Wi-Fi yaylarının ilerlemesi (pencere).
  final double arrive;

  /// LED parlaklığı (varışta tepe yapar, sonra biraz oturur).
  final double ledGlow;

  /// Kısa "klik" halkası (pencere).
  final double clickRing;

  /// Kapının açıklığı (0 kapalı, 1 tam açık).
  final double doorOpen;

  /// Telefon ekranında "Kapı açıldı" durumunun ağırlığı (telefon çıkarken de 1 kalır, bkz. [AdPhase.screenReset]).
  final double success;

  /// ✓ işaretinin çizilme ilerlemesi.
  final double check;

  /// Altyazı adımı: 0 = hiçbiri, 1..3 = o adım vurgulu.
  final int captionStep;

  /// Kutunun çok hafif yüzmesi, -1..1. Periyodu döngüye eşit olduğundan sınırda kesinti olmaz.
  final double drift;

  /// Karşılaştırma ve testler için tüm sayısal değerler.
  List<double> get values => [
        boxIn, boxOpacity, doorIn, sweep, phoneIn, tap, buttonState, idle, sending, tapRing, signalProgress, arrive,
        ledGlow, clickRing, doorOpen, success, check, captionStep.toDouble(), drift,
      ];

  @override
  bool operator ==(Object other) => other is AdState && listEquals(values, other.values);

  @override
  int get hashCode => Object.hashAll(values);
}

/// Reklamın zaman çizelgesi. Saf fonksiyondur: aynı saniye her zaman aynı durumu verir.
abstract final class AdTimeline {
  /// Bir döngünün süresi (saniye).
  static const double loop = 9.0;

  /// Hareketi azalt açıkken gösterilen durağan kare: kapı açık, ✓ görünür, üç adım da anlaşılır.
  static const double restTime = 7.4;

  /// Kutunun yükselmesi ve telefonun girişi: hedefi ~%4 aşıp oturan yay (ζ ≈ 0.72, bkz. DESIGN_SPEC §3).
  static const _spring = SpringCurve();

  /// LED, varıştan sonra tepe değerinin bu oranına kadar oturur.
  static const _ledSettleDrop = 0.3;

  /// [time] saniyesindeki durum. [0, loop] dışı sıkıştırılır; döngüyü saran çağıran taraftır
  /// (böylece t=0 ve t=loop'un aynı duruma varması gerçekten sınanabilir).
  static AdState stateAt(double time) {
    final t = time.clamp(0.0, loop).toDouble();

    // Her şey döngü sonunda başlangıç durumuna yumuşakça döner.
    final exitBox = AdPhase.exitBox.smooth(t);
    final exitAll = AdPhase.exit.smooth(t);

    final boxIn = _spring.transform(AdPhase.boxRise.of(t)) * (1 - exitBox);
    final boxOpacity = AdPhase.boxFadeIn.smooth(t) * (1 - AdPhase.exitBoxFade.smooth(t));
    final doorIn = AdPhase.doorFadeIn.smooth(t) * (1 - AdPhase.exitDoorFade.smooth(t));

    final phoneIn = _spring.transform(AdPhase.phoneIn.of(t)) * (1 - exitAll);

    // Parmak: hızlı yaklaşır (easeOut), dokunuştan sonra çekilir.
    final tap = AdPhase.fingerDown.curved(t, Curves.easeOutCubic) * (1 - AdPhase.fingerUp.smooth(t));
    final press = AdPhase.pressDown.smooth(t) * (1 - AdPhase.pressUp.smooth(t));
    final sending = AdPhase.sendingIn.smooth(t) * (1 - AdPhase.sendingOut.smooth(t));
    final screenReset = AdPhase.screenReset.smooth(t);
    final idle = math.max(1 - AdPhase.idleOut.smooth(t), screenReset);

    final ledUp = AdPhase.ledUp.curved(t, Curves.easeOutCubic);
    final ledSettle = 1 - _ledSettleDrop * AdPhase.ledSettle.smooth(t);
    final ledGlow = ledUp * ledSettle * (1 - exitAll);

    final doorOpen = AdPhase.doorOpen.curved(t, Curves.easeInOutCubic) * (1 - exitAll);

    final success = AdPhase.success.smooth(t) * (1 - screenReset);
    final check = AdPhase.check.curved(t, Curves.easeOutCubic) * (1 - screenReset);

    // Döngü fazı 0..1; t = loop iken tam 0'a sarılır, böylece t=0 ile t=loop birebir aynı durumdadır.
    final cycle = (t / loop) % 1.0;

    return AdState(
      boxIn: boxIn,
      boxOpacity: boxOpacity,
      doorIn: doorIn,
      sweep: AdPhase.sweep.window(t, Curves.easeInOutSine),
      phoneIn: phoneIn,
      tap: tap,
      buttonState: press,
      idle: idle,
      sending: sending,
      tapRing: AdPhase.tapRing.window(t, Curves.easeOutCubic),
      signalProgress: AdPhase.signal.window(t, Curves.easeInOutSine),
      arrive: AdPhase.arrive.window(t, Curves.easeOutCubic),
      ledGlow: ledGlow,
      clickRing: AdPhase.clickRing.window(t, Curves.easeOutCubic),
      doorOpen: doorOpen,
      success: success,
      check: check,
      captionStep: _captionStep(t),
      drift: math.sin(2 * math.pi * cycle),
    );
  }

  /// Altyazı adımı: dokunuş (2.4–3.1), sinyal (3.1–5.0), kapı (5.0–8.4); diğer zamanlarda hiçbiri.
  static int _captionStep(double t) {
    if (t < AdPhase.fingerDown.start) return 0;
    if (t < AdPhase.signal.start) return 1;
    if (t < AdPhase.doorOpen.start) return 2;
    if (t < AdPhase.exit.start) return 3;
    return 0;
  }
}

/// Reklamın saati: [time] ilerledikçe [value] güncellenir ve dinleyenler çizim katmanlarıdır.
/// Widget ağacı yeniden kurulmaz; yalnızca CustomPainter'lar yeniden boyanır.
class AdClock extends ChangeNotifier implements ValueListenable<AdState> {
  AdClock([double time = 0])
      : _time = time,
        _state = AdTimeline.stateAt(time),
        step = ValueNotifier<int>(AdTimeline.stateAt(time).captionStep);

  double _time;
  AdState _state;

  /// Altyazı adımı; yalnızca adım değiştiğinde bildirir (altyazı satırı kareler boyunca yeniden kurulmaz).
  final ValueNotifier<int> step;

  /// Döngü içindeki saniye.
  double get time => _time;

  set time(double v) {
    _time = v;
    _state = AdTimeline.stateAt(v);
    step.value = _state.captionStep;
    notifyListeners();
  }

  /// Döngüyü saran ilerletme.
  void advance(double dt) => time = (_time + dt) % AdTimeline.loop;

  @override
  AdState get value => _state;

  @override
  void dispose() {
    step.dispose();
    super.dispose();
  }
}
