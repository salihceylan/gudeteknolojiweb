import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme_controller.dart';
import 'core/theme_store.dart';
import 'pages/home_page.dart';
import 'theme.dart';

void main() => runApp(const GudeApp());

class GudeApp extends StatefulWidget {
  const GudeApp({super.key, this.themeController});

  /// Testlerde hazır bir denetleyici verilebilir; verilmezse kayıtlı tercih/varsayılan mod kullanılır.
  final ThemeController? themeController;

  @override
  State<GudeApp> createState() => _GudeAppState();
}

class _GudeAppState extends State<GudeApp> {
  late final ThemeController _theme = widget.themeController ?? ThemeController();

  @override
  void dispose() {
    if (widget.themeController == null) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          title: 'Güde Teknoloji | Zayıf Akım ve Teknoloji Sistemleri',
          debugShowCheckedModeBanner: false,
          // Site Türkçedir: çözümlenen yerel ayar <html lang>'a yazılır (ekran okuyucu, çeviri önerisi, yazım denetimi).
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: _theme.mode,
          // Tema değişimi anlık değil, renklerin yumuşak karışmasıyla olur (AppColors.lerp).
          themeAnimationDuration: const Duration(milliseconds: 320),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) {
            // Tarayıcı çubuğu ve yükleme zemini görünür temayla uyumlu kalsın.
            ThemeStore.applyChrome(Theme.of(context).brightness == Brightness.dark);
            return child ?? const SizedBox.shrink();
          },
          home: const HomePage(),
        ),
      ),
    );
  }
}
