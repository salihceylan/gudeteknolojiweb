import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../brand/gude_logo.dart';
import '../core/scroll_scope.dart';
import '../core/theme_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'nav_model.dart';

/// Sabit üst çubuk: logo (şeffaf zeminli vektör) + normal menü (geniş ekranda) + Teklif Pro + sandviç düğmesi.
/// Normal menü, sandviç panelin yerine geçmez; ikisi birlikte vardır. Dar ekranda yalnızca sandviç kalır.
/// Panel açılırken menü bağlantıları solar; logo ve sandviç/kapat düğmesi panelin üstünde kalır.
///
/// Çubuk kaydırma alanının üstünde durur; yine de boş yerleri ve düğmeler üzerindeki fare tekerleği sayfayı kaydırır.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.scrolled,
    required this.activeId,
    required this.menu,
    required this.onNav,
    required this.onToggleMenu,
    required this.onLogo,
    required this.onTeklif,
    this.menuFocus,
  });

  final bool scrolled;
  final String? activeId;
  final Animation<double> menu;
  final ValueChanged<String> onNav;
  final VoidCallback onToggleMenu;
  final VoidCallback onLogo;
  final VoidCallback onTeklif;

  /// Sandviç düğmesinin odak düğümü: panel kapanınca klavye odağı buraya döner.
  final FocusNode? menuFocus;

  /// Düğmelerin üzerindeyken gelen tekerlek olayını sayfaya iletir (düğme olmayan yerlerde zaten doğrudan sayfaya gider).
  void _forwardWheel(BuildContext context, PointerSignalEvent event) {
    final controller = ScrollScope.maybeOf(context)?.controller;
    if (event is! PointerScrollEvent || controller == null || !controller.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      controller.position.pointerScroll(scroll.scrollDelta.dy);
      scroll.respond(allowPlatformDefault: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final hPad = fluid(context, 16, 32);
    final c = context.colors;

    // Arka plan ayrı ve dokunmaya kapalı bir katmandır: aksi halde bütün şerit tıklamaları ve tekerleği yutar
    // (üstte ölü bölge, sağ kenardaki kaydırma çubuğu tutulamaz).
    Widget background = DecoratedBox(
      decoration: BoxDecoration(
        color: scrolled ? c.bg.withValues(alpha: 0.72) : Colors.transparent,
        border: Border(bottom: BorderSide(color: scrolled ? c.line : Colors.transparent)),
      ),
    );
    if (scrolled) {
      background = ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: background));
    }

    final bar = SizedBox(
      height: topBarHeightOf(context),
      child: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: background)),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                children: [
                  _Logo(onTap: onLogo),
                  const Spacer(),
                  if (wide)
                    AnimatedBuilder(
                      animation: menu,
                      builder: (context, child) {
                        final hidden = menu.value > 0.05;
                        // Panel açıkken solan bağlantılara dokunulamaz ve klavyeyle de ulaşılamaz.
                        return ExcludeFocus(
                          excluding: hidden,
                          child: IgnorePointer(
                            ignoring: hidden,
                            child: Opacity(opacity: (1 - menu.value * 1.6).clamp(0.0, 1.0), child: child),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          for (final item in kNavItems) _NavLink(label: item.label, active: item.id == activeId, onTap: () => onNav(item.id)),
                          const SizedBox(width: 12),
                          _TopButton(label: 'Teklif Pro', icon: Icons.north_east_rounded, onTap: onTeklif),
                        ],
                      ),
                    ),
                  // Yuvarlak düğmeler 40 px görünür, 44 px dokunulur: aradaki boşluk, görünen aralık eskisi gibi kalsın diye kısaltıldı.
                  SizedBox(width: wide ? 14 : 0),
                  if (kThemeSwitchVisible) ...[const _ThemeButton(), const SizedBox(width: 4)],
                  _MenuButton(menu: menu, onTap: onToggleMenu, focusNode: menuFocus),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return SafeArea(bottom: false, child: Listener(onPointerSignal: (e) => _forwardWheel(context, e), child: bar));
  }
}

/// Üst çubuk öğelerinin ortak odak halkası: odaktayken 2 px vurgu rengi, aksi halde aynı kalınlıkta şeffaf
/// (öğe boyutu odakla değişmesin).
Border _ring(AppColors c, bool focus) => Border.all(color: focus ? c.accent : Colors.transparent, width: 2);

class _Logo extends StatelessWidget {
  const _Logo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusableTap(
      label: 'Güde Teknoloji, sayfanın başına git',
      onTap: onTap,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Plaka yok: logo vektördür ve sayfa zemininin (koyu ya da açık) üstünde doğrudan durur; odak halkası 2 px yer kaplar.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: focus ? c.accent : Colors.transparent, width: 2),
        ),
        child: GudeLogo(height: logoHeightFor(MediaQuery.sizeOf(context).width) - 4),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusableTap(
      label: label,
      onTap: onTap,
      builder: (context, hover, focus) => Container(
        // Kenarlık 2 px yer kaplar; dolgu bunu karşılar, böylece odak boyutu değiştirmez.
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: _ring(c, focus)),
        // Alt çizgi akış dışındadır: yazı çubuğun tam ortasında durur.
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(label, style: AppText.navOf(context, color: active || hover || focus ? c.text : c.textDim)),
            Positioned(
              bottom: -5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 1,
                width: active || focus ? 18 : (hover ? 10 : 0),
                color: c.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusableTap(
      label: label,
      onTap: onTap,
      link: true,
      builder: (context, hover, focus) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: hover ? c.text.withValues(alpha: 0.08) : Colors.transparent,
          border: Border.all(color: focus ? c.accent : c.lineStrong, width: focus ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.navOf(context, color: c.text)),
            const SizedBox(width: 6),
            Icon(icon, size: 14, color: c.text),
          ],
        ),
      ),
    );
  }
}

/// Yuvarlak, 40 px'lik çubuk düğmesinin ortak görünümü (dokunma alanı [FocusableTap] ile 44 px).
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.hover, required this.focus, required this.child});

  final bool hover;
  final bool focus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface.withValues(alpha: hover ? 1 : 0.85),
        border: Border.all(color: focus ? c.accent : c.lineStrong, width: focus ? 2 : 1),
      ),
      child: Center(child: child),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.menu, required this.onTap, this.focusNode});

  final Animation<double> menu;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FocusableTap(
      label: 'Menüyü aç veya kapat',
      onTap: onTap,
      focusNode: focusNode,
      builder: (context, hover, focus) => _RoundButton(
        hover: hover,
        focus: focus,
        child: AnimatedIcon(icon: AnimatedIcons.menu_close, progress: menu, size: 20, color: c.text),
      ),
    );
  }
}

/// Güneş/ay düğmesi: görünür temayı tersine çevirir (tek dokunuş). Ayrıntılı seçim yan paneldedir.
class _ThemeButton extends StatelessWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = c.isDark;
    return FocusableTap(
      label: dark ? 'Açık temaya geç' : 'Koyu temaya geç',
      onTap: () => ThemeScope.of(context).toggle(Theme.of(context).brightness),
      builder: (context, hover, focus) => _RoundButton(
        hover: hover,
        focus: focus,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            key: ValueKey(dark),
            size: 18,
            color: c.text,
          ),
        ),
      ),
    );
  }
}
