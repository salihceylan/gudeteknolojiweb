import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// İçerik en çok bu genişliğe kadar uzar.
const kMaxContent = 1200.0;

/// Sahne bölümü: tam genişlik zemin, ortalanmış içerik, akıcı dikey/yatay boşluk.
class Section extends StatelessWidget {
  const Section({super.key, required this.child, this.color, this.padding, this.minHeight, this.maxWidth = kMaxContent});

  final Widget child;
  final Color? color;
  final EdgeInsets? padding;
  final double? minHeight;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      color: color ?? context.colors.bg,
      padding: padding ?? EdgeInsets.symmetric(vertical: fluid(context, 64, 112), horizontal: fluid(context, 24, 40)),
      child: Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      ),
    );
  }
}

/// Küçük, büyük harfli bölüm etiketi: ince turkuaz çizgi + metin.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 22, height: 1, color: context.colors.accent),
        const SizedBox(width: 10),
        Flexible(child: Text(text.toUpperCase(), style: AppText.label(context), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.align = TextAlign.start});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Semantics(header: true, child: Text(text, textAlign: align, style: AppText.h2(context)));
}

/// Başlığın altındaki kısa açıklama.
class Lead extends StatelessWidget {
  const Lead(this.text, {super.key, this.maxWidth = 560, this.align = TextAlign.start});
  final String text;
  final double maxWidth;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(text, textAlign: align, style: AppText.body(context)),
    );
  }
}

class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, color: context.colors.line);
}

/// Dokunulabilir öğelerin en küçük kenarı (px). Görsel boyut küçük kalabilir; dokunma alanı bu kadar büyür.
const kMinTapTarget = 44.0;

/// Odaklanabilir, üzerine gelinebilir ortak dokunma alanı: Enter ve Boşluk ile çalışır, [builder] odak/üzerine gelme
/// durumunu alır (odak halkasını çizmek [builder]'ın işidir). Görsel boyutu korurken dokunma alanını en az
/// [minSize] x [minSize] yapar (WCAG 2.5.8). Üst çubuk, yan panel ve düğmeler aynı davranışı bu widget'tan alır.
class FocusableTap extends StatefulWidget {
  const FocusableTap({
    super.key,
    required this.onTap,
    required this.builder,
    required this.label,
    this.focusNode,
    this.link = false,
    this.selected,
    this.minSize = kMinTapTarget,
  });

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool hover, bool focus) builder;

  /// Ekran okuyucunun okuduğu ad.
  final String label;

  /// Dışarıdan odak yönetimi gerekiyorsa (ör. panel kapanınca odağı düğmeye geri vermek).
  final FocusNode? focusNode;

  /// Sayfa dışına giden bağlantı mı (anlamsal olarak "bağlantı"), yoksa düğme mi.
  final bool link;

  /// Seçilebilir öğelerde (tema seçici) seçili durum; null ise anlamsal olarak bildirilmez.
  final bool? selected;
  final double minSize;

  @override
  State<FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<FocusableTap> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !widget.link,
      link: widget.link,
      selected: widget.selected,
      label: widget.label,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: widget.minSize, minHeight: widget.minSize),
            child: Center(widthFactor: 1, heightFactor: 1, child: widget.builder(context, _hover, _focus)),
          ),
        ),
      ),
    );
  }
}

/// Düğme. [filled]: açık dolgu (birincil); aksi halde ince çerçeveli (ikincil).
/// Klavye ile odaklanabilir, Enter/Boşluk ile çalışır.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.filled = true, this.icon});

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = filled ? c.filledFg : c.text;
    return FocusableTap(
      label: label,
      onTap: onTap,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        // Sabit yükseklik değil en az 44 px: çok büyük yazı ölçeğinde etiket sarılır, düğme küçülmez ve taşmaz.
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: filled
              ? (hover ? Color.alphaBlend(c.accent.withValues(alpha: 0.18), c.filledBg) : c.filledBg)
              : (hover ? c.text.withValues(alpha: 0.06) : Colors.transparent),
          border: Border.all(
            color: focus ? c.accent : (filled ? Colors.transparent : (hover ? c.text.withValues(alpha: 0.4) : c.lineStrong)),
            width: focus ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, textAlign: TextAlign.center, style: AppText.buttonOf(context, color: fg))),
          ],
        ),
      ),
    );
  }
}
