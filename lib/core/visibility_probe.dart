import 'package:flutter/widgets.dart';

/// Çocuğunun kaydırma alanında görünür olup olmadığını bildirir. Sahneler, ekran dışındayken
/// animasyonlarını ([FrameLoop], döngüler) durdurmak için kullanır.
///
/// [margin]: görünür alanın alt/üst kenarından ne kadar önce "görünür" sayılacağı (piksel).
/// Kaydırma alanı yoksa (ör. widget testi) her zaman görünür kabul edilir.
class VisibilityProbe extends StatefulWidget {
  const VisibilityProbe({super.key, required this.builder, this.margin = 0, this.onChanged});

  final Widget Function(BuildContext context, bool visible) builder;
  final double margin;
  final ValueChanged<bool>? onChanged;

  @override
  State<VisibilityProbe> createState() => _VisibilityProbeState();
}

class _VisibilityProbeState extends State<VisibilityProbe> {
  ScrollPosition? _position;
  bool _visible = true;

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
    _position?.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || _position == null) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final viewport = MediaQuery.sizeOf(context).height;
    final visible = bottom > -widget.margin && top < viewport + widget.margin;
    if (visible != _visible) {
      setState(() => _visible = visible);
      widget.onChanged?.call(visible);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _visible);
}
