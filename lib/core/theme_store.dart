// Tema tercihinin kalıcı saklanması. Web'de tarayıcı `localStorage`, diğer ortamlarda (test) bellek.
// Bağlı depo derleme anında seçilir.
export 'theme_store_memory.dart' if (dart.library.js_interop) 'theme_store_web.dart';
