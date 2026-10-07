import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Üst çubuk ve yan panelin ortak bölüm listesi. [id] değerleri HomePage'deki sahne bağlantılarıyla eşleşir.
class NavItem {
  const NavItem(this.id, this.label, {String? panelLabel}) : panelLabel = panelLabel ?? label;

  final String id;

  /// Üst çubukta görünen kısa ad.
  final String label;

  /// Yan panelde görünen ad.
  final String panelLabel;
}

const kNavItems = [
  NavItem('camera', 'Kamera', panelLabel: 'Kamera Sistemleri'),
  NavItem('products', 'Ürünler'),
  NavItem('services', 'Hizmetler'),
  NavItem('process', 'Süreç'),
  NavItem('references', 'Referanslar'),
  NavItem('contact', 'İletişim'),
];

/// Logonun yüksekliği (px): 360 px genişlikte 84, 1440 px ve üzerinde 126. Boyutu değiştirmek için yalnızca bu iki sayı yeterlidir.
double logoHeightFor(double width) => fluidFor(width, 84, 126);

/// Sabit üst çubuğun yüksekliği: logo + üstte ve altta 8'er px. Yan panel ve testler aynı değeri kullanır.
double topBarHeightFor(double width) => logoHeightFor(width) + 16;

double topBarHeightOf(BuildContext context) => topBarHeightFor(MediaQuery.sizeOf(context).width);
