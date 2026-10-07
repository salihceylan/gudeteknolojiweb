import 'package:flutter/material.dart';

/// Bellekte tutan depo (testler ve web dışı ortamlar).
class ThemeStore {
  ThemeStore._();

  static ThemeMode? _saved;

  static ThemeMode? read() => _saved;

  static void write(ThemeMode mode) => _saved = mode;

  /// Test başına temiz başlangıç için.
  static void reset() => _saved = null;

  /// Tarayıcı çubuğu rengi gibi web'e özgü yan etkiler: bellek deposunda yok.
  static void applyChrome(bool dark) {}
}
