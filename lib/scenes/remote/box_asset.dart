import 'dart:ui';

/// Kutu görselinin (assets/images/ahbu_box.png, 1099x759, şeffaf zeminli CAD render) işaret noktaları.
/// Kaynak: assets/images/ahbu_box.json. Dosya çalışma zamanında okunmaz, sabitler buraya gömülüdür;
/// görsel değişirse yalnızca bu dosya güncellenir. Tüm koordinatlar görsele göre normalize (0..1).
abstract final class BoxAsset {
  static const assetPath = 'assets/images/ahbu_box.png';

  /// Genişlik / yükseklik.
  static const aspect = 1.448;

  /// Ön yüzdeki mavi LED deliği (sinyalin varacağı nokta).
  static const ledBlue = Offset(0.4286, 0.552);

  // JSON'daki diğer işaret noktaları. Sahne şimdilik yalnızca LED'i kullanır; görsel değişirse hepsi birlikte
  // güncellensin diye dosyanın tamamı korunur.

  /// LED'in üstündeki ışık deliği.
  static const lightHole = Offset(0.4258, 0.4638);

  /// Sol uçtaki USB-C girişi.
  static const usbC = Offset(0.2029, 0.3781);

  /// Soldaki küçük nokta (mikrofon deliği).
  static const dot = Offset(0.0692, 0.3439);

  /// Gövdenin ön-alt kenarının iki ucu (görselden ölçüldü). Zemin yansıması ve gölge bu doğruya oturur.
  static const floorA = Offset(0.041, 0.648);
  static const floorB = Offset(0.82, 0.968);
}
