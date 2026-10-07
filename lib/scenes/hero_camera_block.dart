import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/core.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'iris/iris_cover_painter.dart';
import 'iris/iris_geometry.dart';
import 'iris/iris_motion.dart';
import 'iris/lens_art.dart';
import 'iris/scroll_hint.dart';

/// Açılış sahnesi + açılış → kamera "iris" geçişi.
///
/// Blok kaydırma alanının ilk çocuğudur. Sahne (stage) ilk [transitionDistance] kadar kaydırma boyunca
/// ekranın tepesine sabitlenir; bu sürede kaydırma ilerlemesi lensin diyaframını açar ve kullanıcı
/// lensin içinden geçerek altındaki kamera sahnesine girer. Sonra sahne normal şekilde kayar.
class HeroCameraBlock extends StatefulWidget {
  const HeroCameraBlock({super.key, required this.cameraBuilder, required this.onExplore, required this.onContact});

  /// Kamera sahnesi; geçiş ilerledikçe `reveal` 0→1 olur (kaydırma ile oynatılır, kendi zamanı yoktur).
  final Widget Function(BuildContext context, ValueListenable<double> reveal) cameraBuilder;
  final VoidCallback onExplore; // "Kamera Sistemlerini Keşfedin"
  final VoidCallback onContact; // "Bize Ulaşın"

  /// Sabitlenmiş sahnenin kaydırma mesafesi.
  static double transitionDistance(double viewportHeight) => viewportHeight * 0.95;

  /// Bloğun toplam yüksekliği = viewport + geçiş mesafesi.
  static double totalHeight(double viewportHeight) => viewportHeight + transitionDistance(viewportHeight);

  @override
  State<HeroCameraBlock> createState() => _HeroCameraBlockState();
}

class _HeroCameraBlockState extends State<HeroCameraBlock> with SingleTickerProviderStateMixin {
  /// Kaydırma ilerlemesi p = (offset / D).clamp(0, 1). Çizici ve opaklıklar bunu dinler.
  final _progress = ValueNotifier<double>(0);

  /// Kamera sahnesine verilen reveal.
  final _reveal = ValueNotifier<double>(0);

  /// Sahnenin tepeye sabitlenme kayması: offset.clamp(0, D).
  final _pin = ValueNotifier<double>(0);

  /// Kamera sahnesi p >= 0.98 iken etkileşime açıktır; üst katman o zaman hiç çizilmez.
  final _cameraLive = ValueNotifier<bool>(false);

  /// Açılış metni solarken (p < [IrisChoreography.textInteractiveEnd]) etkileşime açıktır.
  final _textActive = ValueNotifier<bool>(true);

  final _motion = IrisMotion();
  final _art = LensArt();
  final _parallaxX = Spring1D(stiffness: 36)..dampingRatio = 0.85;
  final _parallaxY = Spring1D(stiffness: 36)..dampingRatio = 0.85;
  late final FrameLoop _loop;

  ScrollController? _controller;
  double _viewportHeight = 0;
  bool _reduceMotion = false;
  Size _stageSize = Size.zero;
  double _acc = 0;

  /// Mikro hareketlerin saati (sn). Döngü durup yeniden başlasa da sıfırlanmaz; yoksa ışık yansıması ve
  /// nabız her yeniden başlamada başa atlardı.
  double _clock = 0;

