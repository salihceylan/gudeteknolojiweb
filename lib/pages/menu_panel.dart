import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'nav_model.dart';

/// Bu yüksekliğin altında panel sıkışık yerleşimle çizilir (satır ve bölüm boşlukları daralır); aksi halde tema seçici
/// ve iletişim satırları kısa ekranlarda görünür alanın dışında kalır.
const kPanelCompactHeight = 800.0;

/// Panel açılırken öğelerin sırayla belirmesi: [i]. öğe, [count] öğe içinde, açılma ilerlemesi [v] 1'e vardığında
/// tam görünür (opak ve yerinde) olur. Aralıklar 1.0'ı aşarsa son öğe hiçbir zaman tamamlanmaz.
@visibleForTesting
double panelStagger(double v, int i, int count) {
  const span = 0.4; // her öğenin beliriş süresi (ilerlemenin payı)
  const step = 0.06; // öğeler arası gecikme
  final start = 1 - span - step * (count - 1) + i * step;
  return smooth01(remap01(v, start, start + span));
}

/// Sandviç düğmesiyle açılan yan panel. Sağdan yay eğrisiyle kayar; bağlantılar sırayla belirir.
/// Panel kapalıyken hiçbir şey çizmez ve dokunmaları engellemez. Klavye: açılınca odak [focusNode]'a geçer;
/// Esc ile kapatma ve odağı arkadaki sayfadan koruma HomePage'dedir (panelden bağımsız çalışması için).
class MenuPanel extends StatelessWidget {
  const MenuPanel({
    super.key,
    required this.menu,
    required this.activeId,
    required this.onNav,
    required this.onClose,
    required this.onTeklif,
    required this.focusNode,
  });

  final Animation<double> menu;
  final String? activeId;
  final ValueChanged<String> onNav;
  final VoidCallback onClose;
  final VoidCallback onTeklif;

  /// Panelin kök odak düğümü: HomePage açılışta odağı buraya verir.
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final phone = isPhone(context);
    final size = MediaQuery.sizeOf(context);
    final width = phone ? size.width : 400.0;
    final compact = size.height < kPanelCompactHeight;
    final reduce = reduceMotionOf(context);
    final c = context.colors;
    final hPad = fluid(context, 28, 40);
    final gap = compact ? 20.0 : 28.0;
    final count = kNavItems.length + 2; // bağlantılar + ayırıcı + alt grup

