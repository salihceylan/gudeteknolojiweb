import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reveal.dart';

/// Çalışma şekli: dört adım, ince çizgiyle bağlı. Masaüstünde yatay, dar ekranda dikey akar.
/// Çizgi, kullanıcı adımlara ulaştıkça bir kez, yay eğrisiyle uzar: her adım görünür alana girince
/// çizgi o adımın düğümüne kadar (segment segment) ilerler ve düğüm turkuaza döner. Döngü yoktur.
class ProcessScene extends StatelessWidget {
  const ProcessScene({super.key});

  static const _steps = <(String, String)>[
    ('Keşif', 'Saha ve ihtiyaç analizi'),
    ('Projelendirme', 'Doğru ürün ve altyapı seçimi'),
    ('Uygulama', 'Kurulum ve devreye alma'),
    ('Servis', 'Bakım ve teknik destek'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HairlineDivider(),
        Section(
          color: c.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('ÇALIŞMA ŞEKLİMİZ'),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      // Ortak SectionTitle başlık işaretlemesi taşımadığından burada sarılır.
                      child: Semantics(header: true, child: const SectionTitle('Projeden sahaya tek noktadan çözüm.')),
                    ),
                    const SizedBox(height: 16),
                    const Lead(
                      'Sadece ürün temin eden değil, doğru sistemi tasarlayan ve sahada çalışır hale getiren bir teknik çözüm yaklaşımıyla çalışıyoruz.',
                      maxWidth: 620,
                    ),
                  ],
                ),
              ),
              SizedBox(height: fluid(context, 40, 64)),
              const _ProcessSteps(steps: _steps),
            ],
          ),
        ),
      ],
    );
  }
}

/// Adımları ve bağlantı çizgisini kuran kap.
///
/// İlerleme [ValueListenable] olarak tek bir sayıdır ve "birim" cinsindendir: her tam sayı bir şeyin tamamlanması demektir.
/// Birim 0→1: ilk düğüm yanar; 1→2: ilk çizgi ikinci düğüme ulaşır; … Yatayda bir birim daha vardır:
/// son düğümden son sütunun sonuna uzanan kuyruk çizgisi. İlerleme adım-bazlıdır: bir adım ekran yüksekliğinin
/// [_seenAt] oranının üstüne çıkınca (yani Reveal ile birlikte göründüğünde) hedef bir birim artar; birimler sırayla,
/// her biri kendi yayıyla oynar. Böylece yavaş kaydıran kullanıcı henüz görmediği alt segmentleri kaçırmaz,
/// görmediği bir çizgi de "boşuna" çalışmaz.
class _ProcessSteps extends StatefulWidget {
  const _ProcessSteps({required this.steps});

  final List<(String, String)> steps;

  @override
  State<_ProcessSteps> createState() => _ProcessStepsState();
}

class _ProcessStepsState extends State<_ProcessSteps> with SingleTickerProviderStateMixin {
  /// Bir birimin (düğüm ya da segment) süresi.
  static const _unit = Duration(milliseconds: 600);

  /// Adımın üst kenarı ekran yüksekliğinin bu oranının yukarısına çıkınca adım görülmüş sayılır
  /// (Reveal %92'de açılır; çizgi, adım belirmeye başladıktan hemen sonra ona ulaşır).
  static const _seenAt = 0.86;

  late final List<GlobalKey> _keys = List.generate(widget.steps.length, (_) => GlobalKey(debugLabel: 'process-step'));
  late final AnimationController _controller;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  ScrollPosition? _position;
  bool _horizontal = true;