  @override
  void initState() {
    super.initState();
    _loop = FrameLoop(this, _onFrame);
    // Kaydırma alanı ilk karede bağlanır; başlangıç konumu sıfır değilse (ör. geri yükleme) ilerleme eşitlenir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncScroll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ScrollScope.of(context);
    if (scope.controller != _controller) {
      _controller?.removeListener(_syncScroll);
      _controller = scope.controller..addListener(_syncScroll);
    }
    _viewportHeight = scope.viewportHeight;
    final reduce = reduceMotionOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      if (reduce) {
        // Boşta hareketler ve paralaks kapanır; yaylar da sıfırlanır, böylece hareket yeniden açılırsa atlama olmaz.
        _parallaxX.x = _parallaxX.target = _parallaxX.v = 0;
        _parallaxY.x = _parallaxY.target = _parallaxY.v = 0;
        _clock = 0;
        _motion.update(time: 0, dx: 0, dy: 0);
      }
    }
    _syncScroll();
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncScroll);
    _loop.dispose();
    _art.dispose();
    _progress.dispose();
    _reveal.dispose();
    _pin.dispose();
    _cameraLive.dispose();
    _textActive.dispose();
    _motion.dispose();
    super.dispose();
  }

  /// Kaydırma konumundan p, reveal ve sabitlenme kaymasını türetir; yalnızca değişenler bildirilir.
  void _syncScroll() {
    final c = _controller;
    final d = HeroCameraBlock.transitionDistance(_viewportHeight);
    // `controller.position` birden çok konum bağlıysa hata verir; ilk (ana) konum yeterli.
    final offset = (c != null && c.hasClients) ? c.positions.first.pixels : 0.0;
    final p = d <= 0 ? 1.0 : (offset / d).clamp(0.0, 1.0);
    _pin.value = offset.clamp(0.0, d);
    _progress.value = p;
    _reveal.value = IrisChoreography.reveal(p);
    _cameraLive.value = p >= IrisChoreography.coverEnd;
    _textActive.value = p < IrisChoreography.textInteractiveEnd;
    _updateLoop();
  }

  /// Mikro hareketler yalnızca açılış görünürken (p < 0.9) ve hareket azaltılmamışken çalışır.
  void _updateLoop() {
    final run = !_reduceMotion && _progress.value < 0.9;
    if (run) {
      _loop.start();
    } else {
      _loop.stop();
    }
  }

  void _onFrame(double dt, double _) {
    // Çok yavaş hareketler için 30 kare yeter; fare paralaksı sürerken tam hızda çizilir.
    final moving = !_parallaxX.settled || !_parallaxY.settled;
    _acc += dt;
    if (!moving && _acc < 0.030) return;
    final step = _acc;
    _acc = 0;
    _clock += step;
    _parallaxX.step(step);
    _parallaxY.step(step);
    _motion.update(time: _clock, dx: _parallaxX.x, dy: _parallaxY.x);
  }

  void _onHover(PointerHoverEvent e) {
    if (_reduceMotion || _stageSize.isEmpty || _progress.value > 0.5) return;
    final nx = (e.localPosition.dx / _stageSize.width * 2 - 1).clamp(-1.0, 1.0);
    final ny = (e.localPosition.dy / _stageSize.height * 2 - 1).clamp(-1.0, 1.0);
    _parallaxX.target = nx * 6;
    _parallaxY.target = ny * 6;
  }

  void _onExit(PointerExitEvent e) {
    _parallaxX.target = 0;
    _parallaxY.target = 0;
  }

  @override
  Widget build(BuildContext context) {
    final vh = _viewportHeight;
    return SizedBox(
      width: double.infinity,
      height: HeroCameraBlock.totalHeight(vh),
      child: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<double>(
          valueListenable: _pin,
          builder: (context, dy, child) => Transform.translate(offset: Offset(0, dy), child: child),
          child: SizedBox(height: vh, width: double.infinity, child: LayoutBuilder(builder: _buildStage)),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context, BoxConstraints box) {
    final size = box.biggest;
    _stageSize = size;
    final c = context.colors;
    final layout = IrisLayout.compute(size, mobileTextBottom: IrisLayout.isWideSize(size) ? 0 : _HeroText.measureMobileBottom(context, size));
    final painter = IrisCoverPainter(progress: _progress, motion: _motion, layout: layout, art: _art, colors: c);
    final mouse = layout.wide && !_reduceMotion;
    // Çok kısa ekranda (yatay telefon) ipucuna yer yok: metin sütununa binerdi.
    final showHint = size.height >= 520;

    final stage = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // 1) Kamera sahnesi. p < 0.98 iken pointer olaylarına, klavye odağına ve ekran okuyucuya kapalı (üst
        //    katmanın arkasında görünmez bir kontrole Tab ile gidilmesin, okuyucu görünmeyeni okumasın). Altındaki zemin, sahne yüklenirken ya da saydam
        //    kaldığında üst katmanın zemin rengiyle uyumlu kalır (c.stage).
        Positioned.fill(child: ColoredBox(color: c.stage)),
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: _cameraLive,
            builder: (context, live, child) => ExcludeFocus(
              excluding: !live,
              child: ExcludeSemantics(excluding: !live, child: IgnorePointer(ignoring: !live, child: child)),
            ),
            child: widget.cameraBuilder(context, _reveal),
          ),
        ),
        // 2) Üst katman: zemin + lens; açıklık kesilmiştir. p >= 0.98 iken ağaçtan çıkar, hiç çizilmez.
        Positioned.fill(
          child: ValueListenableBuilder<bool>(
            valueListenable: _cameraLive,
            builder: (context, live, _) {
              if (live) return const SizedBox.shrink();
              return ExcludeSemantics(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(key: const ValueKey('hero_iris_cover'), painter: painter, size: Size.infinite),
                  ),
                ),
              );
            },
          ),
        ),
        // 3) Açılış metni ve düğmeler. Hızla solar, paralaksla yukarı kayar; p > 0.3 iken kapalı.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, child) {
              final p = _progress.value;
              return Opacity(
                opacity: IrisChoreography.textOpacity(p),
                child: Transform.translate(offset: Offset(0, -IrisChoreography.textLift(p)), child: child),
              );
            },
            child: ValueListenableBuilder<bool>(
              valueListenable: _textActive,
              builder: (context, active, child) => ExcludeFocus(
                excluding: !active,
                child: ExcludeSemantics(excluding: !active, child: IgnorePointer(ignoring: !active, child: child)),
              ),
              child: RepaintBoundary(child: _HeroText(layout: layout, onExplore: widget.onExplore, onContact: widget.onContact)),
            ),
          ),
        ),
        // 4) Kaydırma ipucu.
        if (showHint)
          Positioned(
            left: 0,
            right: 0,
            bottom: layout.wide ? 28 : 20,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, child) => Opacity(opacity: IrisChoreography.hintOpacity(_progress.value), child: child),
                child: Center(child: ScrollHint(motion: _motion, animated: !_reduceMotion)),
              ),
            ),
          ),
      ],
    );

    if (!mouse) return stage;
    return MouseRegion(hitTestBehavior: HitTestBehavior.translucent, onHover: _onHover, onExit: _onExit, child: stage);
  }
}

