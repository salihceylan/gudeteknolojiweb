import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gudeteknolojiweb/pages/scene_snap.dart';

void main() {
  const vh = 800.0;
  // Açılış(0) → kamera(760) → ürün(1560) → uzun bölüm(2360) → sonraki(4200)
  final anchors = [0.0, 760.0, 1560.0, 2360.0, 4200.0];

  SceneSnap build({List<double>? at, double viewport = vh, double? max}) => SceneSnap(
        controller: ScrollController(),
        anchors: () => at ?? anchors,
        viewportHeight: () => viewport,
        maxExtent: max == null ? null : () => max,
      );

  group('sayfalama (tek ekranlık sahne)', () {
    test('yönsüz bırakışta en yakın sahneye yerleşir', () {
      final s = build();
      expect(s.targetFor(100, dir: 0), 0);
      expect(s.targetFor(500, dir: 0), 760);
      s.dispose();
    });

    test('tek tekerlek çentiği (100 px) her ekran boyunda bir sonraki sahneye geçirir', () {
      // Hata: eşik aralığın %12'siydi (900 px'te ~108 px); 100 px'lik çentik hep geri dönüyordu.
      for (final h in [640.0, 720.0, 900.0, 1080.0]) {
        final s = build(at: [0.0, h, h * 2, h * 3, h * 4], viewport: h);
        expect(s.targetFor(100, dir: 1), h, reason: 'vh=$h: aşağı çentik');
        expect(s.targetFor(h - 100, dir: -1), 0, reason: 'vh=$h: yukarı çentik');
        s.dispose();
      }
    });

    test('titreme boyutundaki kaydırma (48 px altı) başlangıca geri döner', () {
      final s = build(at: [0.0, 900.0, 1800.0, 2700.0], viewport: 900);
      expect(s.targetFor(30, dir: 1), 0);
      expect(s.targetFor(900 - 30, dir: -1), 900);
      s.dispose();
    });

    test('kısa aralıkta eşik aralığın %12\'sidir', () {
      final s = build(at: [0.0, 200.0, 1000.0, 1800.0], viewport: 900);
      expect(s.targetFor(20, dir: 1), 0); // 200 * 0.12 = 24
      expect(s.targetFor(30, dir: 1), 200);
      s.dispose();
    });

    test('ekran yüksekliğinin %102\'sine kadar olan sahne tek sayfa sayılır', () {
      final s = build(at: [0.0, vh * 1.02, 3000.0, 5000.0]);
      expect(s.targetFor(100, dir: 1), vh * 1.02);
      s.dispose();
    });
  });

  group('ekranı az aşan sahne', () {
    // 640 px ekranda 764 px'lik ürün sahnesi (1.19 kat): alt satırlarına inilebilmeli.
    final at = [0.0, 764.0, 1600.0, 2400.0, 3200.0];
    SceneSnap tall() => build(at: at, viewport: 640);

    test('tek çentik ve küçük adımlar sahnenin içinde kalır, sahne başına geri dönmez', () {
      final s = tall();
      expect(s.targetFor(120, dir: 1), isNull);
      expect(s.targetFor(40, dir: 1), isNull);
      expect(s.targetFor(124, dir: 1), isNull, reason: 'sahnenin son satırı ekranın dibinde');
      s.dispose();
    });

    test('sonu görüldükten sonra yeterince ilerlenirse bir sonraki sahneye geçer', () {
      final s = tall();
      expect(s.targetFor(124 + 49, dir: 1), 764);
      expect(s.targetFor(124 + 30, dir: 1), isNull);
      s.dispose();
    });

    test('yukarı doğru bırakınca sahne başına yaslanır', () {
      final s = tall();
      expect(s.targetFor(120, dir: -1), 0);
      expect(s.targetFor(764 - 20, dir: -1), 764);
      s.dispose();
    });
  });

  group('uzun bölüm', () {
    test('ortasında mıknatıs yoktur, kenarlarında vardır', () {
      final s = build();
      expect(s.targetFor(3300, dir: 0), isNull); // 2360..4200 arasının ortası
      expect(s.targetFor(2400, dir: 0), 2360); // üst kenara yakın, yön bilinmiyor → yaslan
      expect(s.targetFor(4100, dir: 0), 4200); // alt kenara yakın, yön bilinmiyor → sonraki sahne
      s.dispose();
    });

    test('yönde ilerlerken başlangıca geri çekmez, yukarı çekerken yaslar', () {
      final s = build();
      expect(s.targetFor(2400, dir: 1), isNull);
      expect(s.targetFor(2400, dir: -1), 2360);
      expect(s.targetFor(4100, dir: -1), isNull);
      s.dispose();
    });

    test('yakalama bölgesi en çok 120 px: büyük ekranda ekranın %22\'si kadar genişlemez', () {
      final s = build(at: [0.0, 4000.0, 9000.0], viewport: 1080);
      expect(s.targetFor(4100, dir: 0), 4000);
      expect(s.targetFor(4130, dir: 0), isNull);
      s.dispose();
    });
  });

  test('tek çapa ya da çapasız durumda null döner', () {
    final s = build(at: [0.0]);
    expect(s.targetFor(50), isNull);
    s.dispose();
  });

  group('son sahne ve sayfa sonu', () {
    test('son sahnenin içinde aşağı kaydırma ya da yönsüz bırakış yaslamaz; yalnızca yukarı çekerken başlangıca yaslanır', () {
      final s = build();
      expect(s.targetFor(4300, dir: 0), isNull);
      expect(s.targetFor(4300, dir: 1), isNull);
      expect(s.targetFor(4300, dir: -1), 4200);
      expect(s.targetFor(5200, dir: -1), isNull);
      s.dispose();
    });

    test('sayfa dibinde hiçbir yönde yerleşme yoktur', () {
      // Son sahne ekrandan biraz yüksek (telefon): dip, sahne başından 100 px aşağıda.
      final s = build(at: [0.0, 640.0, 1440.0], viewport: 640, max: 1540);
      for (final dir in [-1, 0, 1]) {
        expect(s.targetFor(1540, dir: dir), isNull, reason: 'dir=$dir');
      }
      s.dispose();
    });

    test('sayfa dibinden öteki çapalar ulaşılamaz: yerlerine sayfa dibi geçer', () {
      // 900 px ekranda İletişim çapası (2000) sayfa dibinden (1700) ötededir.
      final s = build(at: [0.0, 900.0, 1500.0, 2000.0], viewport: 900, max: 1700);
      expect(s.targetFor(1550, dir: 1), 1700);
      expect(s.targetFor(1650, dir: -1), 1500);
      s.dispose();
    });
  });

  group('konum kaydı (pencere yeniden boyutlanınca)', () {
    test('aynı sahne ve oran yeni yerleşimde aynı yere döner', () {
      var layout = [0.0, 700.0, 1500.0, 2300.0];
      final s = SceneSnap(controller: ScrollController(), anchors: () => layout, viewportHeight: () => vh, maxExtent: () => 3000);
      final at = s.locate(1900); // üçüncü sahnenin ortası: (1900-1500)/800
      expect(at.index, 2);
      expect(at.t, closeTo(0.5, 1e-9));
      layout = [0.0, 500.0, 1700.0, 3100.0];
      expect(s.offsetFor(at), 1700 + 0.5 * 1400);
      expect(s.offsetFor(s.locate(1500)), 1500, reason: 'sahne başındayken yeni sahne başına gider');
      s.dispose();
    });
  });

  group('kaydırma bildirimleriyle', () {
    // 360x640 telefon: son sahne (740 px) ekrandan yüksek, dip sahne başından 100 px aşağıda.
    const heights = [640.0, 800.0, 740.0];
    final starts = [0.0, 640.0, 1440.0];

    Widget harness(ScrollController c, SceneSnap snap, {ScrollPhysics? physics}) => MaterialApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: snap.onNotification,
            child: SingleChildScrollView(
              controller: c,
              physics: physics,
              child: Column(children: [for (final h in heights) SizedBox(height: h, width: double.infinity)]),
            ),
          ),
        );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('sayfa dibinde boş aşağı sürükleme hiçbir şeyi değiştirmez', (tester) async {
      // Hata: delta'sız ScrollEnd yönsüz sayılıp son sahnenin başına yaslıyordu; alt bilgi her seferinde ekran dışına kayıyordu.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ScrollController();
      final snap = SceneSnap(controller: c, anchors: () => starts, viewportHeight: () => 640);
      addTearDown(() {
        snap.dispose();
        c.dispose();
      });
      await tester.pumpWidget(harness(c, snap));
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();
      final bottom = c.offset;
      expect(bottom, 1540);

      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -60));
        await settle(tester);
        expect(c.offset, bottom, reason: 'bırakış #$i');
      }
    });

    testWidgets('iOS geri yaylanması (ters yönlü delta) sayfa sonunda yaslama yapmaz', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ScrollController();
      final snap = SceneSnap(controller: c, anchors: () => starts, viewportHeight: () => 640);
      addTearDown(() {
        snap.dispose();
        c.dispose();
      });
      await tester.pumpWidget(harness(c, snap, physics: const BouncingScrollPhysics()));
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -120));
      await settle(tester);
      expect(c.offset, closeTo(1540, 0.5));
    });

    testWidgets('gerçek yukarı kaydırma ve bırakış hâlâ sahne başına yaslar', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ScrollController();
      final snap = SceneSnap(controller: c, anchors: () => starts, viewportHeight: () => 640);
      addTearDown(() {
        snap.dispose();
        c.dispose();
      });
      await tester.pumpWidget(harness(c, snap));
      c.jumpTo(c.position.maxScrollExtent);
      await tester.pump();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 40)); // 40 px yukarı
      await settle(tester);
      expect(c.offset, closeTo(1440, 1), reason: 'son sahnenin başına yaslanmalı');
    });

    testWidgets('fare tekerleği: tek çentik bir sonraki sahneye yerleşir', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ScrollController();
      final snap = SceneSnap(controller: c, anchors: () => [0.0, 900.0, 1800.0, 2700.0], viewportHeight: () => 900);
      addTearDown(() {
        snap.dispose();
        c.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: NotificationListener<ScrollNotification>(
          onNotification: snap.onNotification,
          child: SingleChildScrollView(controller: c, child: Column(children: [for (var i = 0; i < 4; i++) const SizedBox(height: 900, width: double.infinity)])),
        ),
      ));

      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(700, 450)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await settle(tester);
      expect(c.offset, closeTo(900, 1));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await settle(tester);
      expect(c.offset, closeTo(1800, 1));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await settle(tester);
      expect(c.offset, closeTo(900, 1));
    });
  });
}
