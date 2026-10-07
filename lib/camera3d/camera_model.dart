import 'dart:math' as math;
import 'dart:typed_data';

import 'mesh.dart';
import 'shading.dart';

// YER TUTUCU: Bu dosya gerçek bir ürün modeli değil, kodla üretilen genel bir "bullet" güvenlik kamerasıdır
// (mat grafit gövde, güneşlik, ön lens kaplaması, IR LED halkası, küre-mafsallı ayak). Gerçek ürün görseli ya da
// modeli gelince bu dosya (ve camera_painter.dart'ın çağırdığı kurucu) değiştirilecektir.

const double _tau = math.pi * 2;

/// Model ekseni +z: objektif yönü. +y yukarı, +x sağ (sağ-el kuralı). Birim: gövde yarıçapı 0.5.
const double kZRear = -1.75;
const double kZFront = 1.85;

/// Parça kimlikleri (hata ayıklama ve parlama gibi özel işleme için).
abstract final class CamPart {
  static const body = 0;
  static const bezel = 1;
  static const glass = 2;
  static const lens = 3;
  static const led = 4;
  static const visor = 5;
  static const bracket = 6;
  static const plate = 7;
  static const gland = 8;
  static const glint = 9;
  static const status = 10;
  static const visorIn = 11;
  static const plateTop = 12;

  /// Derinlik önyargısı (model birimi, + = izleyiciye daha yakın sayılır), parça kimliğiyle indekslenir. İç içe
  /// kabuklarda (güneşlik gövdeyi sarar) merkez ağırlıklı sıralama yetmez: kabuğun dışı izleyiciye yakın, içi uzak
  /// sayılarak gövdeye göre kesin sıralanır. Ön cam ve üstündeki LED'ler tüm ön yapının (lens gövdesi, halka) dibinde durduğundan uzak sayılır: hep ilk çizilirler.
  /// Lens parlaması kubbenin üstünde durduğundan biraz yakın sayılır. Plakanın üst yüzü yalnızca yukarıdan görünür ve üstünde duran her şey
  /// ondan önde olduğundan biraz uzak sayılır.
  static const depthBias = <double>[0, 0, -0.5, 0, -0.5, 0.45, 0, 0, 0, 0.15, -0.5, -0.45, -0.2];
}

// --- Ürünün kendi malzeme renkleri: fiziksel olduklarından açık ve koyu temada AYNI kalır ---
final _cBody = Rgb.hex(0x1E2228);
final _cBodyRear = Rgb.hex(0x181B20);
final _cBodyFront = Rgb.hex(0x22262C);
final _cVisor = Rgb.hex(0x262A31);
final _cVisorIn = Rgb.hex(0x1A1C21);
final _cBezel = Rgb.hex(0x626974);
final _cBezelDark = Rgb.hex(0x383D45);
final _cEdge = Rgb.hex(0x9AA2AE);
final _cGlass = Rgb.hex(0x08090D);
final _cLensRim = Rgb.hex(0x15171D);
final _cLensA = Rgb.hex(0x261C70); // merkez: derin mavi-mor kaplama
final _cLensB = Rgb.hex(0x151A58);
final _cLensC = Rgb.hex(0x0B0E30);
final _cLensD = Rgb.hex(0x07081A);
final _cLed = Rgb.hex(0x4A0D10);
final _cBracket = Rgb.hex(0x3B4149);
final _cBall = Rgb.hex(0x5A626D);
final _cPlate = Rgb.hex(0x31363D);
final _cRubber = Rgb.hex(0x1D2024);

/// Ön camın ortak sıralama çıpası: cam, LED'ler, haleler ve durum LED'i aynı çıpayı paylaşır; böylece çıkartmalar
/// hiçbir açıda camın altında kalmaz (katman: cam 0, LED/durum 1, hale 2). Büyük düz cam, üstünde yükselen
/// lens gövdesine ve halkaya göre merkez ağırlığıyla sıralanamaz; bu yüzden [CamPart.depthBias] ile hep en dipte çizilir.
const _floorAnchor = V3(0, 0, 1.775);

