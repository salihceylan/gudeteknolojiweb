import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/rendering.dart';

import 'camera_model.dart';
import 'camera_pose.dart';
import 'mesh.dart';
import 'shading.dart';

// YER TUTUCU: Çizilen ürün, kodla üretilen genel bir "bullet" kameradır (bkz. camera_model.dart). Gerçek ürün
// görseli/modeli gelince yalnızca model değişir; bu dosyadaki oluşturucu (renderer) ve sözleşme aynı kalır.

/// Koyu temada zemin gölgesinin varsayılan rengi (`AppColors.dark.shadow` ile aynı: %55 siyah).
const Color kCameraShadowDark = Color(0x8C000000);

/// Kamera ürününü çizen hafif yazılım-3B oluşturucu.
///
/// * Arka planı ÇİZMEZ (şeffaf); yalnızca ürünü ve altındaki yumuşak zemin gölgesini çizer.
/// * Ürün verilen alana kenarlardan pay bırakarak ortalanır; [CameraPose.scale] ile ölçeklenir.
/// * Ürünün malzeme renkleri (grafit, metal, lens, LED) fiziksel olduğundan temadan bağımsızdır. Temaya bağlı
///   yalnızca iki şey dışarıdan verilir: zemin gölgesinin rengi/yoğunluğu ([shadowColor]) ve kenar (rim) ışığı
///   yoğunluğu ([rimStrength]; açık zeminde azaltılırsa kenarlarda "yapıştırılmış" bir hale oluşmaz).
/// * [quality] 0.5..1.0: düşükse dilim (segment) sayısı azalır (telefon).
/// * Açı sözleşmesi (radyan): yaw = 0 → objektif izleyiciye bakar, artan yaw objektifi ekranın soluna çevirir,
///   yaw = π → arkadan görünüm; pitch > 0 → izleyici ürüne yukarıdan bakar. Açılar sınırsızdır, painter sarar.
/// * [CameraPose.scale] 1'i aşarsa ürün kutudan taşar; kırpmak çağıranın işidir (ör. ClipRect).
///
/// Çizim yöntemi: görünür üçgenler derinliğe göre sıralanır (painter's algorithm), köşeler Gouraud gölgelendirilir
/// ve tek bir `drawVertices` çağrısıyla çizilir. Canvas bu üçgenleri kenar yumuşatmasız çizdiğinden silüet ve
/// malzeme sınırlarına 1 piksellik saydamlaşan şeritler eklenir.
class CameraProductPainter extends CustomPainter {
  CameraProductPainter({
    required this.pose,
    this.quality = 1.0,
    this.shadowColor = kCameraShadowDark,
    this.rimStrength = 1.0,
  }) : super(repaint: pose);

  final CameraPose pose;
  final double quality;

  /// Zemin gölgesinin rengi (alfa yoğunluğu içinde). Koyu: %55 siyah; açık: %20 koyu lacivert.
  final Color shadowColor;

  /// Kenar ışığı çarpanı: 1 = koyu zemin; açık zeminde ~0.4–0.6.
  final double rimStrength;

  /// Önerilen en/boy oranı (en ÷ boy). Ürün bu orana sahip bir kutuda, yaw'ın tam turunda ve eğim -8°..+12° için
  /// kenarlardan pay kalarak (gölgesiyle birlikte) sığar. Daha geniş kutuda yüksekliğe göre sığdırılır.
  static const double aspect = 1.6;

  /// Kutu yüksekliğinin kaç model birimine karşılık geldiği (gölge ve eğim payı dahil); ürünün kendisi ~2 birim yüksektir.
  static const double _fitHeightUnits = 3.2;

