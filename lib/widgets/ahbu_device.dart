import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// AHBU kapı kontrol cihazının etkileşimli çizimi.
///
/// Gerçek cihazın önden görünümünü yeniden çizer: siyah gövde, "AHBU" kesiği,
/// kırmızı LED, 2.4" ekran (dinamik karekod) ve ışıklı metal buton.
/// Fare ile hafifçe eğilir; butona basınca ekran "KAPI AÇILDI" gösterir.
/// Ekrandaki karekod yalnızca gösterim amaçlıdır, gerçek bir kapıya bağlı değildir.
class AhbuDevice extends StatefulWidget {
  const AhbuDevice({super.key, required this.width, this.paused = false, this.shadowColor});

  final double width;

  /// true iken yüzme animasyonu ve karekod sayacı durur (cihaz ekran dışındayken ya da hareketi azalt modunda).
  final bool paused;

  /// Zemin gölgesinin rengi (alfa dahil). Verilmezse koyu zeminler için koyu gölge kullanılır;
  /// açık temada sahne `context.colors.shadow` verir. Cihazın kendi malzeme renkleri temadan bağımsızdır.
  final Color? shadowColor;

  @override
  State<AhbuDevice> createState() => _AhbuDeviceState();
}

class _AhbuDeviceState extends State<AhbuDevice> with SingleTickerProviderStateMixin {
  static const _qrLifetime = 30; // Gerçek cihazda karekod 30 sn'de bir yenilenir.