/// Durum LED'i (turkuaz). Marka vurgusuyla aynı tonda ama fiziksel bir ışık olduğundan temadan bağımsızdır.
const _cStatus = Rgb(0.10, 0.55, 0.50);

/// Lens parlamasının ışığa göre konumlanan yelpazesi. Ağdaki köşeler yer tutucudur; her karede painter bu
/// köşelerin görünüm uzayı konumunu ve alfasını yeniden yazar.
class GlintSpec {
  GlintSpec({
    required this.firstVertex,
    required this.dx,
    required this.dy,
    required this.alpha,
    required this.center,
    required this.capRadius,
    required this.curvature,
  });

  /// Ağdaki ilk köşe indeksi; köşeler ardışıktır.
  final int firstVertex;

  /// Köşenin parlama merkezine göre yerel konumu (model birimi, ekrana paralel düzlem) ve temel alfası.
  final Float64List dx, dy, alpha;

  /// Lens kubbesinin merkezi (model uzayı), kubbenin yarıçapı ve parlamanın konumlandığı eğrilik yarıçapı.
  /// Eksen her zaman model +z'dir.
  final V3 center;
  final double capRadius, curvature;

  int get count => dx.length;
}

/// Hazır model: değişmez ağ + yardımcı veriler.
class CameraModel {
  CameraModel._(this.mesh, this.glint, this.pivot, this.groundY);

  final CameraMesh mesh;
  final GlintSpec glint;

  /// Dönme merkezi (sınırlayıcı kutunun ortası): ürün hangi açıda olursa olsun kutunun ortasında kalır.
  final V3 pivot;

  /// Zemin gölgesinin yüksekliği (model y).
  final double groundY;

  /// Çözünürlük [segs] (gövde çevresi için dilim sayısı): 36 → tam kalite, 18 → telefon (quality 0.5).
  static CameraModel build(int segs) => _Builder(segs).build();
}

double _smooth(double t) {
  final x = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
  return x * x * (3 - 2 * x);
}

class _Builder {
  _Builder(int segs)
      : s = math.max(16, (segs ~/ 2) * 2),
        b = MeshBuilder();

  /// Gövde çevresindeki dilim sayısı.
  final int s;
  final MeshBuilder b;

  int get sVisor => math.max(10, (s * 0.55).round());
  int get sLens => math.max(14, (s * 0.66).round());
  int get sSmall => math.max(12, (s * 0.45).round());
  int get sPlate => math.max(16, (s * 0.67).round());
  int get sLed => math.max(6, (s * 0.2).round());
  int get sBall => math.max(14, (s * 0.55).round());

  CameraModel build() {
    _body();
    _bezelAndFront();
    _lens();
    _leds();
    _visor();
    _bracket();
    _gland();
    final glint = _glintFan();
    final mesh = b.build();
    return CameraModel._(mesh, glint, const V3(0, -0.325, -0.02), -1.36);
  }

  // ---------------------------------------------------------------- gövde

  /// Çeyrek yay: merkez (cz, cr), yarıçap rad, açı a0→a1 (z,r düzleminde: (cos a, sin a)). İlk nokta atlanabilir.
  List<PP> _arc(double cz, double cr, double rad, double a0, double a1, int n, {Rgb? c0, Rgb? c1, int sub = 1, bool skipFirst = false}) {
    final out = <PP>[];
    for (var i = skipFirst ? 1 : 0; i <= n; i++) {
      final t = i / n;
      final a = a0 + (a1 - a0) * t;
      final col = (c0 != null && c1 != null) ? c0.lerp(c1, t) : null;
      out.add(PP(cz + rad * math.cos(a), cr + rad * math.sin(a), color: col, sub: sub));
    }
    return out;
  }