    return AnimatedBuilder(
      animation: menu,
      builder: (context, _) {
        final v = menu.value;
        if (v == 0) return const SizedBox.shrink();
        final slide = reduce ? v.roundToDouble() : const SpringCurve(damping: 0.85).transform(v.clamp(0.0, 1.0));

        double stagger(int i) => reduce ? 1 : panelStagger(v, i, count);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: ColoredBox(color: c.scrim.withValues(alpha: c.scrim.a * smooth01(v))),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: -width * (1 - slide),
              width: width,
              child: Focus(
                focusNode: focusNode,
                skipTraversal: true,
                child: Semantics(
                  scopesRoute: true,
                  explicitChildNodes: true,
                  label: 'Menü',
                  child: Material(
                    color: c.bgAlt,
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: c.line))),
                      child: SafeArea(
                        child: Column(
                          children: [
                            // Üst çubuğun yeri: kaydırılan içerik çubuğun arkasından geçmez, tam altında temiz kesilir.
                            SizedBox(height: topBarHeightOf(context)),
                            Expanded(
                              child: _EdgeFades(
                                color: c.bgAlt,
                                child: _PanelScroll(
                                  padding: EdgeInsets.fromLTRB(hPad, compact ? 24 : 40, hPad, 32),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Eyebrow('Menü'),
                                      SizedBox(height: gap),
                                      for (var i = 0; i < kNavItems.length; i++)
                                        _fade(
                                          stagger(i),
                                          _PanelLink(
                                            number: i + 1,
                                            label: kNavItems[i].panelLabel,
                                            active: kNavItems[i].id == activeId,
                                            compact: compact,
                                            onTap: () => onNav(kNavItems[i].id),
                                          ),
                                        ),
                                      SizedBox(height: gap),
                                      _fade(stagger(kNavItems.length), const HairlineDivider()),
                                      SizedBox(height: compact ? 16 : 24),
                                      _fade(
                                        stagger(kNavItems.length + 1),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            PillButton(label: 'Teklif Pro', icon: Icons.north_east_rounded, onTap: onTeklif),
                                            SizedBox(height: gap),
                                            _ContactLine(icon: Icons.phone_outlined, text: Contact.phoneDisplay, onTap: () => openLink(Contact.phoneUri)),
                                            _ContactLine(icon: Icons.mail_outline_rounded, text: Contact.email, onTap: () => openLink('mailto:${Contact.email}')),
                                            _ContactLine(icon: Icons.chat_bubble_outline_rounded, text: 'WhatsApp', onTap: () => openLink(Contact.whatsapp)),
                                            if (kThemeSwitchVisible) ...[SizedBox(height: gap), const ThemeSelector()],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fade(double p, Widget child) => Opacity(opacity: p, child: Transform.translate(offset: Offset(24 * (1 - p), 0), child: child));
}

/// Panelin kaydırma alanı. İçerik kısa ekrana sığmıyorsa ince bir kaydırma çubuğu hep görünür: dokunmatik ekranda
/// (çubuk normalde yoktur) paneli kaydırabileceğini gösteren tek ipucu budur. İçerik sığıyorsa çubuk çizilmez.
class _PanelScroll extends StatefulWidget {
  const _PanelScroll({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  State<_PanelScroll> createState() => _PanelScrollState();
}

class _PanelScrollState extends State<_PanelScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(context.colors.textFaint),
        thickness: const WidgetStatePropertyAll(3),
        radius: const Radius.circular(2),
        crossAxisMargin: 3,
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(controller: _controller, padding: widget.padding, child: widget.child),
      ),
    );
  }
}

/// Kaydırılan içeriğin alt ve üst kenarında yumuşak bir solma: içerik ekran dışına taşıyorsa kaydırılabildiği belli olur.
/// İçerik sığıyorsa solma boş dolgunun üstüne düştüğünden görünmez.
class _EdgeFades extends StatelessWidget {
  const _EdgeFades({required this.color, required this.child});

  final Color color;
  final Widget child;

  static const _height = 24.0;

  @override
  Widget build(BuildContext context) {
    Widget fade({required bool top}) => Positioned(
          top: top ? 0 : null,
          bottom: top ? null : 0,
          left: 0,
          right: 0,
          height: _height,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                  end: top ? Alignment.bottomCenter : Alignment.topCenter,
                  colors: [color, color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        );
    return Stack(children: [Positioned.fill(child: child), fade(top: true), fade(top: false)]);
  }
}

/// Tema seçici: Açık / Koyu / Sistem. Seçim kalıcıdır (bkz. ThemeController).
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final c = context.colors;
    const options = [
      (ThemeMode.light, 'Açık', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Koyu', Icons.dark_mode_outlined),
      (ThemeMode.system, 'Sistem', Icons.brightness_auto_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TEMA', style: AppText.label(context, color: c.textFaint)),
        const SizedBox(height: 10),
        Container(
          // Dikey boşluğu segmentlerin 44 px'lik dokunma alanı sağlar.
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: c.surface,
            border: Border.all(color: c.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (mode, label, icon) in options)
                _Segment(
                  label: label,
                  icon: icon,
                  selected: controller.mode == mode,
                  onTap: () => controller.setMode(mode),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = selected;
    return FocusableTap(
      label: '$label tema',
      selected: on,
      onTap: onTap,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        // Görünür yükseklik 38 px; 44 px'lik dokunma alanı içinde ortalanır, çerçeveye 3 px boşluk kalır.
        height: kMinTapTarget - 6,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: on ? c.surfaceHi : (hover ? c.surfaceHi.withValues(alpha: 0.5) : Colors.transparent),
          border: Border.all(color: focus ? c.accent : (on ? c.lineStrong : Colors.transparent), width: focus ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: on ? c.accentText : c.textDim),
            const SizedBox(width: 6),
            Text(label, style: AppText.small(context, color: on ? c.text : c.textDim)),
          ],
        ),
      ),
    );
  }
}

class _PanelLink extends StatelessWidget {
  const _PanelLink({required this.number, required this.label, required this.active, required this.compact, required this.onTap});

  final int number;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusableTap(
      label: label,
      onTap: onTap,
      builder: (context, hover, focus) {
        final lit = hover || focus || active;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 5 : 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                child: Text('0$number', style: AppText.label(context, color: lit ? c.accentText : c.textFaint)),
              ),
              Expanded(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(left: lit ? 8 : 0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(label, maxLines: 1, style: AppText.panelLink(context, color: lit ? c.text : c.textDim)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Telefon / e-posta / WhatsApp satırı: klavyeyle odaklanır, Enter ve Boşlukla açılır, odakta alt çizgi alır.
class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusableTap(
      label: text,
      link: true,
      onTap: onTap,
      builder: (context, hover, focus) {
        final lit = hover || focus;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: focus ? c.accentText : c.textDim),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small(context, color: c.text).copyWith(
                    decoration: lit ? TextDecoration.underline : TextDecoration.none,
                    decorationColor: c.accent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
