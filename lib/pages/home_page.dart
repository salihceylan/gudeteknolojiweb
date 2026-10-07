import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
import '../scenes/camera_scene.dart';
import '../scenes/contact_scene.dart';
import '../scenes/hero_camera_block.dart';
import '../scenes/process_scene.dart';
import '../scenes/references_scene.dart';
import '../scenes/remote_door_scene.dart';
import '../scenes/screen_door_scene.dart';
import '../scenes/services_scene.dart';
import '../scenes/teklif_band.dart';
import '../theme.dart';
import 'menu_panel.dart';
import 'nav_model.dart';
import 'scene_snap.dart';
import 'top_bar.dart';

/// Önizleme bayrağı: `flutter build web --dart-define=PREVIEW=true` ile derlenen sürümde adres çubuğundan
/// `?scroll=<ekran yüksekliği katı>`, `?menu=1` ve `?theme=light|dark` verilebilir (görsel kontrol için). Normal derlemede kapalıdır.
const kPreview = bool.fromEnvironment('PREVIEW');

/// Mıknatıs çapası olan sahneler (kamera bloğu hesapla bulunur). Teklif bandı menüde yoktur ama ayrı bir duraktır.
const _sceneIds = ['products', 'screen', 'services', 'process', 'references', 'teklif', 'contact'];

/// Pencere boyutu değişimi bu kadar durulunca (ms) önceki sahneye geri dönülür.
const _resizeSettle = Duration(milliseconds: 150);

/// Klavye ile sayfa kaydırma türleri.
enum _KeyScroll { lineUp, lineDown, pageUp, pageDown, home, end }

class _ScrollKeyIntent extends Intent {
  const _ScrollKeyIntent(this.kind);
  final _KeyScroll kind;
}

class _CloseMenuIntent extends Intent {
  const _CloseMenuIntent();
}

/// Panel kapalıyken sayfayı kaydıran tuşlar. Boşluk odaktaki düğmede (FocusableTap) önce onu çalıştırır;
/// buraya yalnızca düğme dışında bir yere odaklıyken ulaşır.
const _pageKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowDown): _ScrollKeyIntent(_KeyScroll.lineDown),
  SingleActivator(LogicalKeyboardKey.arrowUp): _ScrollKeyIntent(_KeyScroll.lineUp),
  SingleActivator(LogicalKeyboardKey.pageDown): _ScrollKeyIntent(_KeyScroll.pageDown),
  SingleActivator(LogicalKeyboardKey.pageUp): _ScrollKeyIntent(_KeyScroll.pageUp),
  SingleActivator(LogicalKeyboardKey.space): _ScrollKeyIntent(_KeyScroll.pageDown),
  SingleActivator(LogicalKeyboardKey.space, shift: true): _ScrollKeyIntent(_KeyScroll.pageUp),
  SingleActivator(LogicalKeyboardKey.home): _ScrollKeyIntent(_KeyScroll.home),
  SingleActivator(LogicalKeyboardKey.end): _ScrollKeyIntent(_KeyScroll.end),
};

/// Panel açıkken yalnızca Esc dinlenir: ok tuşları panelin kendi kaydırmasına kalır, sayfa yerinde durur.
const _panelKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.escape): _CloseMenuIntent(),
};

