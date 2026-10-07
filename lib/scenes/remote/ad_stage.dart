import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../core/motion.dart';
import '../../core/visibility_probe.dart';
import '../../theme.dart';
import 'ad_timeline.dart';
import 'box_asset.dart';
import 'box_painters.dart';
import 'phone_painters.dart';
import 'scene_painters.dart';
import 'signal_painter.dart';
import 'stage_geometry.dart';

/// "İlk ürünümüz" reklam sahnesi: kutu, telefon, kapı ve aralarındaki sinyal tek bir zaman çizelgesiyle
/// (bkz. [AdTimeline]) oynar. Sahne ekranda değilken döngü durur; hareketi azalt açıkken durağan son kare gösterilir.
///
/// Katmanlar ayrı RepaintBoundary'lerdedir: kutunun ürün çekimi katmanı bir kez boyanır, kareler boyunca
/// yalnızca ışık/sinyal/telefon ekranı katmanları yeniden boyanır; widget ağacı yeniden kurulmaz.
/// Renkler temadan ([BuildContext.colors]) gelir ve painter'lara kurucu alanı olarak verilir; tema değişince
/// painter'lar yeniden boyanır.
class RemoteDoorStage extends StatefulWidget {
  const RemoteDoorStage({super.key, this.compact = false, this.maxHeight, this.debugClock});

  /// Telefon genişliğinde dikey kompozisyon.
  final bool compact;

  /// Sahne çiziminin (altyazı hariç) en büyük yüksekliği; verilirse sahne en-boy oranı korunarak bu yüksekliğe sığacak
  /// kadar daralır ve ortalanır. Dikey yerleşimde sahnenin tek ekrana sığması içindir.
  final double? maxHeight;

  /// Yalnızca testler için: verilirse döngü çalışmaz, zamanı bu saat belirler.
  @visibleForTesting
  final AdClock? debugClock;

  /// YER TUTUCU: ürünün kesin adı/modeli belli olunca telefon başlığı ve metin güncellenir.
  static const productName = 'AHBU';

  @override
  State<RemoteDoorStage> createState() => _RemoteDoorStageState();
}

class _RemoteDoorStageState extends State<RemoteDoorStage> with SingleTickerProviderStateMixin {
  late final AdClock _ownClock = AdClock();
  late final FrameLoop _loop = FrameLoop(this, (dt, _) => _ownClock.advance(dt));

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;

  bool _visible = true;
  bool _reduce = false;

  /// Kutu görseli ekranda gerekenden büyük çözülmesin diye bu genişliğe sınırlanarak okunur (kaynak 1099 px).
  static const _decodeWidth = 1100;

  /// Sahne tam ekran sınırında başlar/durur: reklam, ziyaretçi sahneyi görmeye başladığı anda en başından oynar.
  static const _visibilityMargin = 0.0;

  /// Sahne ile altyazı arasındaki boşluk.
  static const _captionGap = 4.0;

  static const _semantics =
      'Animasyon: telefondaki uygulamada kapıyı aç düğmesine dokunulur, sinyal kutuya gider ve kapı açılır.';

  AdClock get _clock => widget.debugClock ?? _ownClock;

  @override
  void initState() {
    super.initState();
    _ownClock.time = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotionOf(context);
    _resolveImage();
    _sync();
  }

  @override
  void didUpdateWidget(RemoteDoorStage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    _info?.dispose();
    _loop.dispose();
    _ownClock.dispose();
    super.dispose();
  }

  /// Döngü yalnızca: gerçek saat kullanılıyor, sahne görünür ve hareketi azalt kapalıysa çalışır.
  void _sync() {
    if (widget.debugClock != null) {
      _loop.stop();
      return;
    }
    if (_reduce) {
      _loop.stop();
      _ownClock.time = AdTimeline.restTime;
      return;
    }
    if (_visible) {
      _loop.start();
    } else {
      _loop.stop();
    }
  }

  /// Sahne ekrana girince reklam baştan başlar (ziyaretçi hikâyeyi ortasından değil, en başından izler);
  /// ekrandan çıkınca durur.
  void _onVisibility(bool visible) {
    final entering = visible && !_visible;
    _visible = visible;
    if (entering && widget.debugClock == null && !_reduce) _ownClock.time = 0;
    _sync();
  }

