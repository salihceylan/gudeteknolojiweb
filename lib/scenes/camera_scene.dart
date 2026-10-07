import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../camera3d/camera_pose.dart';
import '../core/core.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'camera/camera_layout.dart';
import 'camera/camera_stage_painters.dart';
import 'camera/product_layer.dart';
import 'camera/rotation_physics.dart';

/// Kamera Sistemleri sahnesi: tek bir kaliteli ürün (kodla üretilen kamera), basılı tutup sürükleyince 360° döner.
///
/// * Bırakınca momentum (sürtünmeyle sönen), sonra yay fiziğiyle başlangıç açısına dönüş ([RotationPhysics]).
/// * Mobilde yalnızca yatay sürükleme ürünü döndürür; dikey sürükleme sayfayı kaydırmaya devam eder.
/// * Klavyede ←/→ ürünü 15° döndürür; ürün odaklanabilir ve anlamlı bir etiketi vardır.
/// * Giriş: [reveal] 0→1 (kaydırma ile oynatılır, kendi zamanı yoktur). Önce boş stüdyo zemini, sonra ürün
///   ölçek/opaklıkla belirir, yazılar gecikmeli gelir; reveal 1 olunca sahne dinlenme durumundadır.
class CameraScene extends StatefulWidget {
  const CameraScene({super.key, required this.reveal}); // reveal: 0→1 (açıklıktan görünme); 1 = tam görünür, serbest etkileşim

  final ValueListenable<double> reveal;

  @override
  State<CameraScene> createState() => CameraSceneState();
}

/// Sahnenin durumu. Genel olmasının tek nedeni testlerin pozu ve fiziği okuyabilmesidir.
class CameraSceneState extends State<CameraScene> with SingleTickerProviderStateMixin {
  /// reveal bu değerin altındayken ürün jestlere kapalıdır (hero bloğu da p < 0.98 iken pointer'ı keser).
  static const double liveThreshold = 0.98;

  /// Klavye ile bir basışta dönülen açı.
  static const double keyStep = 15 * math.pi / 180;

  static const _label = 'Kamera ürünü. Sürükleyerek veya ok tuşlarıyla döndürülebilir.';

  final CameraPose _pose = CameraPose();
  final RotationPhysics _physics = RotationPhysics();
  late final FrameLoop _loop;
  final FocusNode _focus = FocusNode(debugLabel: 'Kamera ürünü');

  final ValueNotifier<bool> _dragging = ValueNotifier(false);
  final ValueNotifier<bool> _focusRing = ValueNotifier(false);

  /// Çizgi-notlarının görünürlüğü (0..1): ürün ana pozdan döndükçe solar ([noteVisibilityForYaw]).
  final ValueNotifier<double> _noteFade = ValueNotifier(1);

  /// İpucu yayındaki noktanın saati (sn). Yalnızca ipucu görünürken ilerler.
  final ValueNotifier<double> _hintPhase = ValueNotifier(0);

  bool _hintGone = false;

  /// Son odak işaretçiyle (tıklama) mi geldi? O zaman odak halkası çizilmez (yalnızca klavye odağında görünür).
  bool _pointerFocus = false;
  bool _visible = true;
  bool _reduceMotion = false;
  double _radPerPx = 0.005;
  double _acc = 0;
  double _light = 0;

  // Painter, yalnızca girdileri değişince yeniden kurulur.
  CustomPainter? _painter;
  Object? _painterKey;

  @visibleForTesting
  CameraPose get debugPose => _pose;

  @visibleForTesting
  RotationPhysics get debugPhysics => _physics;

  @visibleForTesting
  bool get debugLoopRunning => _loop.isRunning;

  @visibleForTesting
  bool get debugHintGone => _hintGone;

  @visibleForTesting
  bool get debugFocusRingVisible => _focusRing.value;

  @visibleForTesting
  double get debugNoteFade => _noteFade.value;