  late final AnimationController _float;
  Timer? _tick;
  int _remaining = _qrLifetime;
  int _qrSeed = 1;
  bool _opened = false;
  bool _pressed = false;
  Offset _tilt = Offset.zero; // -1..1

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _applyPaused();
  }

  @override
  void didUpdateWidget(AhbuDevice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused) _applyPaused();
  }

  /// Duraklatılmışken zamanlayıcı ve yüzme döngüsü çalışmaz (ekran dışında CPU/GPU harcanmaz).
  void _applyPaused() {
    if (widget.paused) {
      _tick?.cancel();
      _tick = null;
      _float.stop();
      return;
    }
    _float.repeat(reverse: true);
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _remaining = _qrLifetime;
          _qrSeed++;
        }
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _float.dispose();
    super.dispose();
  }

  Future<void> _openDoor() async {
    if (_opened) return;
    setState(() => _opened = true);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (mounted) setState(() => _opened = false);
  }

  void _onHover(PointerEvent e, Size size) {
    final dx = (e.localPosition.dx / size.width) * 2 - 1;
    final dy = (e.localPosition.dy / size.height) * 2 - 1;
    setState(() => _tilt = Offset(dx.clamp(-1, 1), dy.clamp(-1, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final size = Size(w, w * 1.62);

    return MouseRegion(
      onHover: (e) => _onHover(e, size),
      onExit: (_) => setState(() => _tilt = Offset.zero),
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, child) {
          final lift = math.sin(_float.value * math.pi) * 8;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-_tilt.dy * 0.22)
            ..rotateY(_tilt.dx * 0.28);
          return Transform.translate(
            offset: Offset(0, -lift),
            child: Transform(alignment: Alignment.center, transform: m, child: child),
          );
        },
        child: SizedBox.fromSize(size: size, child: _body(w)),
      ),
    );
  }

  Widget _body(double w) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Zemin gölgesi
        Positioned(
          left: w * 0.08,
          right: w * 0.08,
          bottom: -w * 0.05,
          child: Container(
            height: w * 0.08,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w),
              boxShadow: [
                BoxShadow(color: widget.shadowColor ?? Colors.black.withValues(alpha: 0.55), blurRadius: w * 0.12, spreadRadius: w * 0.01),
              ],
            ),
          ),
        ),
        // Gövde
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w * 0.07),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2C31), Color(0xFF131417), Color(0xFF1D1F23)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: w * 0.08, offset: Offset(0, w * 0.04))],
            ),
          ),
        ),
        // AHBU kesiği
        Positioned(
          top: w * 0.075,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'AHBU',
              style: TextStyle(
                fontSize: w * 0.15,
                fontWeight: FontWeight.w900,
                letterSpacing: w * 0.012,
                color: const Color(0xFF050506),
                shadows: [Shadow(color: Colors.white.withValues(alpha: 0.18), offset: Offset(0, w * 0.004), blurRadius: 0)],
              ),
            ),
          ),
        ),
        // Kırmızı LED
        Positioned(
          top: w * 0.265,
          left: w * 0.5 - w * 0.012,
          child: Container(
            width: w * 0.024,
            height: w * 0.024,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _opened ? const Color(0xFF34D399) : const Color(0xFFEF4444),
              boxShadow: [
                BoxShadow(
                  color: (_opened ? const Color(0xFF34D399) : const Color(0xFFEF4444)).withValues(alpha: 0.8),
                  blurRadius: w * 0.03,
                ),
              ],
            ),
          ),
        ),
        // Ekran
        Positioned(
          top: w * 0.31,
          left: w * 0.17,
          width: w * 0.66,
          height: w * 0.9,
          child: _screen(w),
        ),
        // Buton
        Positioned(
          top: w * 1.27,
          left: w * 0.5 - w * 0.15,
          width: w * 0.3,
          height: w * 0.3,
          child: _button(w),
        ),
      ],
    );
  }

  Widget _screen(double w) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(w * 0.018),
        border: Border.all(color: const Color(0xFF3A3D44), width: w * 0.008),
      ),
      child: Padding(
        padding: EdgeInsets.all(w * 0.012),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.01),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: 240, height: 320, child: _screenContent()),
          ),
        ),
      ),
    );
  }

  Widget _screenContent() {
    const cyan = Color(0xFF22D3EE);
    final progress = _remaining / _qrLifetime;

    Widget statusDot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w600)),
          ],
        );

    return Container(
      color: const Color(0xFF0B1A2E),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _opened
            ? Column(
                key: const ValueKey('open'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.lock_open_rounded, color: Color(0xFF34D399), size: 64),
                  SizedBox(height: 12),
                  Text('KAPI AÇILDI', style: TextStyle(color: Color(0xFF34D399), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  SizedBox(height: 6),
                  Text('Hoş geldiniz', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )
            : Column(
                key: const ValueKey('qr'),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      statusDot(const Color(0xFF34D399), 'Wi-Fi VAR'),
                      statusDot(const Color(0xFF34D399), 'Mqtt VAR'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: cyan), borderRadius: BorderRadius.circular(3)),
                        child: const Text('AYAR', style: TextStyle(fontSize: 8, color: cyan, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('AHBU', style: TextStyle(color: cyan, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const Text('GİRİŞ İÇİN KAREKODU OKUTUN', style: TextStyle(color: cyan, fontSize: 8.5, letterSpacing: 0.4)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(6),
                    color: Colors.white,
                    child: QrImageView(
                      data: 'AHBU-DEMO-$_qrSeed',
                      size: 148,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(cyan),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Kalan Süre: $_remaining sn', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
      ),
    );
  }

  Widget _button(double w) {
    const glow = Color(0xFFC084FC);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        _openDoor();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [Color(0xFFE5E7EB), Color(0xFF6B7280), Color(0xFFF3F4F6), Color(0xFF6B7280), Color(0xFFE5E7EB)],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: w * 0.04, offset: Offset(0, w * 0.015))],
            ),
            padding: EdgeInsets.all(w * 0.02),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0C0C10),
                border: Border.all(color: glow, width: w * 0.008),
                boxShadow: [BoxShadow(color: glow.withValues(alpha: _opened ? 0.95 : 0.55), blurRadius: w * 0.05)],
              ),
              child: Center(
                child: Icon(Icons.key_rounded, color: Colors.white.withValues(alpha: 0.25), size: w * 0.11),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
