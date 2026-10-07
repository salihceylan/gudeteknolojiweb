import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/reveal.dart';

/// Referanslar: tamamen statik tipografik ızgara. Akan yazı, logo ya da sayı yok; yalnızca proje adları.
/// Her isim ince bir üst çizgiyle ayrılır; üzerine gelince çizgi soldan turkuaza döner.
class ReferencesScene extends StatelessWidget {
  const ReferencesScene({super.key});

  static const _names = <String>[
    'Folkart Life',
    'Folkart Time',
    'Sinpaş Aqua City',
    'Manisa Meydan Projesi',
    'TÜPRAŞ Teknik Yapı',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = MediaQuery.sizeOf(context).width;
    final columns = w >= 900 ? 3 : (w >= 600 ? 2 : 1);
    final gapX = fluid(context, 16, 28);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HairlineDivider(),
        Section(
          color: c.bgAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Reveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('REFERANSLAR'),
                    const SizedBox(height: 16),
                    // Ortak SectionTitle başlık işaretlemesi taşımadığından burada sarılır.
                    Semantics(header: true, child: const SectionTitle('Bazı projelerimiz.')),
                  ],
                ),
              ),
              SizedBox(height: fluid(context, 28, 48)),
              _grid(columns, gapX),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(int columns, double gap) {
    final rows = <Widget>[];
    // Son satırdaki hücreler alt çizgiyle de kapanır; liste yarım kalmış görünmez.
    final lastRowStart = (_names.length - 1) ~/ columns * columns;
    for (var start = 0; start < _names.length; start += columns) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sütunlar tüm satırlarda aynı hizada kalır; son satırdaki boş hücreler yer tutar.
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(
                child: start + j < _names.length
                    ? Reveal(
                        delay: Duration(milliseconds: 70 * (start + j)),
                        child: _ReferenceCell(index: start + j, name: _names[start + j], closing: start == lastRowStart),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _ReferenceCell extends StatefulWidget {
  const _ReferenceCell({required this.index, required this.name, required this.closing});

  final int index;
  final String name;

  /// Hücrenin altına da ince çizgi çizilir (son satır).
  final bool closing;

  @override
  State<_ReferenceCell> createState() => _ReferenceCellState();
}

class _ReferenceCellState extends State<_ReferenceCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = reduceMotionOf(context);
    final vPad = fluid(context, 22, 32);
    final label = Text(widget.name, style: AppText.h3(context));

    // Hücreler bağlantı değil, yalnızca isim: klavye odağı almazlar, vurgu fare üzerine gelince oluşur.
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: RepaintBoundary(
        key: ValueKey('reference-cell-${widget.index}'),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _hover ? 1 : 0),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
          curve: const SpringCurve(),
          child: label,
          builder: (context, t, child) {
            final h = t.clamp(0.0, 1.0);
            return Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: vPad, bottom: vPad + 8),
                  child: Transform.translate(
                    // İsim hover'da birkaç piksel sağa kayar (yay hedefi çok az aşar).
                    offset: Offset(reduce ? 0 : 6 * t, 0),
                    child: child,
                  ),
                ),
                Positioned(left: 0, right: 0, top: 0, child: SizedBox(height: 1, child: ColoredBox(color: c.lineStrong))),
                if (widget.closing) Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(height: 1, child: ColoredBox(color: c.lineStrong))),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      key: ValueKey('reference-line-${widget.index}'),
                      widthFactor: h,
                      child: SizedBox(height: 1, child: ColoredBox(color: c.accent)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