  void _body() {
    // Güneşliğin altında kalan üst yarım koyulaşsın (önceden pişirilmiş ortam kapanması).
    b.occlusion = (p, n) {
      final up = p.y / 0.5;
      final under = _smooth((up + 0.15) / 1.0);
      final zf = _smooth((p.z + 1.2) / 0.5);
      return 1 - 0.55 * under * zf;
    };
    final style = Style(Mats.graphite, _cBody, part: CamPart.body);
    final seam = _cBodyRear.scaled(0.28);
    final prof = <PP>[
      PP(kZRear, 0, color: _cBodyRear),
      PP(kZRear, 0.30, color: _cBodyRear),
      ..._arc(kZRear + 0.12, 0.30, 0.12, math.pi, math.pi / 2, 3, c0: _cBodyRear, c1: _cBodyRear, skipFirst: true),
      PP(-0.64, 0.50, color: _cBody),
      // ince ayrım çizgisi (arka kapak / gövde): tek halkalık koyu bant
      PP(-0.64, 0.50, color: seam),
      PP(-0.62, 0.50, color: seam),
      PP(-0.62, 0.50, color: _cBody, sub: 3),
      PP(1.55, 0.50, color: _cBodyFront),
    ];
    b.lathe(prof, segs: s, style: style);
    b.occlusion = null;
  }

  // ---------------------------------------------------------------- çerçeve ve ön yüz

  void _bezelAndFront() {
    b.occlusion = (p, n) {
      final up = p.y / 0.515;
      return 1 - 0.45 * _smooth((up + 0.1) / 1.0);
    };
    // basamak + silindir duvar (merkez ağırlıklı sıralama)
    b.lathe(
      [
        PP(1.55, 0.50, color: _cBezelDark),
        PP(1.55, 0.515, color: _cBezelDark),
        PP(1.55, 0.515, color: _cBezel),
        PP(1.78, 0.515, color: _cBezel),
      ],
      segs: s,
      style: Style(Mats.metal, _cBezel, part: CamPart.bezel),
    );
    b.occlusion = null;
    // pah + ön halka + iç duvar: gerçek 3B yapı (ön halka camın üstünde yükselir); küçük yüzleri merkez
    // ağırlığıyla doğru sıralanır. Yalnızca camın kendisi ve üstündeki çıkartmalar ortak çıpa + katman kullanır.
    final g = Style(Mats.edge, _cEdge, part: CamPart.bezel);
    b.lathe(
      [
        PP(1.78, 0.515, color: _cBezel, mat: Mats.edge),
        PP(1.85, 0.49, color: _cEdge, sharp: true, mat: Mats.metal),
        PP(1.85, 0.44, color: _cBezel, mat: Mats.metal, sharp: true),
        PP(1.77, 0.44, color: _cBezelDark, sharp: true),
      ],
      segs: s,
      style: g,
    );
    // cam (halka; ortası lens gövdesiyle örtülür)
    b.lathe(
      [PP(1.77, 0.44, color: _cGlass), PP(1.77, 0.22, color: _cGlass)],
      segs: s,
      style: Style(Mats.glass, _cGlass, anchor: _floorAnchor, layer: 0, feather: false, part: CamPart.glass),
    );
  }

  // ---------------------------------------------------------------- lens

  void _lens() {
    Style st(int mat, Rgb c) => Style(mat, c, part: CamPart.lens);
    final ls = sLens;
    // gövde: dış duvar
    b.lathe([PP(1.77, 0.26, color: _cLensRim), PP(1.84, 0.26, color: _cLensRim)], segs: ls, style: st(Mats.metal, _cLensRim));
    // üst halka (ince parlak pah)
    b.lathe([PP(1.84, 0.26, color: _cEdge), PP(1.84, 0.212, color: _cBezelDark)], segs: ls, style: st(Mats.edge, _cEdge));
    // içeri inen koni (iç duvar + taban) ve içerideki yükselen koni
    b.lathe([PP(1.84, 0.212, color: _cLensRim), PP(1.812, 0.164, color: _cLensD)], segs: ls, style: st(Mats.glass, _cLensRim).copy(feather: false));
    b.lathe([PP(1.812, 0.164, color: _cLensD, mat: Mats.metal), PP(1.842, 0.134, color: _cBezelDark)], segs: ls, style: st(Mats.metal, _cBezelDark));
    // kaplamalı cam kubbe: merkezden dışa renk geçişi (mavi-mor → koyu)
    final dome = <PP>[];
    const rc = 0.40;
    final radii = [0.134, 0.075, 0.0];
    final cols = [_cLensC, _cLensB, _cLensA];
    for (var i = 0; i < radii.length; i++) {
      final r = radii[i];
      dome.add(PP(1.862 - (rc - math.sqrt(rc * rc - r * r)), r, color: cols[i]));
    }
    b.lathe(dome, segs: ls, style: st(Mats.lens, _cLensA));
  }