  /// Gözlemcinin uzaklığı (model birimi): büyük tutulur ki perspektif bozulması hafif kalsın.
  static const double _eye = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _Renderer.forQuality(quality).paint(canvas, size, pose, shadowColor, rimStrength);
  }

  @override
  bool shouldRepaint(CameraProductPainter old) =>
      old.pose != pose || old.quality != quality || old.shadowColor != shadowColor || old.rimStrength != rimStrength;

  /// Modeli (ağı) önceden kurar. İlk çizimde ~10–40 ms'lik bir kurulum olur; sahne ürünü göstermeden önce
  /// (ör. `initState` sonrası boşta) çağrılırsa ilk karede takılma olmaz. Tekrar çağrılması maliyetsizdir.
  static void warmUp({double quality = 1.0}) => _Renderer.forQuality(quality);

  /// Yalnızca testler: son çizimin ekran köşeleri (piksel), görünüm derinlikleri (+ = izleyiciye yakın), yüz
  /// görünürlükleri ve köşe renkleri (ARGB). Diziler bir sonraki çizimde üzerine yazılır; kopyalamadan saklamayın.
  @visibleForTesting
  static ({CameraMesh mesh, Float32List screen, Float64List viewZ, Uint8List visible, Int32List colors}) debugLastFrame(double quality) {
    final r = _Renderer.forQuality(quality);
    return (mesh: r.mesh, screen: r.outPos, viewZ: r.vz, visible: r.vis, colors: r.outCol);
  }

  /// Hata ayıklama / test: son çizimde çizilen üçgen sayısı (silüet yumuşatma şeritleri dahil).
  static int debugLastTriangleCount(double quality) => _Renderer.forQuality(quality).lastTriangleCount;

  /// Hata ayıklama / test: ürünün (gölge hariç) verilen açıdaki ekran sınırları; birim = dönme merkezindeki model birimi.
  static Rect debugBounds(double quality, double yaw, double pitch) => _Renderer.forQuality(quality).bounds(yaw, pitch);

  /// Hata ayıklama / test: son çizimde lens parlamasının şiddeti (0..1).
  static double debugGlint(double quality) => _Renderer.forQuality(quality).lastGlint;

  /// Hata ayıklama / test: ağdaki toplam üçgen sayısı.
  static int debugMeshTriangleCount(double quality) => _Renderer.forQuality(quality).mesh.faceCount;
}

/// Kalite başına tek örnek: ağ ve ara belleklerin hepsi bir kez ayrılır; karede nesne üretilmez
/// (yalnızca dart:ui'ın zorunlu tuttuğu tek bir [ui.Vertices]).
class _Renderer {
  _Renderer._(this.model)
      : mesh = model.mesh,
        nv = model.mesh.vertexCount,
        nf = model.mesh.faceCount {
    vx = Float64List(nv);
    vy = Float64List(nv);
    vz = Float64List(nv);
    stamp = Int32List(nv);
    vis = Uint8List(nf);
    emitted = Int32List(nf);
    keyA = Int32List(nf);
    keyB = Int32List(nf);
    idA = Int32List(nf);
    idB = Int32List(nf);
    outPos = Float32List(2 * (nv + _maxExtra));
    outCol = Int32List(nv + _maxExtra);
    outIdx = Uint16List(3 * nf + 6 * _maxExtra);
  }

  static final _cache = <int, _Renderer>{};

  static _Renderer forQuality(double quality) {
    final q = quality.isFinite ? quality.clamp(0.5, 1.0) : 1.0;
    var segs = (36 * q).round();
    segs -= segs % 2;
    // putIfAbsent karede kapanış (closure) üretirdi; önbellek isabetinde nesne oluşturulmaz.
    final hit = _cache[segs];
    if (hit != null) return hit;
    return _cache[segs] = _Renderer._(CameraModel.build(segs));
  }

  /// Silüet yumuşatma şeritleri için ek köşe üst sınırı.
  static const _maxExtra = 2400;

  /// Silüet yumuşatma şeridinin genişliği (mantıksal piksel). Yüksek çözünürlüklü ekranda şerit ~1 cihaz
  /// pikseli kalacak biçimde daralır (kenarlar bulanıklaşmaz).
  double _featherPx = 1.25;

  final CameraModel model;
  final CameraMesh mesh;
  final int nv, nf;
  final LightRig rig = LightRig();

  // Görünüm uzayı köşe konumları
  late final Float64List vx, vy, vz;
  late final Int32List stamp;
  late final Uint8List vis;
  late final Int32List emitted;
  late final Int32List keyA, keyB, idA, idB;
  final Int32List _counts = Int32List(256);
  late final Float32List outPos;
  late final Int32List outCol;
  late final Uint16List outIdx;
  int _frame = 0;
  double lastGlint = 0;
  int lastTriangleCount = 0;