/// Açılış metni: eyebrow, başlık, gövde ve iki düğme. Masaüstünde sol sütun; mobilde üstte.
class _HeroText extends StatelessWidget {
  const _HeroText({required this.layout, required this.onExplore, required this.onContact});

  final IrisLayout layout;
  final VoidCallback onExplore;
  final VoidCallback onContact;

  static const _title = 'Gelecek sizin elinizde.';
  static const _lead = 'Zayıf akım ve teknoloji sistemlerinde keşiften servise, uçtan uca profesyonel çözümler.';
  static const _explore = 'Kamera Sistemlerini Keşfedin';
  static const _contact = 'Bize Ulaşın';

  /// Mobil yerleşimde metin bloğunun alt kenarı (piksel). Lens bunun altına yerleştirilir; ölçüm gerçek
  /// yazı stilleri ve metin ölçeğiyle yapıldığından küçük ekranlarda lens düğmelerin üstüne binmez.
  static double measureMobileBottom(BuildContext context, Size size) {
    final avail = size.width - 2 * fluid(context, 24, 40);
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style; // Text, stili bununla birleştirir (ör. harf aralığı miras kalır)
    final tp = TextPainter(textDirection: TextDirection.ltr, textScaler: scaler);
    Size measure(String text, TextStyle style, double maxWidth) {
      tp.text = TextSpan(text: text, style: base.merge(style));
      tp.layout(maxWidth: maxWidth);
      return tp.size;
    }

    final title = measure(_title, AppText.display(context), avail).height;
    final lead = measure(_lead, AppText.body(context), math.min(440, avail)).height;
    final w1 = 44 + 24 + measure(_explore, AppText.buttonOf(context), double.infinity).width;
    final w2 = 44 + measure(_contact, AppText.buttonOf(context), double.infinity).width;
    tp.dispose();
    final buttons = w1 + 12 + w2 <= avail ? 44.0 : 44.0 + 12 + 44;
    final natural = 14 + 14 + title + 14 + lead + 24 + buttons;
    return 96 + math.min(natural, _mobileMaxTextHeight(size));
  }

  /// Mobilde metin bloğunun en çok yüksekliği: altta lens için en az ~300 px kalır. Büyük yazı
  /// boyutlarında blok bu yüksekliğe orantılı küçülür (kırpılmaz, taşmaz).
  static double _mobileMaxTextHeight(Size size) => math.max(200.0, size.height - 96 - 300);

  @override
  Widget build(BuildContext context) {
    final wide = layout.wide;
    final width = layout.size.width;
    final pad = fluid(context, 24, 40);
    final contentLeft = (width - math.min(width, kMaxContent)) / 2 + pad;

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Eyebrow büyük harfe çevirirken Türkçe "İ"yi bilmez; bu yüzden metin zaten büyük yazıldı.
        const Eyebrow('GÜDE TEKNOLOJİ'),
        SizedBox(height: wide ? 20 : 14),
        Semantics(header: true, child: Text(_title, style: AppText.display(context))),
        SizedBox(height: wide ? 20 : 14),
        const Lead(_lead, maxWidth: 440),
        SizedBox(height: wide ? 32 : 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Düğmeler küçültülmez (44 px hit alanı korunur); sığmazsa Wrap alt satıra alır.
            PillButton(label: _explore, icon: Icons.arrow_downward_rounded, onTap: onExplore),
            PillButton(label: _contact, filled: false, onTap: onContact),
          ],
        ),
      ],
    );

    if (wide) {
      // Sütun lensin soluna kadar uzanır, ona değmez.
      final lensLeft = layout.center.dx - layout.radius;
      final colWidth = math.max(280.0, math.min(480.0, lensLeft - contentLeft - 24));
      return Padding(
        padding: EdgeInsets.only(top: 72, bottom: 48, left: contentLeft),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: SizedBox(width: colWidth, child: column)),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: 96, left: pad, right: pad),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: _mobileMaxTextHeight(layout.size)),
          child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topLeft, child: SizedBox(width: width - 2 * pad, child: column)),
        ),
      ),
    );
  }
}
