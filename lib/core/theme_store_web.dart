import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const _key = 'gude-theme';

/// Tarayıcı `localStorage` deposu. Özel gezinti vb. durumlarda erişim hata verebilir: sessizce yok sayılır.
class ThemeStore {
  ThemeStore._();

  static ThemeMode? read() {
    try {
      switch (web.window.localStorage.getItem(_key)) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
          return ThemeMode.system;
      }
    } catch (_) {}
    return null;
  }

  static void write(ThemeMode mode) {
    try {
      web.window.localStorage.setItem(_key, mode.name);
    } catch (_) {}
  }

  static void reset() {}

  /// Tarayıcı çubuğu/adres satırı rengi ve yükleme zemini görünür temayla uyumlu olsun.
  static void applyChrome(bool dark) {
    try {
      final color = dark ? '#06080B' : '#F4F5F7';
      web.document.documentElement?.setAttribute('data-theme', dark ? 'dark' : 'light');
      web.document.querySelector('meta[name="theme-color"]')?.setAttribute('content', color);
      web.document.querySelector('meta[name="color-scheme"]')?.setAttribute('content', dark ? 'dark' : 'light');
    } catch (_) {}
  }
}