  // Dönüş matrisi (satır öncelikli) ve çizim parametreleri
  double _r00 = 1, _r01 = 0, _r02 = 0, _r10 = 0, _r11 = 1, _r12 = 0, _r20 = 0, _r21 = 0, _r22 = 1;
  double _ppu = 100, _cx = 0, _cy = 0;

  static const double _d = CameraProductPainter._eye;

  // Gölge çizimi için önbellek (alloc-free)
  final Float64List _m4 = Float64List(16);
  ui.Paint? _shadowWide, _shadowCore;
  int _shadowKey = 0;
  final Paint _meshPaint = Paint()..color = const Color(0xFFFFFFFF);

  void paint(Canvas canvas, Size size, CameraPose pose, Color shadowColor, double rimStrength) {
    final yaw = pose.yaw, pitch = pose.pitch;
    final sy = math.sin(yaw), cy = math.cos(yaw);
    final sp = math.sin(pitch), cp = math.cos(pitch);
    _r00 = cy;
    _r01 = 0;
    _r02 = -sy;
    _r10 = -sp * sy;
    _r11 = cp;
    _r12 = -sp * cy;
    _r20 = cp * sy;
    _r21 = sp;
    _r22 = cp * cy;

    final fitH = CameraProductPainter._fitHeightUnits;
    final ppu = math.min(size.width / (fitH * CameraProductPainter.aspect), size.height / fitH) * pose.scale;
    if (ppu <= 0 || !ppu.isFinite) return;
    _ppu = ppu;
    _cx = size.width / 2;
    // Dikey pay: eğim -8°'de ön uç yukarı kalkar (üstte 1.5 birim), +12°'de gölge aşağı iner; dönme merkezi
    // kutunun ortasından biraz aşağıda durur ki iki uçta da kenar payı kalsın.
    _cy = size.height / 2 + ppu * 0.08;

    final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1.0;
    _featherPx = dpr >= 1.0 ? (1.25 / dpr).clamp(0.5, 1.25) : 1.25;

    rig.rimGain = rimStrength.isFinite ? rimStrength.clamp(0.0, 4.0) : 1.0;
    rig.update(pose.lightPhase);

    _drawShadow(canvas, shadowColor, pitch, sy, cy);

    final count = _build();
    if (count == 0) return;
    final v = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(outPos, 0, 2 * _vertTotal),
      colors: Int32List.sublistView(outCol, 0, _vertTotal),
      indices: Uint16List.sublistView(outIdx, 0, 3 * count),
    );
    canvas.drawVertices(v, BlendMode.modulate, _meshPaint);
    v.dispose();
    lastTriangleCount = count;
  }

  Rect bounds(double yaw, double pitch) {
    final sy = math.sin(yaw), cy = math.cos(yaw), sp = math.sin(pitch), cp = math.cos(pitch);
    final pv = model.pivot;
    var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    final pos = mesh.pos;
    for (var i = 0; i < nv; i++) {
      final x = pos[i * 3] - pv.x, y = pos[i * 3 + 1] - pv.y, z = pos[i * 3 + 2] - pv.z;
      final X = cy * x - sy * z;
      final Y = -sp * sy * x + cp * y - sp * cy * z;
      final Z = cp * sy * x + sp * y + cp * cy * z;
      final k = _d / (_d - Z);
      minX = math.min(minX, X * k);
      maxX = math.max(maxX, X * k);
      minY = math.min(minY, Y * k);
      maxY = math.max(maxY, Y * k);
    }
    return Rect.fromLTRB(minX, -maxY, maxX, -minY);
  }

  // ------------------------------------------------------------------ zemin gölgesi

  void _drawShadow(Canvas canvas, Color color, double pitch, double sy, double cy) {
    final key = color.toARGB32();
    if (_shadowWide == null || key != _shadowKey) {
      // Tema geçişi sırasında renk her karede değişir: eski gölgelendiriciler serbest bırakılır.
      _shadowWide?.shader?.dispose();
      _shadowCore?.shader?.dispose();
      _shadowKey = key;
      _shadowWide = _shadowPaint(color, 0.85);
      _shadowCore = _shadowPaint(color, 1.0);
    }
    // Zemin düzlemine hep biraz yukarıdan bakılıyormuş gibi (en az 0.16 rad) çizilir: ürün neredeyse göz
    // hizasındayken bile gölge ince bir elips olarak kalır.
    final ps = math.max(math.sin(pitch), math.sin(0.16));
    // geniş yumuşak gölge: ışık soldan-önden geldiği için hafifçe sağa ve arkaya kayar
    _shadowEllipse(canvas, 0.20, -0.14, 1.75, 0.66, ps, sy, cy, _shadowWide!);
    // temas gölgesi: plakanın hemen altında, daha koyu ve sıkı
    _shadowEllipse(canvas, 0.0, -0.05, 0.78, 0.60, ps, sy, cy, _shadowCore!);
  }

  /// Zemin düzleminde (model x,z) merkezli, modelin z (boy, yarı-eksen [a]) ve x (en, [b]) yönünde elips.
  void _shadowEllipse(Canvas canvas, double gx, double gz, double a, double b, double ps, double sy, double cy, ui.Paint paint) {
    final pv = model.pivot;
    final x = gx - pv.x, y = model.groundY - pv.y, z = gz - pv.z;
    final X = x * _r00 + y * _r01 + z * _r02;
    final Y = x * _r10 + y * _r11 + z * _r12;
    final Z = x * _r20 + y * _r21 + z * _r22;
    final k = _ppu * _d / (_d - Z);
    final cxs = _cx + X * k, cys = _cy - Y * k;
    // eksenler yaw ile döner; dikey bileşen bakış yüksekliği ps ile ölçeklenir
    _paintEllipse(canvas, cxs, cys, -sy * a * _ppu, ps * cy * a * _ppu, cy * b * _ppu, ps * sy * b * _ppu, paint, 1.0, 1.0);
  }

  ui.Paint _shadowPaint(Color c, double k) {
    final a = c.a * k;
    final base = c.withValues(alpha: 1.0);
    const stops = <double>[0.0, 0.22, 0.45, 0.68, 0.86, 1.0];
    const amp = <double>[1.0, 0.82, 0.52, 0.24, 0.07, 0.0];
    return Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        [for (final m in amp) base.withValues(alpha: a * m)],
        stops,
      );
  }

  void _paintEllipse(Canvas canvas, double cx, double cy, double ux, double uy, double vx, double vy, ui.Paint paint, double su, double sv) {
    final m = _m4;
    m[0] = ux * su;
    m[1] = uy * su;
    m[2] = 0;
    m[3] = 0;
    m[4] = vx * sv;
    m[5] = vy * sv;
    m[6] = 0;
    m[7] = 0;
    m[8] = 0;
    m[9] = 0;
    m[10] = 1;
    m[11] = 0;
    m[12] = cx;
    m[13] = cy;
    m[14] = 0;
    m[15] = 1;
    canvas.save();
    canvas.transform(m);
    canvas.drawCircle(Offset.zero, 1.0, paint);
    canvas.restore();
  }

  // ------------------------------------------------------------------ ağ

  int _vertTotal = 0;

  /// Bütün köşeleri dönüştürür/izdüşürür, görünür yüzleri derinliğe göre sıralar, gölgelendirir ve çizim
  /// dizilerini doldurur. Çizilecek üçgen sayısını döndürür.
  int _build() {
    _frame++;
    final pos = mesh.pos;
    final pv = model.pivot;
    final px0 = pv.x, py0 = pv.y, pz0 = pv.z;
    final r00 = _r00, r01 = _r01, r02 = _r02, r10 = _r10, r11 = _r11, r12 = _r12, r20 = _r20, r21 = _r21, r22 = _r22;
    final ppu = _ppu, cx = _cx, cy = _cy;
    final vx = this.vx, vy = this.vy, vz = this.vz, outPos = this.outPos;
    for (var i = 0; i < nv; i++) {
      final x = pos[i * 3] - px0, y = pos[i * 3 + 1] - py0, z = pos[i * 3 + 2] - pz0;
      final X = r00 * x + r01 * y + r02 * z;
      final Y = r10 * x + r11 * y + r12 * z;
      final Z = r20 * x + r21 * y + r22 * z;
      vx[i] = X;
      vy[i] = Y;
      vz[i] = Z;
      final k = ppu * _d / (_d - Z);
      outPos[i * 2] = cx + X * k;
      outPos[i * 2 + 1] = cy - Y * k;
    }

    final glintOn = _updateGlint();

    // cam yansıma degradesi için kamera ekseni ve cam merkezi
    rig.axX = r02;
    rig.axY = r12;
    rig.axZ = r22;
    {
      const gz = 1.77;
      rig.glassX = r02 * (gz - pz0) + r00 * (0 - px0) + r01 * (0 - py0);
      rig.glassY = r12 * (gz - pz0) + r10 * (0 - px0) + r11 * (0 - py0);
      rig.glassZ = r22 * (gz - pz0) + r20 * (0 - px0) + r21 * (0 - py0);
    }

    // Kablo rakoru gövdenin arkasında durur: önden bakınca gövdenin gerisinde (önce), arkadan bakınca önünde
    // (sonra) çizilmelidir; bu yüzden önyargısı bakış yönüne göre işaret değiştirir (yandan bakınca sıfırdır).
    final glandBias = -0.25 * (r22 * 4).clamp(-1.0, 1.0);

    // --- yüz geçişi: arka yüz ayıklama + sıralama anahtarı
    final idx = mesh.idx, anchor = mesh.anchor, layer = mesh.layer, part = mesh.part;
    var n = 0;
    final vis = this.vis;
    for (var f = 0; f < nf; f++) {
      final a = idx[f * 3], b = idx[f * 3 + 1], c = idx[f * 3 + 2];
      final ax = outPos[a * 2], ay = outPos[a * 2 + 1];
      final area = (outPos[b * 2] - ax) * (outPos[c * 2 + 1] - ay) - (outPos[b * 2 + 1] - ay) * (outPos[c * 2] - ax);
      if (area >= -1e-4 || (part[f] == CamPart.glint && !glintOn)) {
        vis[f] = 0;
        continue;
      }
      vis[f] = 1;
      final x = anchor[f * 3] - px0, y = anchor[f * 3 + 1] - py0, z = anchor[f * 3 + 2] - pz0;
      final X = r00 * x + r01 * y + r02 * z;
      final Y = r10 * x + r11 * y + r12 * z;
      final Z = r20 * x + r21 * y + r22 * z;
      final dz = _d - Z;
      final dist = math.sqrt(X * X + Y * Y + dz * dz);
      final pt = part[f];
      final bias = pt == CamPart.gland ? glandBias : CamPart.depthBias[pt];
      var q = ((_d + 4.0 - dist + bias) * (1048575.0 / 8.0)).toInt();
      if (q < 0) q = 0;
      if (q > 1048575) q = 1048575;
      keyA[n] = (q << 4) | layer[f];
      idA[n] = f;
      n++;
    }
    _radixSort(n);

    // --- çizim: gölgelendir + dizilere yaz
    final stamp = this.stamp, frame = _frame;
    final outCol = this.outCol, outIdx = this.outIdx;
    final twin = mesh.twin, flags = mesh.flags;
    final feather = _featherPx;
    var ni = 0;
    var extra = 0;
    var tris = 0;
    final ids = idB;
    for (var s = 0; s < n; s++) {
      final f = ids[s];
      final a = idx[f * 3], b = idx[f * 3 + 1], c = idx[f * 3 + 2];
      if (stamp[a] != frame) {
        stamp[a] = frame;
        _shadeVertex(a);
      }
      if (stamp[b] != frame) {
        stamp[b] = frame;
        _shadeVertex(b);
      }
      if (stamp[c] != frame) {
        stamp[c] = frame;
        _shadeVertex(c);
      }
      outIdx[ni++] = a;
      outIdx[ni++] = b;
      outIdx[ni++] = c;
      tris++;
      emitted[f] = frame;
      if ((flags[f] & 1) == 0) continue;
      for (var k = 0; k < 3; k++) {
        final va = k == 0 ? a : (k == 1 ? b : c);
        final vb = k == 0 ? b : (k == 1 ? c : a);
        final th = twin[f * 3 + k];
        if (th >= 0) {
          final tw = th ~/ 3;
          if (vis[tw] != 0) {
            // Görünür komşu: yalnızca sonradan çizilen yüz, belirgin renk farkı olan kenarını yumuşatır
            // (malzeme sınırları: parlak pah / koyu iç yüz gibi). Aynı yüzeyin kendi içindeki kenarlar atlanır.
            if (emitted[tw] != frame) continue;
            final tk = th - tw * 3;
            final ta = idx[tw * 3 + (tk + 1) % 3], tb = idx[tw * 3 + tk];
            if (_colorGap(outCol[va], outCol[ta]) + _colorGap(outCol[vb], outCol[tb]) < 2 * _edgeContrast) continue;
          }
        }
        if (extra + 2 > _maxExtra) break;
        final vc = k == 0 ? c : (k == 1 ? a : b);
        final ax = outPos[va * 2], ay = outPos[va * 2 + 1];
        final bx = outPos[vb * 2], by = outPos[vb * 2 + 1];
        final ex = bx - ax, ey = by - ay;
        final len = math.sqrt(ex * ex + ey * ey);
        if (len < 1e-3) continue;
        var nx = ey / len, ny = -ex / len;
        if (nx * (outPos[vc * 2] - ax) + ny * (outPos[vc * 2 + 1] - ay) > 0) {
          nx = -nx;
          ny = -ny;
        }
        nx *= feather;
        ny *= feather;
        final ia = nv + extra, ib = ia + 1;
        extra += 2;
        outPos[ia * 2] = ax + nx;
        outPos[ia * 2 + 1] = ay + ny;
        outPos[ib * 2] = bx + nx;
        outPos[ib * 2 + 1] = by + ny;
        outCol[ia] = outCol[va] & 0x00FFFFFF;
        outCol[ib] = outCol[vb] & 0x00FFFFFF;
        outIdx[ni++] = va;
        outIdx[ni++] = vb;
        outIdx[ni++] = ib;
        outIdx[ni++] = va;
        outIdx[ni++] = ib;
        outIdx[ni++] = ia;
        tris += 2;
      }
    }
    _vertTotal = nv + extra;
    return tris;
  }

  /// İki ARGB renk arasındaki mutlak kanal farkı toplamı (alfa hariç), 0..765.
  static int _colorGap(int p, int q) {
    final dr = ((p >> 16) & 255) - ((q >> 16) & 255);
    final dg = ((p >> 8) & 255) - ((q >> 8) & 255);
    final db = (p & 255) - (q & 255);
    return (dr < 0 ? -dr : dr) + (dg < 0 ? -dg : dg) + (db < 0 ? -db : db);
  }

  /// Bitişik iki görünür yüz arasında kenar yumuşatması için gereken en düşük renk farkı.
  static const _edgeContrast = 80;

  /// LSD taban sıralaması (24 bit anahtar, 3 geçiş). Sonuç idB'dedir; eşit anahtarlarda yüz sırası korunur.
  void _radixSort(int n) {
    var ks = keyA, ki = idA, kd = keyB, id = idB;
    final counts = _counts;
    for (var pass = 0; pass < 3; pass++) {
      final shift = pass * 8;
      counts.fillRange(0, 256, 0);
      for (var i = 0; i < n; i++) {
        counts[(ks[i] >> shift) & 255]++;
      }
      var sum = 0;
      for (var d = 0; d < 256; d++) {
        final c = counts[d];
        counts[d] = sum;
        sum += c;
      }
      for (var i = 0; i < n; i++) {
        final key = ks[i];
        final d = (key >> shift) & 255;
        final p = counts[d]++;
        kd[p] = key;
        id[p] = ki[i];
      }
      final tk = ks;
      ks = kd;
      kd = tk;
      final ti = ki;
      ki = id;
      id = ti;
    }
    // 3 geçiş sonunda sonuç "ki" (= son yazılan) dizisindedir; idB'ye hizala.
    if (!identical(ki, idB)) {
      for (var i = 0; i < n; i++) {
        idB[i] = ki[i];
      }
    }
  }

  void _shadeVertex(int v) {
    final X = vx[v], Y = vy[v], Z = vz[v];
    final nrm = mesh.nrm;
    final n0 = nrm[v * 3], n1 = nrm[v * 3 + 1], n2 = nrm[v * 3 + 2];
    final nx = _r00 * n0 + _r01 * n1 + _r02 * n2;
    final ny = _r10 * n0 + _r11 * n1 + _r12 * n2;
    final nz = _r20 * n0 + _r21 * n1 + _r22 * n2;
    final ex = -X, ey = -Y, ez = _d - Z;
    final il = 1 / math.sqrt(ex * ex + ey * ey + ez * ez);
    final col = mesh.col;
    rig.shade(X, Y, Z, nx, ny, nz, ex * il, ey * il, ez * il, col[v * 4], col[v * 4 + 1], col[v * 4 + 2], mesh.ao[v], Mats.table[mesh.mat[v]]);
    final a = (col[v * 4 + 3] * 255 + 0.5).toInt();
    outCol[v] = (a << 24) | (toByte(rig.outR) << 16) | (toByte(rig.outG) << 8) | toByte(rig.outB);
  }

  // ------------------------------------------------------------------ lens parlaması

  /// Lens kubbesindeki ışık yansımasını (parlama) konumlandırır; parlama görünmüyorsa false.
  /// İki sanal ışıktan (sol-üst, sağ-üst) lens kubbesine daha iyi denk gelen seçilir; böylece parlama yalnızca
  /// tek bir bakış aralığında değil, objektif sola da sağa da dönükken görünür.
  bool _updateGlint() {
    final g = model.glint;
    final pv = model.pivot;
    final cx = g.center.x - pv.x, cy = g.center.y - pv.y, cz = g.center.z - pv.z;
    final lx = _r00 * cx + _r01 * cy + _r02 * cz;
    final ly = _r10 * cx + _r11 * cy + _r12 * cz;
    final lz = _r20 * cx + _r21 * cy + _r22 * cz;
    // lens ekseni (görünüm uzayı) = R·(0,0,1)
    final ax = _r02, ay = _r12, az = _r22;
    var vx = -lx, vy = -ly, vz = _d - lz;
    final vl = 1 / math.sqrt(vx * vx + vy * vy + vz * vz);
    vx *= vl;
    vy *= vl;
    vz *= vl;
    final facing = ax * vx + ay * vy + az * vz;
    final fadeFace = _smoothstep((facing - 0.10) / 0.30);

    var best = 0.0, bx = 0.0, by = 0.0, bz = 0.0;
    for (var li = 0; li < 2; li++) {
      var hx = vx + (li == 0 ? rig.gx : rig.hx), hy = vy + (li == 0 ? rig.gy : rig.hy), hz = vz + (li == 0 ? rig.gz : rig.hz);
      final hl2 = hx * hx + hy * hy + hz * hz;
      if (hl2 < 1e-9) continue;
      final hl = 1 / math.sqrt(hl2);
      hx *= hl;
      hy *= hl;
      hz *= hl;
      final ha = hx * ax + hy * ay + hz * az;
      final off = g.curvature * math.sqrt(math.max(0.0, 1 - ha * ha));
      final inten = _smoothstep((g.capRadius - off) / (g.capRadius * 0.30)) * fadeFace * (li == 0 ? 1.0 : 0.8);
      if (inten > best) {
        best = inten;
        bx = hx - ha * ax;
        by = hy - ha * ay;
        bz = hz - ha * az;
      }
    }
    lastGlint = best;
    if (best < 0.01) return false;
    final k = g.curvature;
    final ox = lx + k * bx, oy = ly + k * by, oz = lz + k * bz;
    final sc = 0.65 + 0.35 * best;
    final base = g.firstVertex;
    final w = _d / (_d - oz);
    final kk = _ppu * w;
    for (var i = 0; i < g.count; i++) {
      final X = ox + g.dx[i] * sc, Y = oy + g.dy[i] * sc;
      final v = base + i;
      outPos[v * 2] = _cx + X * kk;
      outPos[v * 2 + 1] = _cy - Y * kk;
      stamp[v] = _frame;
      final a = (g.alpha[i] * best * 255 + 0.5).toInt();
      outCol[v] = (a << 24) | 0x00FFFFFF;
    }
    return true;
  }

  static double _smoothstep(double t) {
    final x = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    return x * x * (3 - 2 * x);
  }
}
