import 'package:flutter/widgets.dart';

/// Ana kaydırma alanının denetleyicisini ve görünür yüksekliğini sahnelere ulaştırır.
/// Sahneler kaydırma konumuna (ör. açılış → kamera geçişi) buradan bağlanır.
class ScrollScope extends InheritedWidget {
  const ScrollScope({super.key, required this.controller, required this.viewportHeight, required super.child});

  final ScrollController controller;

  /// Kaydırma alanının (ekranın) yüksekliği.
  final double viewportHeight;

  static ScrollScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ScrollScope>();
    assert(scope != null, 'ScrollScope bulunamadı: sahne, HomePage altında kullanılmalı.');
    return scope!;
  }

  static ScrollScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ScrollScope>();

  @override
  bool updateShouldNotify(ScrollScope old) => controller != old.controller || viewportHeight != old.viewportHeight;
}
