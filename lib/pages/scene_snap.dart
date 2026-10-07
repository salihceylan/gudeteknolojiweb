import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/motion.dart';

/// Sahneler arasında çok hafif "mıknatıs" (soft snap) etkisi.
///
/// Kullanıcı kaydırmayı bıraktığında (dokunmatik: parmak/ivme bitince, fare tekerleği: ~140 ms sessizlik)
/// sayfa, en yakın sahne başlangıcına sert değil, yay eğrisiyle (küçük aşma) yerleşir. Kaydırma sırasında
/// hiçbir şey zorlanmaz. Eşikler oransal değil piksel cinsindendir: tek bir tekerlek çentiği (100-120 px)
/// ekran boyundan bağımsız olarak bir sonraki sahneye geçirmelidir.
///
/// Sahneler uzunluklarına göre üç davranıştan birini alır (bkz. [targetFor]):
/// ekrana sığanlar sayfalanır, ekranı az aşanlar sonu görüldükten sonra sayfalanır, uzun olanlar serbest gezilir.
class SceneSnap {
  SceneSnap({
    required this.controller,
    required this.anchors,
    required this.viewportHeight,
    this.reduceMotion = false,
    this.maxExtent,
  });

  /// Bir sonraki sahneye geçmek için yönde gereken en büyük ilerleme (px). Aralığın %12'si bundan küçükse o kullanılır.
  /// Tek çentik 100-120 px olduğundan geçer; elin titremesi ya da yanlışlıkla dokunuş geçmez.
  static const pullMax = 48.0;
  static const pullShare = 0.12;

  /// Sahne aralığı ekran yüksekliğinin bu katına kadarsa sahne tek sayfa sayılır (taşan kısım yalnızca boşluktur).
  static const pageRatio = 1.02;

  /// [pageRatio] ile bu kat arasındaki sahneler ekranı az aşar: son satırlarına inilebilir, sonu görüldükten sonra sayfalanır.
  /// Bunun üstündeki sahnelerin ortası serbesttir.
  static const overflowRatio = 1.5;

  /// Uzun sahnenin kenarlarında mıknatısın devreye girdiği bölge: ekranın %22'si, en çok [zoneMax] px.
  static const zoneShare = 0.22;
  static const zoneMax = 120.0;

  /// Klavye: ok tuşu adımı, sayfa tuşu adımı (ekranın %90'ı) ve sayfa adımının çapaya yaslanma erişimi.
  static const lineStep = 100.0;
  static const pageStep = 0.9;
  static const pageReach = 0.25;

  final ScrollController controller;

  /// Sahne başlangıçlarının kaydırma ofsetleri (artan sıralı). Her çağrıda güncel değerler dönmeli.
  final List<double> Function() anchors;
  final double Function() viewportHeight;

  /// Sayfanın en alt kaydırma ofseti; verilmezse denetleyiciden okunur (testlerde sabit verilebilir).
  final double Function()? maxExtent;

  /// "Hareketi azalt" açıksa mıknatıs kapanır, hedefe anında gidilir.
  bool reduceMotion;

  Timer? _timer;
  bool _animating = false;
  int _token = 0;
  int _dir = 0; // son kullanıcı kaydırma yönü: +1 aşağı, -1 yukarı
  bool _userMoved = false; // son yerleşmeden beri kullanıcı sayfayı gerçekten oynattı mı
  bool _wasOut = false; // bir önceki güncelleme aralık dışındaydı (iOS geri yaylanmasının son karesi)