  @override
  void initState() {
    super.initState();
    _loop = FrameLoop(this, _onFrame);
    widget.reveal.addListener(_onReveal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncLoop();
    });
  }

  @override
  void didUpdateWidget(CameraScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reveal != widget.reveal) {
      oldWidget.reveal.removeListener(_onReveal);
      widget.reveal.addListener(_onReveal);
      _syncLoop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = reduceMotionOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _physics.reduceMotion = reduce;
      _applyPose();
    }
    _syncLoop();
  }

  @override
  void dispose() {
    widget.reveal.removeListener(_onReveal);
    _loop.dispose();
    _pose.dispose();
    _focus.dispose();
    _dragging.dispose();
    _focusRing.dispose();
    _noteFade.dispose();
    _hintPhase.dispose();
    super.dispose();
  }

  // ---- Döngü ---------------------------------------------------------------------------------------------------

  void _onReveal() => _syncLoop();

  /// Döngü yalnızca sahne görünürken, açıklıktan en az biraz göründükten sonra ve gerçekten kare gerekiyorsa
  /// çalışır (hareketi azalt açıkken boşta kare yoktur).
  void _syncLoop() {
    if (!mounted) return;
    final shown = widget.reveal.value > 0.01;
    if (_visible && shown && _physics.needsFrames) {
      _loop.start();
    } else {
      _loop.stop();
    }
  }

  void _onFrame(double dt, double elapsed) {
    // Boşta hareketler çok yavaştır: 30 kare yeter. Etkileşim sürerken her karede çizilir.
    _acc += dt;
    if (!_physics.isInteracting && _acc < 1 / 30) return;
    final step = _acc;
    _acc = 0;
    _physics.step(step);
    if (!_reduceMotion) _light = (_light + step * 2 * math.pi / 80) % (2 * math.pi);
    if (!_hintGone) _hintPhase.value += step;
    _applyPose();
    if (!_physics.needsFrames) _loop.stop();
  }

  void _applyPose() {
    _pose.set(yaw: _physics.yaw, pitch: kCameraHomePitch + _physics.idlePitch, lightPhase: _light);
    _noteFade.value = noteVisibilityForYaw(_physics.yaw);
  }

  // ---- Etkileşim -----------------------------------------------------------------------------------------------

  void _dismissHint() {
    if (_hintGone) return;
    setState(() => _hintGone = true);
  }

  void _onDragStart(DragStartDetails d) {
    _dismissHint();
    _dragging.value = true;
    _physics.dragStart();
    _syncLoop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _physics.dragUpdate(d.delta.dx, _radPerPx);
    _applyPose();
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging.value = false;
    _physics.dragEnd(d.velocity.pixelsPerSecond.dx, _radPerPx);
    _applyPose();
    _syncLoop();
  }

  void _onDragCancel() {
    _dragging.value = false;
    _physics.dragCancel();
    _applyPose();
    _syncLoop();
  }

  /// [direction] +1: sola (←), -1: sağa (→). Sürükleme ile aynı yön: sola sürüklemek yaw'ı artırır.
  void _nudge(int direction) {
    if (widget.reveal.value < liveThreshold) return;
    // Klavye (ya da ekran okuyucu) kullanılıyor: odak halkası görünür olsun.
    _pointerFocus = false;
    _focusRing.value = _focus.hasFocus;
    _dismissHint();
    _physics.nudge(direction * keyStep);
    _applyPose();
    _syncLoop();
  }

  // ---- Çizim ---------------------------------------------------------------------------------------------------

  /// Metin bloğunun doğal yüksekliği (mobilde ürün onun altına yerleşir).
  double _measureText(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    // Text widget'ı stilini DefaultTextStyle ile birleştirir (ör. harf aralığı); ölçüm de aynısını yapmalı.
    final base = DefaultTextStyle.of(context).style;
    double h(String s, TextStyle style, double maxWidth) {
      final tp = TextPainter(text: TextSpan(text: s, style: base.merge(style)), textDirection: TextDirection.ltr, textScaler: scaler)
        ..layout(maxWidth: math.max(1.0, maxWidth));
      final r = tp.height;
      tp.dispose();
      return r;
    }

    return h(_Copy.eyebrow, AppText.label(context), width - 32) +
        _Copy.gapAfterEyebrow +
        h(_Copy.title, AppText.h2(context), width) +
        _Copy.gapAfterTitle +
        h(_Copy.lead, AppText.body(context), math.min(width, _Copy.leadMaxWidth));
  }

  /// Üç notun etiket genişlikleri (yerleşim, etiket sahneye sığmıyorsa çizgiyi ters yöne çevirir).
  List<double> _measureLabels(BuildContext context) {
    final scaler = _annotationScaler(MediaQuery.textScalerOf(context));
    final base = DefaultTextStyle.of(context).style;
    double width(String text) {
      final tp = TextPainter(text: TextSpan(text: text, style: base.merge(AppText.small(context))), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)
        ..layout();
      final w = tp.width;
      tp.dispose();
      return w.ceilToDouble() + 2;
    }

    return [for (final n in _Copy.notes) width(n)];
  }

  /// Süs niteliğindeki kısa notlar (etiketler, ipucu) çok büyük yazı boyutunda bile yerleşimi bozmasın diye ölçek sınırlanır.
  static TextScaler _annotationScaler(TextScaler s) => s.clamp(maxScaleFactor: 1.3);

  CustomPainter _productPainter(AppColors c, double quality) {
    final rim = c.isDark ? 0.5 : 0.3;
    final key = Object.hash(c.shadow, quality, rim);
    if (_painter == null || _painterKey != key) {
      _painter = buildProductPainter(pose: _pose, quality: quality, shadowColor: c.shadow, rimStrength: rim);
      _painterKey = key;
    }
    return _painter!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return VisibilityProbe(
      onChanged: (v) {
        _visible = v;
        _syncLoop();
      },
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final mq = MediaQuery.sizeOf(context);
          final size = Size(box.hasBoundedWidth ? box.maxWidth : mq.width, box.hasBoundedHeight ? box.maxHeight : mq.height);
          final mode = CameraSceneLayout.modeFor(size);
          final sidePad = fluid(context, 24, 40);
          final textW = CameraSceneLayout.textWidthFor(mode, size, sidePad);
          final layout = CameraSceneLayout.compute(
            size: size,
            mode: mode,
            textHeight: _measureText(context, textW),
            sidePad: sidePad,
            aspect: kProductAspect,
            noteLabelWidths: _measureLabels(context),
          );
          _radPerPx = math.pi / math.max(160.0, layout.product.width);
          return SizedBox(
            width: size.width,
            height: size.height,
            child: ClipRect(child: _content(context, c, layout)),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, AppColors c, CameraSceneLayout layout) {
    final reveal = widget.reveal;
    final quality = isPhone(context) ? 0.6 : 1.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Zemin: stüdyo zemini + merkezde yumuşak parıltı. Hareketsiz; ayrı katmanda bir kez çizilir.
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: StagePainter(colors: c, glowCenter: layout.glowCenter, glowRadius: layout.glowRadius)),
          ),
        ),
        // Klavye odak ayraçları notların ALTINDA çizilir (notlar her zaman okunur kalır).
        Positioned.fromRect(rect: layout.product, child: _focusBrackets(c)),
        Positioned.fromRect(rect: layout.text, child: _textBlock(layout)),
        if (layout.wide) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: NoteLinesPainter(notes: layout.noteGeometry, reveal: reveal, fade: _noteFade, lineColor: c.lineStrong, dotColor: c.accent),
                ),
              ),
            ),
          ),
          ..._wideNoteLabels(layout),
        ] else if (!layout.notes.isEmpty)
          // Yatay-kısa kipte ([CameraLayoutMode.compact]) ve ürüne yer kalmayan dar düzende notlar gösterilmez.
          Positioned.fromRect(rect: layout.notes, child: _narrowNotes(c)),
        Positioned.fromRect(rect: layout.product, child: _product(c, layout, quality)),
        Positioned.fromRect(rect: layout.hint, child: IgnorePointer(child: _hint(c, layout))),
      ],
    );
  }

  Widget _textBlock(CameraSceneLayout layout) {
    final reveal = widget.reveal;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: layout.wide ? Alignment.centerLeft : Alignment.topLeft,
      child: SizedBox(
        width: layout.text.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _EnterOnReveal(reveal: reveal, begin: 0.55, end: 0.85, child: const Eyebrow(_Copy.eyebrow)),
            const SizedBox(height: _Copy.gapAfterEyebrow),
            _EnterOnReveal(reveal: reveal, begin: 0.62, end: 0.92, child: const SectionTitle(_Copy.title)),
            const SizedBox(height: _Copy.gapAfterTitle),
            _EnterOnReveal(reveal: reveal, begin: 0.70, end: 1.0, child: const Lead(_Copy.lead, maxWidth: _Copy.leadMaxWidth)),
          ],
        ),
      ),
    );
  }

  /// Geniş düzende üç çizgi-notunun etiketleri (çizgileri [NoteLinesPainter] çizer). Döndürürken sabit kalırlar.
  List<Widget> _wideNoteLabels(CameraSceneLayout layout) {
    final reveal = widget.reveal;
    return [
      for (var i = 0; i < layout.noteGeometry.length; i++)
        Positioned.fromRect(
          rect: layout.noteGeometry[i].label,
          child: _EnterOnReveal(
            reveal: reveal,
            begin: 0.80 + 0.05 * i,
            end: 1.0,
            dy: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _noteFade,
              builder: (context, fade, child) => Opacity(opacity: fade, child: child),
              child: Align(
                alignment: layout.noteGeometry[i].labelRight ? Alignment.centerLeft : Alignment.centerRight,
                child: _annotation(Text(_Copy.notes[i], maxLines: 1, softWrap: false, style: AppText.small(context))),
              ),
            ),
          ),
        ),
    ];
  }

  /// Etiket/ipucu gibi süs niteliğindeki kısa yazıları ölçek sınırıyla sarar.
  Widget _annotation(Widget child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child);

  /// Mobilde ürünün altında sade üç satır.
  Widget _narrowNotes(AppColors c) {
    final reveal = widget.reveal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _Copy.notes.length; i++)
          SizedBox(
            height: 30,
            child: _EnterOnReveal(
              reveal: reveal,
              begin: 0.66 + 0.06 * i,
              end: 0.96,
              dy: 8,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _annotation(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle)),
                      Container(width: 18, height: 1, color: c.lineStrong),
                      const SizedBox(width: 10),
                      Text(_Copy.notes[i], maxLines: 1, softWrap: false, style: AppText.small(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Ürün: giriş animasyonu (ölçek + opaklık) + jestler + klavye + erişilebilirlik.
  Widget _product(AppColors c, CameraSceneLayout layout, double quality) {
    final reveal = widget.reveal;
    final art = SizedBox.expand(
      child: RepaintBoundary(child: CustomPaint(painter: _productPainter(c, quality))),
    );

    final entering = ValueListenableBuilder<double>(
      valueListenable: reveal,
      child: art,
      builder: (context, r, child) {
        // reveal 0.12'den önce yalnızca boş zemin ve parıltı görünür; sonra ürün 0.82 → 1 ölçekle belirir.
        final scale = 0.82 + 0.18 * smooth01(remap01(r, 0.12, 0.80));
        final opacity = smooth01(remap01(r, 0.12, 0.55));
        return Opacity(opacity: opacity, child: Transform.scale(scale: scale, child: child));
      },
    );

    final interactive = Semantics(
      label: _label,
      onIncrease: () => _nudge(-1),
      onDecrease: () => _nudge(1),
      child: FocusableActionDetector(
        focusNode: _focus,
        onShowFocusHighlight: (v) => _focusRing.value = v && !_pointerFocus,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _RotateIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _RotateIntent(-1),
        },
        actions: {
          _RotateIntent: CallbackAction<_RotateIntent>(onInvoke: (i) {
            _nudge(i.direction);
            return null;
          }),
        },
        child: Listener(
          onPointerDown: (_) {
            _pointerFocus = true;
            _focusRing.value = false;
            _focus.requestFocus();
          },
          child: ValueListenableBuilder<bool>(
            valueListenable: _dragging,
            builder: (context, dragging, child) => MouseRegion(
              cursor: dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
              child: child,
            ),
            // YALNIZCA yatay sürükleme: dikey sürükleme sayfayı kaydırmaya devam eder.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: _onDragCancel,
              child: entering,
            ),
          ),
        ),
      ),
    );

    // reveal < 0.98 iken ürün jestlere kapalıdır (ayrıca hero bloğu da pointer'ı keser).
    return ValueListenableBuilder<double>(
      valueListenable: reveal,
      child: interactive,
      builder: (context, r, child) => IgnorePointer(ignoring: r < liveThreshold, child: child),
    );
  }

  /// Klavye odağı işareti (yalnızca [_focusRing] açıkken görünür); jestleri engellemez.
  Widget _focusBrackets(AppColors c) {
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: _focusRing,
        builder: (context, on, _) => on ? CustomPaint(painter: FocusBracketsPainter(color: c.accent)) : const SizedBox.expand(),
      ),
    );
  }

  /// "Sürükleyerek döndürün" ipucu: ürünün altında ince yay + kısa yazı. İlk etkileşimden sonra solar ve geri gelmez.
  Widget _hint(AppColors c, CameraSceneLayout layout) {
    final reveal = widget.reveal;
    final text = layout.wide ? 'Sürükleyerek döndürün' : 'Yatay çevirerek döndürün';
    return AnimatedOpacity(
      opacity: _hintGone ? 0 : 1,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      child: _EnterOnReveal(
        reveal: reveal,
        begin: 0.88,
        end: 1.0,
        dy: 6,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: _annotation(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: math.min(layout.hint.width, 200.0),
                  height: 22,
                  child: CustomPaint(
                    painter: RotateHintArcPainter(phase: _hintPhase, lineColor: c.lineStrong, dotColor: c.accent, animate: !_reduceMotion),
                  ),
                ),
                const SizedBox(height: 6),
                Text(text, textAlign: TextAlign.center, style: AppText.small(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sahnede kullanılan metinler (şartname §5.2: birebir).
class _Copy {
  _Copy._();

  static const eyebrow = 'KAMERA SİSTEMLERİ';
  static const title = 'Her açıdan net görüntü.';
  static const lead = 'IP ve analog kamera sistemleri, kayıt çözümleri, ağ altyapısı ve profesyonel görüntüleme sistemleri.';
  static const notes = ['IP ve analog sistemler', 'Kayıt çözümleri', 'Ağ altyapısı'];

  static const double leadMaxWidth = 440;
  static const double gapAfterEyebrow = 18;
  static const double gapAfterTitle = 16;
}

class _RotateIntent extends Intent {
  const _RotateIntent(this.direction);
  final int direction;
}

/// [reveal] belirli bir aralığa girdiğinde çocuğu [dy] piksel aşağıdan süzülerek ve opaklıkla getirir.
/// Zamanı yoktur: ilerleme doğrudan reveal'dan gelir (kaydırma ile oynatılır, geri de oynar).
class _EnterOnReveal extends StatelessWidget {
  const _EnterOnReveal({required this.reveal, required this.begin, required this.end, required this.child, this.dy = 16});

  final ValueListenable<double> reveal;
  final double begin;
  final double end;
  final double dy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: reveal,
      child: child,
      builder: (context, r, child) {
        final t = smooth01(remap01(r, begin, end));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: child),
        );
      },
    );
  }
}
