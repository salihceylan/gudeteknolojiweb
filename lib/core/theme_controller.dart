import 'package:flutter/material.dart';

import '../theme.dart';
import 'theme_store.dart';

/// Temanın TEK denetim noktası. Seçili modu ([ThemeMode.light], [ThemeMode.dark], [ThemeMode.system]) tutar,
/// kalıcı saklar ve değişince dinleyicilerini (MaterialApp) bilgilendirir. Palet tanımları lib/theme.dart'tadır.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemeMode? initial}) : _mode = initial ?? ThemeStore.read() ?? kDefaultThemeMode;

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    ThemeStore.write(mode);
    notifyListeners();
  }

  /// Görünür temayı tersine çevirir. [current] ekranda şu an görünen parlaklıktır
  /// (sistem modundayken hangisinin görünür olduğunu widget bilir).
  void toggle(Brightness current) => setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}

/// Ağaçtaki herhangi bir yerden [ThemeController]'a erişim: `ThemeScope.of(context).setMode(...)`.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child}) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope bulunamadı: GudeApp altında kullanılmalı.');
    return scope!.notifier!;
  }
}