  void _leds() {
    const zg = 1.77;
    final nLed = 8;
    for (var i = 0; i < nLed; i++) {
      final a = _tau * (i + 0.5) / nLed;
      final c = V3(0.345 * math.sin(a), 0.345 * math.cos(a), zg);
      final f = Frame.at(c);
      // yarım küre kubbe
      b.lathe(
        [PP(0.004, 0.034, color: _cLed), PP(0.012, 0.0, color: _cLed)],
        segs: sLed,
        style: Style(Mats.led, _cLed, anchor: _floorAnchor, layer: 1, feather: false, part: CamPart.led),
        frame: f,
      );
      // yumuşak kızıl hale
      b.lathe(
        [PP(0.006, 0.078, color: const Rgb(0.6, 0.05, 0.03, 0.0)), PP(0.006, 0.0, color: const Rgb(0.9, 0.08, 0.04, 0.34))],
        segs: sLed + 1,
        style: Style(Mats.glow, _cLed, anchor: _floorAnchor, layer: 2, feather: false, part: CamPart.led),
        frame: f,
      );
    }
    // durum LED'i (alt orta)
    final sc = const V3(0, -0.405, zg);
    final f = Frame.at(sc);
    b.lathe(
      [PP(0.004, 0.02, color: _cStatus), PP(0.004, 0.0, color: _cStatus)],
      segs: sLed + 2,
      style: Style(Mats.status, _cStatus, anchor: _floorAnchor, layer: 1, feather: false, part: CamPart.status),
      frame: f,
    );
    b.lathe(
      [PP(0.006, 0.07, color: const Rgb(0.1, 0.6, 0.55, 0.0)), PP(0.006, 0.0, color: const Rgb(0.1, 0.6, 0.55, 0.30))],
      segs: sLed + 2,
      style: Style(Mats.glow, _cStatus, anchor: _floorAnchor, layer: 2, feather: false, part: CamPart.status),
      frame: f,
    );
  }

  /// Lens parlaması: yer tutucu yelpaze (her karede painter konumlar).
  GlintSpec _glintFan() {
    const n = 10;
    final first = b.vertexCount;
    final dx = <double>[0], dy = <double>[0], al = <double>[1];
    const white = Rgb(1, 1, 1, 1);
    final style = Style(Mats.glow, white, anchor: const V3(0, 0, 1.862), layer: 0, feather: false, part: CamPart.glint);
    const nz = V3(0, 0, 1);
    final ids = <int>[b.vertex(const V3(0, 0, 1.86), nz, white, Mats.glow)];
    const radii = [0.011, 0.05];
    const alphas = [0.95, 0.0];
    for (var ring = 0; ring < radii.length; ring++) {
      for (var k = 0; k < n; k++) {
        final a = _tau * k / n;
        dx.add(radii[ring] * math.cos(a));
        dy.add(radii[ring] * math.sin(a));
        al.add(alphas[ring]);
        ids.add(b.vertex(V3(radii[ring] * math.cos(a), radii[ring] * math.sin(a), 1.86), nz, white.withAlpha(alphas[ring]), Mats.glow));
      }
    }
    // merkez → iç halka → dış halka
    for (var k = 0; k < n; k++) {
      final k1 = (k + 1) % n;
      b.tri(ids[0], ids[1 + k], ids[1 + k1], style);
    }
    for (var k = 0; k < n; k++) {
      final k1 = (k + 1) % n;
      b.quad(ids[1 + k], ids[1 + n + k], ids[1 + n + k1], ids[1 + k1], style);
    }
    return GlintSpec(
      firstVertex: first,
      dx: Float64List.fromList(dx),
      dy: Float64List.fromList(dy),
      alpha: Float64List.fromList(al),
      center: const V3(0, 0, 1.862),
      capRadius: 0.13,
      curvature: 0.22,
    );
  }

