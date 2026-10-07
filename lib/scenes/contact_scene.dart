import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'line_icons.dart';

/// İletişim sahnesi + alt bilgi. Sol: etiket, başlık, gövde, WhatsApp düğmesi.
/// Sağ: Telefon / E-Posta / Adres satırları. Dar ekranda tek sütun.
class ContactScene extends StatelessWidget {
  /// [onOpenLink] bağlantıyı açan işlevdir; varsayılanı [openLink]. Testlerde sahte işlevle değiştirilebilir.
  const ContactScene({super.key, this.onOpenLink = openLink});

  final Future<void> Function(String url) onOpenLink;

  static const _leadMaxWidth = 520.0;
  static const _buttonMaxTextScale = 1.5; // düğme, çok büyük yazı ölçeğinde taşmasın

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final wide = isWide(context);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('İLETİŞİM'),
        const SizedBox(height: 16),
        const SectionTitle('Projenizi konuşalım.'),
        const SizedBox(height: 16),
        const Lead(
          'Yeni sistem kurulumu, mevcut sistemlerin yenilenmesi veya teknik servis '
          'ihtiyaçlarınız için bizimle iletişime geçebilirsiniz.',
          maxWidth: _leadMaxWidth,
        ),
        const SizedBox(height: 32),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: _buttonMaxTextScale,
          child: PillButton(label: 'WhatsApp\'tan Ulaşın', onTap: () => onOpenLink(Contact.whatsapp)),
        ),
      ],
    );

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContactRow(
          icon: LineGlyph.phone,
          label: 'Telefon',
          value: Contact.phoneDisplay,
          onTap: () => onOpenLink(Contact.phoneUri),
        ),
        _ContactRow(
          icon: LineGlyph.mail,
          label: 'E-Posta',
          value: Contact.email,
          onTap: () => onOpenLink('mailto:${Contact.email}'),
        ),
        const _ContactRow(
          icon: LineGlyph.pin,
          label: 'Adres',
          value: Contact.address,
        ),
        const HairlineDivider(),
      ],
    );

    return Section(
      color: c.bg,
      padding: EdgeInsets.only(
        top: fluid(context, 64, 112),
        bottom: fluid(context, 32, 40),
        left: fluid(context, 24, 40),
        right: fluid(context, 24, 40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: intro),
                      SizedBox(width: fluid(context, 32, 80)),
                      Expanded(flex: 5, child: rows),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [intro, SizedBox(height: fluid(context, 40, 56)), rows],
                  ),
          ),
          SizedBox(height: fluid(context, 64, 96)),
          const HairlineDivider(),
          const SizedBox(height: 24),
          Text('© 2026 Güde Teknoloji. Tüm hakları saklıdır.', style: AppText.small(context)),
        ],
      ),
    );
  }
}

/// İkon + etiket + değer satırı. [onTap] verilirse tıklanabilir (fare, dokunma ve klavye); aksi halde yalnızca bilgi.
class _ContactRow extends StatefulWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, this.onTap});

  final LineGlyph icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  static const _rowPaddingV = 20.0;
  static const _rowPaddingH = 4.0;
  static const _iconNudgeTop = 2.0; // ikonu etiketin ilk satırıyla hizalar
  static const _iconInset = 4.0;
  static const _iconGap = 18.0;
  static const _arrowSize = 18.0;
  static const _arrowGap = 12.0;
  static const _hoverTint = 0.035; // üzerine gelince satır zeminine karışan yazı rengi
  static const _iconAlpha = 0.9; // ikon çok hafif: vurgu rengi tam yoğunlukta değil

  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tappable = widget.onTap != null;
    final active = tappable && (_hover || _focus);
    final valueStyle = AppText.body(context, color: c.text).copyWith(height: 1.45);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.line),
          left: BorderSide(color: _focus ? c.accent : Colors.transparent, width: 2),
        ),
        // Yazı rengi iki temada da zeminin tersidir: koyuda hafif parlama, açıkta hafif gölge verir.
        color: active ? c.text.withValues(alpha: _hoverTint) : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(vertical: _rowPaddingV, horizontal: _rowPaddingH),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: _iconNudgeTop, left: _iconInset),
            child: LineIcon(widget.icon, color: c.accentText.withValues(alpha: _iconAlpha)),
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label.toUpperCase(), style: AppText.label(context)),
                const SizedBox(height: 6),
                Text(widget.value, style: valueStyle),
              ],
            ),
          ),
          if (tappable) ...[
            const SizedBox(width: _arrowGap),
            Padding(
              padding: const EdgeInsets.only(top: _iconNudgeTop, right: _iconInset),
              child: LineIcon(LineGlyph.arrowUpRight, color: active ? c.accentText : c.textDim, size: _arrowSize),
            ),
          ],
        ],
      ),
    );

    if (!tappable) {
      return Semantics(label: '${widget.label}: ${widget.value.replaceAll('\n', ', ')}', container: true, child: ExcludeSemantics(child: content));
    }
    return Semantics(
      link: true,
      label: '${widget.label}: ${widget.value}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap!();
            return null;
          }),
        },
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: content),
      ),
    );
  }
}