/// Tek sayfa: üst çubuk + sandviç panel + sahneler. Sahneler dikey scroll ile gezilir; sahne başlarında
/// çok hafif mıknatıs (SceneSnap) vardır.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scroll = ScrollController();
  late final AnimationController _menu = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    reverseDuration: const Duration(milliseconds: 420),
  );

  final _keys = <String, GlobalKey>{for (final id in _sceneIds) id: GlobalKey()};

  /// Odak düğümleri: sayfa (klavye kaydırması), panel (açılınca odak buraya geçer) ve sandviç düğmesi (kapanınca odak buraya döner).
  final _pageFocus = FocusNode(debugLabel: 'sayfa', skipTraversal: true);
  final _panelFocus = FocusNode(debugLabel: 'menü paneli', skipTraversal: true);
  final _menuFocus = FocusNode(debugLabel: 'menü düğmesi');

  late final SceneSnap _snap = SceneSnap(controller: _scroll, anchors: _anchors, viewportHeight: () => _vh);

  double _vh = 800;
  bool _scrolled = false;
  String? _active;

  /// Panel açık mı (açılıyor ya da açık). Klavye kısayollarını, odak tuzağını ve geri tuşunu belirler.
  bool _panelOpen = false;

  Timer? _resizeTimer;
  ({int index, double t})? _resizeFrom;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _menu.addStatusListener(_onMenuStatus);
    WidgetsBinding.instance.addObserver(this);
    if (kPreview) WidgetsBinding.instance.addPostFrameCallback((_) => _applyPreview());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resizeTimer?.cancel();
    _snap.dispose();
    _scroll.dispose();
    _menu.dispose();
    _pageFocus.dispose();
    _panelFocus.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _applyPreview() {
    final q = Uri.base.queryParameters;
    final s = double.tryParse(q['scroll'] ?? '');
    if (s != null && _scroll.hasClients) _scroll.jumpTo(s * _vh);
    if (q['menu'] == '1') _menu.value = 1;
    final theme = q['theme'];
    if (theme == 'light' || theme == 'dark') ThemeScope.of(context).setMode(theme == 'light' ? ThemeMode.light : ThemeMode.dark);
  }

  /// Pencere yeniden boyutlanınca ya da yakınlaşınca sahne yükseklikleri değişir; piksel ofseti korunursa kullanıcı iki
  /// sahnenin arasında kalır. Bu yüzden ilk olayda (yerleşim henüz eskiyken) sahne ve sahne içi oran kaydedilir,
  /// boyut durulunca yeni yerleşimde aynı yere dönülür.
  @override
  void didChangeMetrics() {
    if (!_scroll.hasClients) return;
    // Kullanıcı kaydırırken (ör. mobil tarayıcının adres çubuğu gizlenip ekran yüksekliğini değiştirirken) sayfa parmağın
    // altından kaçırılmaz; yalnızca duran sayfa yeniden hizalanır. (Boyut değişince sayfanın kendisi de kısa süre "kayıyor"
    // sayılır; bu yüzden durum yalnızca değişimin ilk olayında, yerleşim henüz eskiyken sorulur.)
    if (_resizeFrom == null && _scroll.position.isScrollingNotifier.value) return;
    _resizeFrom ??= _snap.locate(_scroll.offset);
    _resizeTimer?.cancel();
    _resizeTimer = Timer(_resizeSettle, _restoreAfterResize);
  }

  void _restoreAfterResize() {
    final from = _resizeFrom;
    _resizeFrom = null;
    if (from == null || !mounted || !_scroll.hasClients) return;
    final target = _snap.offsetFor(from).clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent);
    if ((target - _scroll.offset).abs() > 1) _scroll.jumpTo(target);
  }

  double _cameraOffset() => HeroCameraBlock.transitionDistance(_vh);

  /// Sahne [id]'sinin kaydırma ofseti (üst kenarı görünür alanın tepesine gelecek konum).
  double? _offsetOf(String id) {
    final ctx = _keys[id]?.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro == null || !ro.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    return viewport?.getOffsetToReveal(ro, 0).offset;
  }

  /// Mıknatıs çapaları: her sahnenin başlangıcı (artan sıralı).
  List<double> _anchors() {
    final list = <double>[0, _cameraOffset()];
    for (final id in _sceneIds) {
      final o = _offsetOf(id);
      if (o != null) list.add(o);
    }
    list.sort();
    return list;
  }

  double? _targetFor(String id) => id == 'camera' ? _cameraOffset() : _offsetOf(id);

  void _onScroll() {
    final y = _scroll.offset;
    final scrolled = y > 24;
    final active = _activeFor(y);
    if (scrolled != _scrolled || active != _active) {
      setState(() {
        _scrolled = scrolled;
        _active = active;
      });
    }
  }

  /// Üst çubukta vurgulanacak bölüm (ekranın üst %40'ına gelen son sahne).
  String? _activeFor(double y) {
    final probe = y + _vh * 0.4;
    String? current;
    for (final item in kNavItems) {
      final o = _targetFor(item.id);
      if (o != null && o <= probe) current = item.id;
    }
    return current;
  }

  void _goTo(String id) {
    final target = _targetFor(id);
    if (target == null) return;
    if (_menu.value > 0) _menu.reverse();
    _snap.scrollTo(target);
  }

  void _openTeklif() {
    if (_menu.value > 0) _menu.reverse();
    openLink(Contact.teklifPro);
  }

  void _toggleMenu() {
    if (_menu.status == AnimationStatus.forward || _menu.status == AnimationStatus.completed) {
      _menu.reverse();
    } else {
      _menu.forward();
    }
  }

  void _onMenuStatus(AnimationStatus status) {
    final open = status == AnimationStatus.forward || status == AnimationStatus.completed;
    if (open != _panelOpen && mounted) setState(() => _panelOpen = open);
    if (status == AnimationStatus.forward) {
      // Panel ilk karede kurulur; odak o zaman ona verilebilir. Odak panelde kalır, arkadaki sayfa odaktan çıkarılmıştır.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _panelOpen) _panelFocus.requestFocus();
      });
    } else if (status == AnimationStatus.dismissed) {
      // Panel ağaçtan kalkınca odak boşa düşmesin: klavye kullanıcısı kaldığı yere, sandviç düğmesine döner.
      _menuFocus.requestFocus();
    }
  }

  void _scrollByKey(_ScrollKeyIntent intent) {
    switch (intent.kind) {
      case _KeyScroll.lineUp:
        _snap.scrollLine(-1);
      case _KeyScroll.lineDown:
        _snap.scrollLine(1);
      case _KeyScroll.pageUp:
        _snap.scrollPage(-1);
      case _KeyScroll.pageDown:
        _snap.scrollPage(1);
      case _KeyScroll.home:
        _snap.scrollTo(0);
      case _KeyScroll.end:
        if (_scroll.hasClients) _snap.scrollTo(_scroll.position.maxScrollExtent);
    }
  }

  /// Boş bir yere tıklayınca (odak halkası kapanırken) klavye odağı sayfaya döner; kaydırma tuşları çalışmaya devam eder.
  void _reclaimFocus(PointerDownEvent _) {
    if (!_panelOpen && FocusManager.instance.primaryFocus != _pageFocus) _pageFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _snap.reduceMotion = reduceMotionOf(context);

    // Panel açıkken geri tuşu önce paneli kapatır (Android/tarayıcı geri), sonra sayfadan çıkar.
    return PopScope(
      canPop: !_panelOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _menu.reverse();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _vh = constraints.maxHeight;
          return ScrollScope(
            controller: _scroll,
            viewportHeight: _vh,
            child: Shortcuts(
              shortcuts: _panelOpen ? _panelKeys : _pageKeys,
              child: Actions(
                actions: {
                  _ScrollKeyIntent: CallbackAction<_ScrollKeyIntent>(onInvoke: _scrollByKey),
                  _CloseMenuIntent: CallbackAction<_CloseMenuIntent>(onInvoke: (_) => _menu.reverse()),
                },
                child: Focus(
                  focusNode: _pageFocus,
                  autofocus: true,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _reclaimFocus,
                    child: Scaffold(
                      backgroundColor: context.colors.bg,
                      body: Stack(
                        children: [
                          // Panel açıkken arkadaki sayfa klavye odağından çıkarılır (Tab panelden dışarı kaçmaz).
                          ExcludeFocus(
                            excluding: _panelOpen,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _snap.onNotification,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                child: Column(
                                  children: [
                                    HeroCameraBlock(
                                      cameraBuilder: (context, reveal) => CameraScene(reveal: reveal),
                                      onExplore: () => _goTo('camera'),
                                      onContact: () => _goTo('contact'),
                                    ),
                                    RemoteDoorScene(key: _keys['products'], onContact: () => _goTo('contact')),
                                    ScreenDoorScene(key: _keys['screen'], onContact: () => _goTo('contact')),
                                    ServicesScene(key: _keys['services']),
                                    ProcessScene(key: _keys['process']),
                                    ReferencesScene(key: _keys['references']),
                                    // Teklif bandı da bir duraktır: aksi halde Referanslar ile İletişim arasında atlanır.
                                    KeyedSubtree(key: _keys['teklif'], child: const TeklifBand()),
                                    ContactScene(key: _keys['contact']),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          MenuPanel(
                            menu: _menu,
                            activeId: _active,
                            onNav: _goTo,
                            onClose: _menu.reverse,
                            onTeklif: _openTeklif,
                            focusNode: _panelFocus,
                          ),
                          // Üst çubuk panelin üzerinde kalır: sandviç düğmesi açıkken kapatma düğmesine dönüşür.
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: TopBar(
                              scrolled: _scrolled,
                              activeId: _active,
                              menu: _menu,
                              onNav: _goTo,
                              onToggleMenu: _toggleMenu,
                              onLogo: () => _snap.scrollTo(0),
                              onTeklif: _openTeklif,
                              menuFocus: _menuFocus,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