  // ---------------------------------------------------------------- güneşlik

  void _visor() {
    const th = 1.42;
    const rOut = 0.588, rIn = 0.54;
    const zR = -0.80, zF = 2.22;
    double warp(double t, double z) {
      final c = (1 - math.cos(t)) * 0.5;
      final f = _smooth((z - 0.2) / (zF - 0.2));
      final r = _smooth((-0.1 - z) / (-0.1 - zR));
      return z - 0.62 * c * f + 0.34 * c * r;
    }

    final zs = <double>[zR, 0.05, 0.85, 1.5, 1.95, zF];
    final zsIn = <double>[1.45, 1.85, zF];
    final sv = sVisor;
    final outer = Style(Mats.satin, _cVisor, part: CamPart.visor);
    b.lathe([for (final z in zs) PP(z, rOut, color: _cVisor)], segs: sv, style: outer, theta0: -th, theta1: th, zWarp: warp);
    final inner = Style(Mats.graphite, _cVisorIn, feather: false, part: CamPart.visorIn);
    b.lathe([for (final z in zsIn.reversed) PP(z, rIn, color: _cVisorIn)], segs: sv, style: inner, theta0: -th, theta1: th, zWarp: warp);
    // ön ve arka kenar (kalınlık yüzü): parlak işlenmiş kenar
    final edge = Style(Mats.edge, _cEdge, part: CamPart.visor);
    // Ön kenar bandı en belirgin eğri olduğundan kabuktan daha ince dilimlenir (çokgen köşeleri görünmesin).
    b.lathe([PP(zF, rOut, color: _cEdge), PP(zF, rIn, color: _cEdge)], segs: (sv * 1.6).round(), style: edge, theta0: -th, theta1: th, zWarp: warp);
    b.lathe([PP(zR, rIn, color: _cBezelDark), PP(zR, rOut, color: _cBezelDark)], segs: sv, style: edge, theta0: -th, theta1: th, zWarp: warp);
    // iki uzun yan kenar
    for (final side in [1.0, -1.0]) {
      final t = th * side;
      final nx = math.cos(t) * side, ny = -math.sin(t) * side;
      final n = V3(nx, ny, 0);
      final vo = <int>[], vi = <int>[];
      for (final z in zs) {
        final zw = warp(t, z);
        vo.add(b.vertex(V3(rOut * math.sin(t), rOut * math.cos(t), zw), n, _cBezelDark, Mats.edge));
        vi.add(b.vertex(V3(rIn * math.sin(t), rIn * math.cos(t), zw), n, _cBezelDark, Mats.edge));
      }
      for (var i = 0; i < zs.length - 1; i++) {
        b.quad(vo[i], vo[i + 1], vi[i + 1], vi[i], edge);
      }
    }
  }

  // ---------------------------------------------------------------- braket