  /// Sayfanın `NotificationListener` bileşenine `onNotification: snap.onNotification` olarak bağlanır.
  bool onNotification(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _timer?.cancel();
    } else if (n is ScrollUpdateNotification) {
      _timer?.cancel();
      // Kullanıcı bizim animasyonumuzu elinden devraldıysa (parmakla tutma) animasyon bitmiş sayılır.
      if (n.dragDetails != null) _animating = false;
      final d = n.scrollDelta ?? 0;
      // Sayfa başında ya da sonunda iOS'un geri yaylanması ters yönlü delta üretir; bu kullanıcının yönü değildir.
      final out = n.metrics.outOfRange;
      if (!_animating && d != 0 && !out && !_wasOut) {
        _dir = d > 0 ? 1 : -1;
        _userMoved = true;
      }
      _wasOut = out;
    } else if (n is ScrollEndNotification) {
      if (_animating) {
        // Kendi yerleşme animasyonumuzun sonu: yeniden yerleşmeye çalışma.
        _animating = false;
        _dir = 0;
        _userMoved = false;
      } else if (_userMoved) {
        // Hareketsiz bir bırakış (ör. sayfa sonunda boş sürükleme) hiçbir şeyi değiştirmemeli.
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 140), _settle);
      }
    }
    return false;
  }

  void _settle() {
    if (reduceMotion || !controller.hasClients) return;
    final pos = controller.position;
    if (pos.isScrollingNotifier.value) {
      _timer = Timer(const Duration(milliseconds: 100), _settle);
      return;
    }
    final target = pos.outOfRange ? null : targetFor(pos.pixels);
    _dir = 0;
    _userMoved = false;
    if (target == null || (target - pos.pixels).abs() < 1.5) return;
    scrollTo(target);
  }

  double get _max => maxExtent?.call() ?? (controller.hasClients ? controller.position.maxScrollExtent : double.infinity);

  /// Durak noktaları: ulaşılabilen sahne başlangıçları ve sayfanın dibi. Sayfa sonundan ötedeki çapalar
  /// (kısa son sahneler) ulaşılamaz; yerlerine sayfa dibi geçer.
  List<double> _stops() {
    final max = _max;
    final stops = <double>[];
    for (final a in anchors()) {
      if (a < max - 1 && (stops.isEmpty || a - stops.last > 1)) stops.add(a);
    }
    if (max.isFinite && (stops.isEmpty || max - stops.last > 1)) stops.add(max);
    return stops;
  }

  /// [y] konumunda bırakılırsa yerleşilecek ofset; mıknatıs devreye girmiyorsa null. [dir] verilmezse son
  /// kullanıcı kaydırma yönü kullanılır (+1 aşağı, -1 yukarı, 0 bilinmiyor).
  double? targetFor(double y, {int? dir}) {
    final a = _stops();
    if (a.length < 2) return null;
    final vh = viewportHeight();
    final d = dir ?? _dir;
    final zone = math.min(vh * zoneShare, zoneMax);
    var i = 0;
    while (i + 1 < a.length && a[i + 1] <= y) {
      i++;
    }
    final lo = a[i];
    if (i == a.length - 1) {
      // Son durak sayfanın dibidir (sayfa uzunluğu bilinmiyorsa son sahnenin başı): orada aşağı kaydırma, boş
      // sürükleme ya da geri yaylanma hiçbir şeyi değiştirmez. Yalnızca son sahnenin başına çok yakınken ve
      // gerçekten yukarı çekilirken yaslan.
      return !_max.isFinite && d < 0 && y - lo < zone ? lo : null;
    }
    final hi = a[i + 1];
    final gap = hi - lo;
    final pull = math.min(gap * pullShare, pullMax);

    if (gap <= vh * pageRatio) {
      // Tek ekranlık sahne: yönü gözeterek sahne başına yerleş.
      if (d > 0) return y - lo > pull ? hi : lo;
      if (d < 0) return hi - y > pull ? lo : hi;
      return y - lo < gap / 2 ? lo : hi;
    }
    if (gap <= vh * overflowRatio) {
      // Ekranı az aşan sahne: alt kısmı serbestçe görülebilir; sonu (hi - vh) görüldükten sonra bir miktar
      // daha ilerlenirse sonraki sahneye geçilir. Yukarı doğru sahnenin başına yaslanılır.
      if (d > 0) return y - (hi - vh) > pull ? hi : null;
      if (d < 0) return hi - y > pull ? lo : hi;
    }
    // Uzun bölüm: ortası serbest; yalnızca kenarlara yakınken ve yön uygunsa mıknatıs.
    if (y - lo < zone && d <= 0) return lo;
    if (hi - y < zone && d >= 0) return hi;
    return null;
  }

  /// [y] konumunun duraklar arasındaki yeri (kaçıncı çapa, sonrakine oranı). Pencere boyutu değişince aynı sahnede
  /// kalmak için kullanılır; ulaşılabilirlik süzmesi uygulanmaz, böylece indeksler yeniden yerleşimden sonra da geçerlidir.
  ({int index, double t}) locate(double y) {
    final a = anchors();
    if (a.isEmpty) return (index: 0, t: 0);
    var i = 0;
    while (i + 1 < a.length && a[i + 1] <= y) {
      i++;
    }
    final hi = i + 1 < a.length ? a[i + 1] : _max;
    final span = hi - a[i];
    return (index: i, t: span > 0 && span.isFinite ? ((y - a[i]) / span).clamp(0.0, 1.0) : 0.0);
  }

  /// [locate]'in tersi: güncel yerleşimde aynı sahne ve oranın ofseti.
  double offsetFor(({int index, double t}) at) {
    final a = anchors();
    if (a.isEmpty) return 0;
    final i = at.index.clamp(0, a.length - 1);
    final hi = i + 1 < a.length ? a[i + 1] : _max;
    final span = hi - a[i];
    return a[i] + (span > 0 && span.isFinite ? span * at.t : 0);
  }

  /// [target] ofsetine yay eğrisiyle kayar (menü bağlantıları ve mıknatıs yerleşmesi için).
  Future<void> scrollTo(double target) {
    if (!controller.hasClients) return Future.value();
    final pos = controller.position;
    final t = target.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    if (reduceMotion) {
      pos.jumpTo(t);
      return Future.value();
    }
    final dist = (t - pos.pixels).abs();
    final ms = (420 + dist * 0.42).clamp(520, 1100).round();
    final token = ++_token;
    _animating = true;
    return pos.animateTo(t, duration: Duration(milliseconds: ms), curve: const SpringCurve(damping: 0.8)).whenComplete(() {
      if (token == _token) _animating = false;
    });
  }

  /// Ok tuşları: [dir] yönünde [lineStep] kadar kısa ve yumuşak bir adım. Kullanıcı kaydırması sayıldığından
  /// bırakınca mıknatıs normal şekilde devreye girer.
  void scrollLine(int dir) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    final t = (pos.pixels + dir * lineStep).clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    if (reduceMotion) {
      pos.jumpTo(t);
    } else {
      pos.animateTo(t, duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic);
    }
  }

  /// PageUp/PageDown/Boşluk: ekranın %90'ı kadar ilerler; yakınında bir sahne başı varsa oraya yaslanır.
  Future<void> scrollPage(int dir) {
    if (!controller.hasClients) return Future.value();
    final y = controller.position.pixels;
    final vh = viewportHeight();
    var t = y + dir * vh * pageStep;
    var best = vh * pageReach;
    for (final a in _stops()) {
      final away = (a - y) * dir;
      final off = (a - t).abs();
      if (away > 1 && off < best) {
        best = off;
        t = a;
      }
    }
    return scrollTo(t);
  }

  void dispose() => _timer?.cancel();
}
