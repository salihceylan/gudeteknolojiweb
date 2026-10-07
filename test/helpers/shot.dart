import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testlerde gerçek yazı tiplerini (Manrope + Material ikonları) yükler. `setUpAll` içinde çağırın.
/// Aksi halde testlerdeki varsayılan "Ahem" yazı tipi her harfi kare çizer ve taşma hataları uydurur.
Future<void> loadAppFonts() async {
  final manrope = FontLoader('Manrope')..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
  await manrope.load();
  try {
    final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  } catch (_) {
    // Ikon fontu bulunamazsa ikonlar kare görünür; görsel kontrol için sorun değil.
  }
}

/// [app]'i [size] boyutunda çizip PNG olarak kaydeder ve dosya yolunu döndürür (Read aracıyla görüntülenebilir).
/// Animasyon ilerletmek için [advance] adımlarını sırayla uygular (ör. [Duration(milliseconds: 400)] x3).
/// Çıktı: `<geçici klasör>/gt_shots/<name>.png`
Future<String> shot(
  WidgetTester tester,
  Widget app, {
  required Size size,
  required String name,
  double pixelRatio = 1,
  List<Duration> advance = const [Duration(milliseconds: 100), Duration(milliseconds: 600)],
}) async {
  tester.view.physicalSize = Size(size.width * pixelRatio, size.height * pixelRatio);
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: app));
  for (final d in advance) {
    await tester.pump(d);
  }
  return captureBoundary(tester, key, name: name, pixelRatio: pixelRatio);
}

/// Zaten çizilmiş bir [RepaintBoundary]'yi (GlobalKey ile) PNG'ye yazar. Etkileşim sonrası ikinci kare almak için.
///
/// flutter_test gölgeleri varsayılan olarak kapatır (`debugDisableShadows`); ekran görüntülerinde sert şeritler çıkar
/// ve açık temada yanıltır. Bu yüzden yakalama sırasında gölgeler açılıp ağaç yeniden boyanır ve sonra mutlaka kapatılır
/// (flutter_test, test bitiminde bu değişkenin değişmemiş olmasını denetler; bu yüzden tearDown'a güvenilmez).
Future<String> captureBoundary(WidgetTester tester, GlobalKey key, {required String name, double pixelRatio = 1}) async {
  final dir = Directory('${Directory.systemTemp.path}/gt_shots')..createSync(recursive: true);
  final path = '${dir.path}/$name.png';
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  debugDisableShadows = false;
  try {
    void repaintAll(RenderObject o) {
      o.markNeedsPaint();
      o.visitChildren(repaintAll);
    }

    repaintAll(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(data!.buffer.asUint8List());
    });
  } finally {
    debugDisableShadows = true;
  }
  return path;
}
