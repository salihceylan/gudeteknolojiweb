import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'line_icons.dart';

/// Teklif Pro bandı: sade yüzey (c.surface), ince üst/alt çizgi; solda metin, sağda düğme (dar ekranda alt alta).
/// Gradyan ve renk yok; açık temada beyaz yüzey ince çizgiyle çevrilir, koyuda grafit yüzey kullanılır.
class TeklifBand extends StatelessWidget {
  /// [onOpenLink] bağlantıyı açan işlevdir; varsayılanı [openLink]. Testlerde sahte işlevle değiştirilebilir.
  const TeklifBand({super.key, this.onOpenLink = openLink});

  final Future<void> Function(String url) onOpenLink;

  static const _titleMin = 22.0;
  static const _titleMax = 30.0;
  static const _leadMaxWidth = 640.0;
  static const _buttonGapWide = 56.0;
  static const _buttonGapNarrow = 28.0;
  static const _buttonMaxTextScale = 1.5; // düğme, çok büyük yazı ölçeğinde taşmasın

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = isWide(context);
    // Bant başlığı sahne başlığından (h2) bilinçli olarak küçüktür: bu bölüm bir çağrıdır, sahne değil.
    final s = fluid(context, _titleMin, _titleMax);
    final title = AppText.h2(context).copyWith(fontSize: s, letterSpacing: -s * 0.015);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('TEKLİF PRO'),
        const SizedBox(height: 14),
        Text('Teklif süreçlerini hızlı ve düzenli yönetin.', style: title),
        const SizedBox(height: 12),
        const Lead(
          'Teklif hazırlama, ürün yönetimi, revizyon takibi ve proje süreçlerini '
          'daha hızlı ve düzenli yönetmek için geliştirdiğimiz sistem.',
          maxWidth: _leadMaxWidth,
        ),
      ],
    );
    final button = MediaQuery.withClampedTextScaling(
      maxScaleFactor: _buttonMaxTextScale,
      child: _ExternalPillButton(label: 'Teklif Pro', onTap: () => onOpenLink(Contact.teklifPro)),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.symmetric(horizontal: BorderSide(color: c.line)),
      ),
      child: Section(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: fluid(context, 48, 72), horizontal: fluid(context, 24, 40)),
        child: Entrance(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: _buttonGapWide),
                    button,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [text, const SizedBox(height: _buttonGapNarrow), button],
                ),
        ),
      ),
    );
  }
}

/// Dış bağlantı düğmesi: dolgulu hap, etiketin SAĞINDA sağ üste giden çizgi oku.
///
/// Ortak [PillButton]'un simgesi etiketin soluna konur ve yalnızca Material ikonu alır; dış bağlantı oku ise sağda
/// ve sade çizgi diliyle olmalı. Bu yüzden görünüm burada çizilir; hit alanı, hover, klavye odağı ve Enter/Boşluk
/// ortak [FocusableTap]'tan gelir.
class _ExternalPillButton extends StatelessWidget {
  const _ExternalPillButton({required this.label, required this.onTap});

  static const _height = 44.0;
  static const _radius = 22.0;
  static const _paddingH = 22.0;
  static const _arrowSize = 16.0;
  static const _arrowGap = 8.0;
  static const _hoverTint = 0.18; // üzerine gelince dolguya karışan vurgu (PillButton ile aynı)

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = c.filledFg;
    return FocusableTap(
      label: label,
      link: true,
      onTap: onTap,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: _paddingH),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          color: hover ? Color.alphaBlend(c.accent.withValues(alpha: _hoverTint), c.filledBg) : c.filledBg,
          border: Border.all(color: focus ? c.accent : Colors.transparent, width: focus ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppText.buttonOf(context, color: fg)),
            const SizedBox(width: _arrowGap),
            LineIcon(LineGlyph.arrowUpRight, color: fg, size: _arrowSize),
          ],
        ),
      ),
    );
  }
}