  /// Ulaşılmak istenen birim ve şimdiye dek tamamlanan birim.
  double _target = 0;
  double _done = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Üst sınır: n düğüm birimi + yatayda kuyruk birimi.
    _controller = AnimationController(vsync: this, upperBound: (widget.steps.length + 1).toDouble())
      // Yay eğrisi hedefi hafifçe aşar; aşan kısım bir sonraki segmenti erkenden çizmesin diye tamamlanan birimle sınırlanır.
      ..addListener(() => _progress.value = math.min(_controller.value, _done + 1))
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _done = _controller.value;
        _advance();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_check);
      next?.addListener(_check);
      _position = next;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _disposed = true;
    _position?.removeListener(_check);
    _controller.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Kaç adımın görüldüğünü ölçer ve hedefi (yalnızca ileri doğru) günceller.
  void _check() {
    if (_disposed || !mounted) return;
    final limit = MediaQuery.sizeOf(context).height * _seenAt;
    var seen = 0;
    for (final key in _keys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) break;
      if (box.localToGlobal(Offset.zero).dy >= limit) break;
      seen++;
    }
    if (seen == 0) return;
    // Yatayda adımlar aynı hizadadır: hepsi görülünce çizgi son sütunun sonuna kadar (kuyruk) uzar.
    final units = _horizontal && seen == _keys.length ? _keys.length + 1.0 : seen.toDouble();
    if (units <= _target) return;
    _target = units;
    if (reduceMotionOf(context)) {
      _done = units;
      _controller.value = units;
    } else {
      _advance();
    }
  }

  /// Hedefe, birim birim ve her biri ayrı yayla ilerler.
  void _advance() {
    if (_disposed || _controller.isAnimating || _done >= _target) return;
    _controller.animateTo(_done + 1, duration: _unit, curve: const SpringCurve());
  }

  @override
  Widget build(BuildContext context) {
    // Pencere boyutu değişince adımların konumu da değişir: yeniden ölç.
    MediaQuery.sizeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    return LayoutBuilder(
      builder: (context, box) {
        _horizontal = box.maxWidth >= 640;
        return _horizontal ? _buildHorizontal(context) : _buildVertical(context);
      },
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final c = context.colors;
    final n = widget.steps.length;
    final gap = fluid(context, 16, 32);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++)
          Expanded(
            child: KeyedSubtree(
              key: _keys[i],
              child: Reveal(
                delay: Duration(milliseconds: 90 * i),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomPaint(
                      key: ValueKey('process-rail-$i'),
                      size: const Size(double.infinity, 16),
                      painter: ProcessRailPainter(
                        progress: _progress,
                        index: i,
                        count: n,
                        vertical: false,
                        track: c.lineStrong,
                        active: c.accent,
                        background: c.bg,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _StepText(index: i, title: widget.steps[i].$1, text: widget.steps[i].$2, rightPad: gap),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVertical(BuildContext context) {
    final c = context.colors;
    final n = widget.steps.length;
    return Column(
      children: [
        for (var i = 0; i < n; i++)
          KeyedSubtree(
            key: _keys[i],
            child: Reveal(
              delay: Duration(milliseconds: 90 * i),
              // Çizgi parçası kendi adımının yüksekliğini (alt boşluk dâhil) kaplar; bir sonraki düğüme ulaşır.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 32,
                      child: CustomPaint(
                        key: ValueKey('process-rail-$i'),
                        painter: ProcessRailPainter(
                          progress: _progress,
                          index: i,
                          count: n,
                          vertical: true,
                          track: c.lineStrong,
                          active: c.accent,
                          background: c.bg,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: i == n - 1 ? 0 : 32),
                        child: _StepText(index: i, title: widget.steps[i].$1, text: widget.steps[i].$2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText({required this.index, required this.title, required this.text, this.rightPad = 0});

  final int index;
  final String title;
  final String text;
  final double rightPad;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: EdgeInsets.only(right: rightPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Adım numarası textDim: iki temada da ≥ 4.5:1 (textFaint yalnızca süs etiketleri içindir).
            ExcludeSemantics(child: Text((index + 1).toString().padLeft(2, '0'), style: AppText.label(context))),
            const SizedBox(height: 8),
            Text(title, style: AppText.h3(context)),
            const SizedBox(height: 8),
            Text(text, style: AppText.body(context)),
          ],
        ),
      ),
    );
  }
}

/// Bir adımın düğümünü ve onu bir sonraki düğüme bağlayan çizgi parçasını çizer.
/// Yatayda parça sütun genişliği boyunca, dikeyde adım yüksekliği boyunca uzanır; yatayda son sütunun parçası
/// düğümden sütunun (ve içeriğin) sonuna uzanan bir kuyruk çizgisidir, böylece çizgi tüm genişliği kaplar.
///
/// [progress] birim cinsindendir (bkz. `_ProcessSteps`): düğüm `index` → `index+1` biriminde yanar,
/// çizgi parçası `index+1` → `index+2` biriminde uzar. Widget ağacı yeniden kurulmaz; yalnızca bu painter boyanır.
/// Tema renkleri kurucudan gelir ve [shouldRepaint]'e katılır; tema geçişinde yeniden boyanır.
///
/// Test için açıktır (`ValueKey('process-rail-$i')` taşıyan CustomPaint'in painter'ı); uygulama kodu kullanmamalı.
@visibleForTesting
class ProcessRailPainter extends CustomPainter {
  ProcessRailPainter({
    required this.progress,
    required this.index,
    required this.count,
    required this.vertical,
    required this.track,
    required this.active,
    required this.background,
  })  : _trackPaint = Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
        _activePaint = Paint()
          ..color = active
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
        super(repaint: progress);

  final ValueListenable<double> progress;
  final int index;
  final int count;
  final bool vertical;

  /// Çizgi ve yanmamış halka rengi.
  final Color track;

  /// Yanmış çizgi, halka ve düğüm dolgusu (vurgu).
  final Color active;

  /// Yanmamış düğümün iç dolgusu: bölüm zemini.
  final Color background;

  static const _r = 5.0; // düğüm yarıçapı
  static const _inset = 8.0; // düğüm ile çizgi arasındaki boşluk

  final Paint _trackPaint;
  final Paint _activePaint;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _fill = Paint();

  // Kuyruk çizgisinin sağa doğru sönen boyaları; genişlik değişmedikçe yeniden kurulmaz.
  Paint? _tailTrack;
  Paint? _tailActive;
  Offset? _tailSpan;

  /// Kuyruk, `from`→`to` arasında ilk %40'ta tam renkte kalır, sonra şeffaflaşır: "Servis" süregelen bir iştir,
  /// çizgi bir yerde kesilmek yerine sessizce söner.
  void _ensureTail(double from, double to) {
    if (_tailSpan == Offset(from, to)) return;
    _tailSpan = Offset(from, to);
    Paint faded(Paint base, Color color) => Paint()
      ..style = base.style
      ..strokeWidth = base.strokeWidth
      ..strokeCap = base.strokeCap
      ..shader = ui.Gradient.linear(Offset(from, 0), Offset(to, 0), [color, color, color.withValues(alpha: 0)], const [0, 0.4, 1]);
    _tailTrack = faded(_trackPaint, track);
    _tailActive = faded(_activePaint, active);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final isLast = index == count - 1;
    final tail = !vertical && isLast;

    // Düğüm merkezi: yatayda sol kenara hizalı (metinle aynı hat), dikeyde ilk satırın hizasında.
    final center = vertical ? const Offset(_r + 1, 9) : const Offset(_r + 1, 8);

    // Düğüm: çizgi kendisine ulaştığında soluk bir halka + turkuaz iç dolguyla belirir.
    final lit = smooth01(remap01(p, index + 0.85, index + 1.0));
    _ring.color = Color.lerp(track, active.withValues(alpha: 0.45), lit)!;
    canvas.drawCircle(center, _r + 3, _ring);
    _fill.color = Color.lerp(background, active, lit)!;
    canvas.drawCircle(center, _r - 1.5, _fill);

    // Dikeyde son düğümün altında çizgi yoktur.
    if (isLast && !tail) return;

    final from = (vertical ? center.dy : center.dx) + _r + 3 + _inset;
    final to = tail ? size.width : (vertical ? size.height + center.dy : size.width + center.dx) - _r - 3 - _inset;
    if (to <= from) return;
    final local = remap01(p, index + 1.0, index + 2.0);

    Offset at(double v) => vertical ? Offset(center.dx, v) : Offset(v, center.dy);
    if (tail) _ensureTail(from, to);
    canvas.drawLine(at(from), at(to), tail ? _tailTrack! : _trackPaint);
    if (local > 0) canvas.drawLine(at(from), at(from + (to - from) * local), tail ? _tailActive! : _activePaint);
  }

  @override
  bool shouldRepaint(ProcessRailPainter old) =>
      old.progress != progress ||
      old.index != index ||
      old.count != count ||
      old.vertical != vertical ||
      old.track != track ||
      old.active != active ||
      old.background != background;
}