  void _bracket() {
    // Dikey ekseni boyunca: yerel z = model +y (Frame.yUp). Bağlantı tabanı, boyun, küre mafsal, yuva, plaka.
    const cz = -0.05;
    final stemF = Frame.yUp(const V3(0, 0, cz));
    final bracket = Style(Mats.bracket, _cBracket, part: CamPart.bracket);
    // bağlantı tabanı: gövdenin altına gömülen yassı kutu (altı görünür, üstü gövdenin içinde kalır)
    b.lathe(
      [
        PP(-0.585, 0.12, color: _cBracket),
        PP(-0.585, 0.215, color: _cBracket, sharp: true),
        PP(-0.505, 0.215, color: _cBracket),
      ],
      segs: sSmall,
      style: bracket,
      frame: stemF,
    );
    // boyun, küre ve yuva yalnızca birbirine değer (kesişmez); merkez ağırlıklı sıralama yeter
    b.lathe(
      [PP(-0.69, 0.115, color: _cBracket), PP(-0.585, 0.115, color: _cBracket)],
      segs: sSmall ~/ 2 + 2,
      style: bracket,
      frame: stemF,
    );
    // küre mafsal
    const ballY = -0.86;
    const rb = 0.205;
    final ball = <PP>[];
    const nb = 8;
    // Küre, boynun girdiği yerde (r = 0.115) ve yuvanın üst halkasında kesilir: ikisiyle de kesişmez,
    // ek sıralama sorunu çıkmaz.
    final aTop = math.acos(0.115 / rb);
    final aBot = math.asin((-0.95 - ballY) / rb);
    for (var i = 0; i <= nb; i++) {
      final a = aBot + (aTop - aBot) * i / nb;
      ball.add(PP(rb * math.sin(a), rb * math.cos(a), color: _cBall));
    }
    b.lathe(ball, segs: sBall, style: Style(Mats.ball, _cBall, part: CamPart.bracket), frame: Frame.yUp(const V3(0, ballY, cz)));
    // yuva: küreyle kesişmeyen, yukarı doğru açılan konik boyun (üst halkası küreye değer)
    b.lathe(
      [
        PP(-1.16, 0.165, color: _cBracket, sharp: true),
        PP(-0.95, 0.215, color: _cBracket, sharp: true),
        PP(-0.95, 0.19, color: _cBall, mat: Mats.bracket),
      ],
      segs: sSmall,
      style: bracket,
      frame: stemF,
    );
    // montaj plakası (yerel z: alttan üste)
    const plateY = -1.235;
    b.lathe(
      [
        PP(0.0, 0.545, color: _cPlate, sharp: true),
        PP(0.012, 0.56, color: _cEdge, mat: Mats.edge),
        PP(0.058, 0.56, color: _cPlate, mat: Mats.bracket),
        PP(0.075, 0.53, color: _cEdge, mat: Mats.edge, sharp: true),
      ],
      segs: sPlate,
      style: Style(Mats.bracket, _cPlate, part: CamPart.plate),
      frame: Frame.yUp(const V3(0, plateY, cz)),
    );
    // üst yüz: vida delikleriyle aynı çıpa; yalnızca yukarıdan görünür, üstündeki her şey ondan önde sayılır
    const topY = plateY + 0.075;
    const plateAnchor = V3(0, topY, cz);
    b.lathe(
      [PP(0.075, 0.53, color: _cPlate, mat: Mats.bracket), PP(0.075, 0.0, color: _cPlate, mat: Mats.bracket)],
      segs: sPlate,
      style: Style(Mats.bracket, _cPlate, anchor: plateAnchor, layer: 0, part: CamPart.plateTop),
      frame: Frame.yUp(const V3(0, plateY, cz)),
    );
    // vida delikleri (plakanın üst yüzüne oturan koyu çıkartmalar)
    for (var i = 0; i < 3; i++) {
      final a = _tau * i / 3 + 0.5;
      final c = V3(0.38 * math.sin(a), topY, cz + 0.38 * math.cos(a));
      b.lathe(
        [PP(0.002, 0.04, color: const Rgb(0.003, 0.003, 0.004)), PP(0.002, 0.0, color: const Rgb(0.003, 0.003, 0.004))],
        segs: 10,
        style: Style(Mats.graphite, _cRubber, anchor: plateAnchor, layer: 1, part: CamPart.plateTop),
        frame: Frame.yUp(c),
      );
    }
  }

  // ---------------------------------------------------------------- kablo rakoru

  void _gland() {
    final style = Style(Mats.rubber, _cRubber, part: CamPart.gland);
    final gs = math.max(10, s ~/ 3);
    b.lathe(
      [
        PP(-2.30, 0.0, color: _cRubber),
        PP(-2.30, 0.05, color: _cRubber, sharp: true),
        PP(-2.12, 0.05, color: _cRubber),
        PP(-2.12, 0.095, color: _cRubber, sharp: true),
        PP(-1.92, 0.13, color: _cRubber),
        PP(-1.88, 0.13, color: _cRubber),
      ],
      segs: gs,
      style: style,
    );
    // altıgen somun
    b.lathe(
      [PP(-1.90, 0.0, color: _cBezelDark), PP(-1.90, 0.185, color: _cBezelDark, sharp: true), PP(-1.74, 0.185, color: _cBezel)],
      segs: 6,
      style: Style(Mats.metal, _cBezel, part: CamPart.gland),
      flat: true,
    );
  }
}