  void _resolveImage() {
    final provider = ResizeImage(const AssetImage(BoxAsset.assetPath), width: _decodeWidth);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener!);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) {
        info.dispose();
        return;
      }
      setState(() {
        _info?.dispose();
        _info = info;
      });
    });
    _stream = stream..addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final geo = widget.compact ? StageGeometry.tall : StageGeometry.wide;
    final clock = _clock;
    final image = _info?.image;
    final c = context.colors;

    return VisibilityProbe(
      margin: _visibilityMargin,
      onChanged: _onVisibility,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          var w = box.maxWidth.isFinite ? box.maxWidth : geo.design.width;
          final maxHeight = widget.maxHeight;
          if (maxHeight != null) w = math.min(w, maxHeight * geo.design.width / geo.design.height);
          final s = w / geo.design.width;
          final size = Size(w, geo.design.height * s);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: _semantics,
                image: true,
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: _layers(geo, clock, image, c, s),
                  ),
                ),
              ),
              const SizedBox(height: _captionGap),
              AdCaptions(step: clock.step, reduceMotion: _reduce),
            ],
          );
        },
      ),
    );
  }

  Widget _layers(StageGeometry geo, AdClock clock, ui.Image? image, AppColors c, double s) {
    final phone = geo.phone;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        RepaintBoundary(child: CustomPaint(painter: StageBackdropPainter(geo: geo, c: c))),
        RepaintBoundary(child: CustomPaint(painter: DoorPainter(geo: geo, clock: clock, c: c))),
        // Kutu: yükselme ve hafif yüzme yalnızca katman dönüşümüdür; içerik yeniden boyanmaz.
        AnimatedBuilder(
          animation: clock,
          builder: (context, child) {
            final st = clock.value;
            return Opacity(
              opacity: st.boxOpacity.clamp(0.0, 1.0),
              child: Transform.translate(offset: geo.boxOffset(st) * s, child: child),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              RepaintBoundary(child: CustomPaint(painter: ProductBoxPainter(geo: geo, image: image, c: c))),
              RepaintBoundary(child: CustomPaint(painter: BoxLightPainter(geo: geo, image: image, clock: clock, c: c))),
            ],
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: SignalPainter(geo: geo, clock: clock, c: c))),
        Positioned(
          left: phone.left * s,
          top: phone.top * s,
          width: phone.width * s,
          height: phone.height * s,
          child: AnimatedBuilder(
            animation: clock,
            builder: (context, child) {
              final p = clock.value.phoneIn;
              if (p <= _phoneHidden) return const SizedBox.shrink();
              final k = 1 - p; // 0 = yerinde
              final m = Matrix4.translationValues(geo.phoneFrom.dx * k * s, geo.phoneFrom.dy * k * s, 0)..rotateZ(geo.phoneTilt * k);
              return Opacity(
                opacity: (p * _phoneFadeRate).clamp(0.0, 1.0),
                child: Transform(transform: m, alignment: Alignment.center, child: child),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                RepaintBoundary(child: CustomPaint(painter: PhoneBodyPainter(c: c))),
                RepaintBoundary(
                  child: CustomPaint(painter: PhoneScreenPainter(clock: clock, title: RemoteDoorStage.productName)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Telefon, girişin ilk yarısında hızla görünür hâle gelir (opaklık = ilerleme × bu katsayı).
  static const _phoneFadeRate = 1.8;
  static const _phoneHidden = 0.0005;
}

/// Sahnenin altındaki ince adım altyazıları: "1 Dokunun · 2 Sinyal gider · 3 Kapı açılır".
/// Aktif adım [AppColors.text] renginde ve altında ince vurgu çizgisiyle, diğerleri ikincil renkte gösterilir.
class AdCaptions extends StatelessWidget {
  const AdCaptions({super.key, required this.step, this.reduceMotion = false});

  final ValueListenable<int> step;
  final bool reduceMotion;

  static const labels = ['Dokunun', 'Sinyal gider', 'Kapı açılır'];

  static const _fade = Duration(milliseconds: 350);
  static const _spacing = 14.0;
  static const _runSpacing = 4.0;
  static const _underlineGap = 3.0;
  static const _underlineWidth = 18.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<int>(
      valueListenable: step,
      builder: (context, active, _) {
        final duration = reduceMotion ? Duration.zero : _fade;
        final children = <Widget>[];
        for (var i = 0; i < labels.length; i++) {
          if (i > 0) {
            children.add(Text('·', style: AppText.small(context, color: c.textFaint)));
          }
          final on = active == i + 1;
          children.add(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOut,
                  style: AppText.small(context, color: on ? c.text : c.textDim),
                  child: Text('${i + 1}  ${labels[i]}'),
                ),
                const SizedBox(height: _underlineGap),
                AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  height: 1,
                  width: on ? _underlineWidth : 0,
                  color: c.accent,
                ),
              ],
            ),
          );
        }
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: _spacing,
          runSpacing: _runSpacing,
          children: children,
        );
      },
    );
  }
}
