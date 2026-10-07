import 'package:flutter/material.dart';
import 'package:gudeteknolojiweb/theme.dart';

/// Testlerde iki temalı (açık + koyu) MaterialApp. [brightness] ile görünür tema seçilir.
/// Sahne widget'larını `testApp(Scaffold(body: ...))` ile sarın; ScrollScope gibi ek kapsamlar [home] içinde kurulur.
Widget testApp(Widget home, {Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
  );
}
