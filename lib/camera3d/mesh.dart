import 'dart:math' as math;
import 'dart:typed_data';

/// Üç boyutlu nokta/yön. Yalnızca model KURULURKEN kullanılır; karede (kare başına) hiç V3 üretilmez,
/// çizim döngüsü düz Float64List dizileri üzerinde çalışır.
class V3 {
  const V3(this.x, this.y, this.z);

  final double x, y, z;

  static const zero = V3(0, 0, 0);
  static const ux = V3(1, 0, 0);
  static const uy = V3(0, 1, 0);
  static const uz = V3(0, 0, 1);
}

/// Doğrusal-uzay renk (0..1) + alfa. Paleti sRGB onaltılık olarak yazarız; aydınlatma doğrusal uzayda yapılır,
/// sonuç karekökle (gamma ≈ 2) ekrana döner. Böylece koyu tonlar bantlaşmadan ve pürüzsüz geçiş yapar.
class Rgb {
  const Rgb(this.r, this.g, this.b, [this.a = 1.0]);

  /// 0xRRGGBB (sRGB) → yaklaşık doğrusal (gamma 2).
  factory Rgb.hex(int hex, [double a = 1.0]) {
    final r = ((hex >> 16) & 0xFF) / 255.0;
    final g = ((hex >> 8) & 0xFF) / 255.0;
    final b = (hex & 0xFF) / 255.0;
    return Rgb(r * r, g * g, b * b, a);
  }

  final double r, g, b, a;

  Rgb lerp(Rgb o, double t) => Rgb(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t);
  Rgb scaled(double k) => Rgb(r * k, g * k, b * k, a);
  Rgb withAlpha(double alpha) => Rgb(r, g, b, alpha);
}

/// Yerel eksen takımı: yerel (x,y,z) → model = o + ex·x + ey·y + ez·z. Yalnızca yön-koruyan (dönme) takımlar kullanılır.
class Frame {
  const Frame(this.o, this.ex, this.ey, this.ez);

  final V3 o, ex, ey, ez;

  static const world = Frame(V3.zero, V3.ux, V3.uy, V3.uz);

  /// Yerel z ekseni model +y olacak biçimde (dik duran parçalar: braket, mafsal).
  factory Frame.yUp(V3 origin) => Frame(origin, V3.ux, const V3(0, 0, -1), V3.uy);

  /// Dünya ekseniyle aynı, yalnızca [origin]'e ötelenmiş.
  factory Frame.at(V3 origin) => Frame(origin, V3.ux, V3.uy, V3.uz);

  V3 point(double x, double y, double z) => V3(
        o.x + ex.x * x + ey.x * y + ez.x * z,
        o.y + ex.y * x + ey.y * y + ez.y * z,
        o.z + ex.z * x + ey.z * y + ez.z * z,
      );

  V3 dir(double x, double y, double z) => V3(
        ex.x * x + ey.x * y + ez.x * z,
        ex.y * x + ey.y * y + ez.y * z,
        ex.z * x + ey.z * y + ez.z * z,
      );
}

/// Bir yüzey grubunun varsayılan biçemi. [anchor], sıralama (painter's algorithm) için yüzeyin "ait olduğu
/// nokta"dır: çıkartma (LED, lens kaplaması) gibi küçük parçalar, üstünde durdukları yüzeyle aynı derinlik
/// anahtarını paylaşır ve [layer] sırasıyla çizilir; böylece büyük zemin yüzeyi ile çıkartması hiçbir açıda
/// yer değiştirmez. Null ise yüzün kendi ağırlık merkezi kullanılır.
class Style {
  const Style(this.mat, this.color, {this.layer = 0, this.anchor, this.feather = true, this.part = 0});

  final int mat;
  final Rgb color;
  final int layer;
  final V3? anchor;

  /// Silüet kenarına 1 px'lik yumuşak (alfa azalan) şerit eklenir. Şeffaf çıkartmalarda kapalı olmalıdır.
  final bool feather;

  /// Hata ayıklama / denetim için parça kimliği.
  final int part;

  Style copy({int? mat, Rgb? color, int? layer, V3? anchor, bool? feather, int? part}) => Style(
        mat ?? this.mat,
        color ?? this.color,
        layer: layer ?? this.layer,
        anchor: anchor ?? this.anchor,
        feather: feather ?? this.feather,
        part: part ?? this.part,
      );
}

/// Dönel yüzey profilindeki bir nokta: eksen boyunca [z], eksenden uzaklık [r].
/// Noktadan sonraki kesit (segment) için malzeme/katman/alt bölüm bu noktanın alanlarından gelir.
class PP {
  const PP(this.z, this.r, {this.color, this.sharp = false, this.mat, this.sub = 1, this.layer, this.feather});

  final double z, r;

  /// Boşsa yüzey biçeminin rengi. İki nokta arasında doğrusal geçiş yapılır; sert renk basamağı için noktayı ikileyin.
  final Rgb? color;

  /// Keskin kenar: bu noktada normaller yumuşatılmaz (pah, köşe).
  final bool sharp;
  final int? mat;

  /// Bu noktadan sonraki kesiti kaç halkaya böleceği (düz yüzeylerde sıralama ve degrade için).
  final int sub;
  final int? layer;
  final bool? feather;
}

/// Tamamlanmış, değişmez ağ. Karedeki çizim döngüsü yalnızca bu düz dizileri okur.
class CameraMesh {
  CameraMesh({
    required this.vertexCount,
    required this.faceCount,
    required this.pos,
    required this.nrm,
    required this.col,
    required this.ao,
    required this.mat,
    required this.idx,
    required this.anchor,
    required this.layer,
    required this.flags,
    required this.part,
    required this.twin,
  });

  final int vertexCount;
  final int faceCount;

  /// Köşe konumu (3 ardışık: x,y,z). Dinamik çıkartmalar (lens parlaması) bu diziyi her karede günceller.
  final Float64List pos;
  final Float64List nrm;

  /// Köşe temel rengi: doğrusal r,g,b + alfa (4 ardışık).
  final Float64List col;

  /// Köşe başına önceden pişirilmiş ortam kapanması (1 = açık, 0 = tamamen kapalı).
  final Float64List ao;
  final Uint8List mat;

  /// Üçgen köşe indeksleri (3 ardışık), dış yüzeye bakarken saat yönünün tersi sarım.
  final Uint16List idx;

  /// Yüz başına sıralama çıpası (3 ardışık).
  final Float64List anchor;
  final Uint8List layer;

  /// bit0: silüet yumuşatma (feather).
  final Uint8List flags;
  final Uint8List part;

  /// Üçgenin her yarım kenarının (3·f + k, köşe k → k+1) komşu yarım kenarı (3·f' + k'); yoksa -1.
  final Int32List twin;

}

/// Ağ kurucu. Dönel yüzey ([lathe]) ve serbest üçgen/dörtgen ekler.
class MeshBuilder {
  /// Verilirse her köşenin ortam kapanması (0..1; küçük = daha karanlık) konum ve normale göre buradan gelir
  /// (önceden pişirilmiş: güneşliğin altındaki gövde, çerçevenin dibi gibi). Hem yaygın hem yansıma ışığını azaltır.
  double Function(V3 p, V3 n)? occlusion;

  final _px = <double>[], _py = <double>[], _pz = <double>[];
  final _nx = <double>[], _ny = <double>[], _nz = <double>[];
  final _cr = <double>[], _cg = <double>[], _cb = <double>[], _ca = <double>[];
  final _vm = <int>[];
  final _ao = <double>[];

  final _fi = <int>[];
  final _fax = <double>[], _fay = <double>[], _faz = <double>[];
  final _fl = <int>[], _ff = <int>[], _fp = <int>[];

  int get vertexCount => _px.length;
  int get faceCount => _fi.length ~/ 3;

  int vertex(V3 p, V3 n, Rgb c, int mat) {
    final occ = occlusion;
    _ao.add(occ == null ? 1.0 : occ(p, n).clamp(0.0, 1.0));
    _px.add(p.x);
    _py.add(p.y);
    _pz.add(p.z);
    _nx.add(n.x);
    _ny.add(n.y);
    _nz.add(n.z);
    _cr.add(c.r);
    _cg.add(c.g);
    _cb.add(c.b);
    _ca.add(c.a);
    _vm.add(mat);
    return _px.length - 1;
  }

  /// Üçgen ekler. Sarım, köşe normallerinin ortalamasına göre otomatik düzeltilir (dışa bakan yüz = CCW).
  /// Alanı yok sayılabilecek kadar küçük (dejenere) üçgenler atlanır.
  void tri(int a, int b, int c, Style s) {
    final ax = _px[a], ay = _py[a], az = _pz[a];
    final ux = _px[b] - ax, uy = _py[b] - ay, uz = _pz[b] - az;
    final vx = _px[c] - ax, vy = _py[c] - ay, vz = _pz[c] - az;
    final gx = uy * vz - uz * vy, gy = uz * vx - ux * vz, gz = ux * vy - uy * vx;
    if (gx * gx + gy * gy + gz * gz < 1e-14) return;
    final nx = _nx[a] + _nx[b] + _nx[c], ny = _ny[a] + _ny[b] + _ny[c], nz = _nz[a] + _nz[b] + _nz[c];
    final flip = gx * nx + gy * ny + gz * nz < 0;
    _fi
      ..add(a)
      ..add(flip ? c : b)
      ..add(flip ? b : c);
    final anc = s.anchor;
    if (anc != null) {
      _fax.add(anc.x);
      _fay.add(anc.y);
      _faz.add(anc.z);
    } else {
      _fax.add((ax + _px[b] + _px[c]) / 3);
      _fay.add((ay + _py[b] + _py[c]) / 3);
      _faz.add((az + _pz[b] + _pz[c]) / 3);
    }
    _fl.add(s.layer);
    _ff.add(s.feather ? 1 : 0);
    _fp.add(s.part);
  }

  void quad(int a, int b, int c, int d, Style s) {
    tri(a, b, c, s);
    tri(a, c, d, s);
  }

  /// Dönel yüzey. Profil (z, r) çifti [frame] içinde yerel z ekseni etrafında [theta0]..[theta1] aralığında döndürülür;
  /// θ = 0 yerel +y yönüdür, artan θ yerel +x'e doğru gider.
  ///
  /// Profil, dışarıdan bakıldığında yüzeyin arka→ön (veya dış kenar→eksen) sırasıyla yazılır; kesitin normali
  /// (nz, nr) = (-dr, dz) / |t| olduğundan yön yanlışsa normaller içe bakar.
  /// [zWarp]: θ'ya bağlı z kaydırması (güneşliğin kavisli ön kenarı için). Normaller bundan etkilenmez.
  /// [flat]: her dörtgene kendi (yüz) normali verilir (altıgen somun gibi köşeli gövdeler için).
  void lathe(
    List<PP> prof, {
    required int segs,
    required Style style,
    Frame frame = Frame.world,
    double theta0 = 0,
    double theta1 = math.pi * 2,
    double Function(double theta, double z)? zWarp,
    bool flat = false,
  }) {
    final nSeg = prof.length - 1;
    if (nSeg < 1) return;

    // Kesit normalleri (nz, nr)
    final snz = List<double>.filled(nSeg, 0), snr = List<double>.filled(nSeg, 0);
    final ok = List<bool>.filled(nSeg, true);
    for (var j = 0; j < nSeg; j++) {
      final dz = prof[j + 1].z - prof[j].z, dr = prof[j + 1].r - prof[j].r;
      final len = math.sqrt(dz * dz + dr * dr);
      if (len < 1e-9) {
        ok[j] = false;
        continue;
      }
      snz[j] = -dr / len;
      snr[j] = dz / len;
    }

    (double, double) avg(double az, double ar, double bz, double br) {
      final z = az + bz, r = ar + br;
      final l = math.sqrt(z * z + r * r);
      return l < 1e-9 ? (az, ar) : (z / l, r / l);
    }

    for (var j = 0; j < nSeg; j++) {
      if (!ok[j]) continue;
      final p0 = prof[j], p1 = prof[j + 1];
      var sz = snz[j], sr = snr[j], ez = snz[j], er = snr[j];
      if (!p0.sharp && j > 0 && ok[j - 1]) (sz, sr) = avg(snz[j - 1], snr[j - 1], snz[j], snr[j]);
      if (!p1.sharp && j + 1 < nSeg && ok[j + 1]) (ez, er) = avg(snz[j], snr[j], snz[j + 1], snr[j + 1]);

      final mat = p0.mat ?? style.mat;
      final seg = style.copy(layer: p0.layer, feather: p0.feather);
      final c0 = p0.color ?? style.color, c1 = p1.color ?? style.color;
      final sub = math.max(1, p0.sub);

      if (flat) {
        // Her dörtgen kendi köşelerini ve tek (yüz) normalini alır; yumuşatma yoktur.
        V3 point(double th, double zz, double rr) =>
            frame.point(rr * math.sin(th), rr * math.cos(th), zWarp == null ? zz : zWarp(th, zz));
        for (var k = 0; k < sub; k++) {
          final ta0 = k / sub, tb0 = (k + 1) / sub;
          final za = p0.z + (p1.z - p0.z) * ta0, zb = p0.z + (p1.z - p0.z) * tb0;
          final ra = p0.r + (p1.r - p0.r) * ta0, rb = p0.r + (p1.r - p0.r) * tb0;
          final ca = c0.lerp(c1, ta0), cb = c0.lerp(c1, tb0);
          for (var i = 0; i < segs; i++) {
            final th0 = theta0 + (theta1 - theta0) * i / segs;
            final th1 = theta0 + (theta1 - theta0) * (i + 1) / segs;
            final tm = (th0 + th1) / 2;
            final n = frame.dir(snr[j] * math.sin(tm), snr[j] * math.cos(tm), snz[j]);
            final a = vertex(point(th0, za, ra), n, ca, mat);
            final b = vertex(point(th1, za, ra), n, ca, mat);
            final c = vertex(point(th1, zb, rb), n, cb, mat);
            final d = vertex(point(th0, zb, rb), n, cb, mat);
            quad(a, b, c, d, seg);
          }
        }
        continue;
      }

      List<int>? prev;
      for (var k = 0; k <= sub; k++) {
        final t = k / sub;
        final z = p0.z + (p1.z - p0.z) * t;
        final r = p0.r + (p1.r - p0.r) * t;
        var nz = sz + (ez - sz) * t, nr = sr + (er - sr) * t;
        final nl = math.sqrt(nz * nz + nr * nr);
        if (nl > 1e-9) {
          nz /= nl;
          nr /= nl;
        }
        final c = c0.lerp(c1, t);
        final ring = List<int>.filled(segs + 1, 0);
        for (var i = 0; i <= segs; i++) {
          final th = theta0 + (theta1 - theta0) * i / segs;
          final zw = zWarp == null ? z : zWarp(th, z);
          final s = math.sin(th), co = math.cos(th);
          ring[i] = vertex(frame.point(r * s, r * co, zw), frame.dir(nr * s, nr * co, nz), c, mat);
        }
        if (prev != null) {
          for (var i = 0; i < segs; i++) {
            quad(prev[i], prev[i + 1], ring[i + 1], ring[i], seg);
          }
        }
        prev = ring;
      }
    }
  }

  /// Bitirir: komşuluk (twin) tablosunu kurar ve değişmez [CameraMesh] üretir.
  CameraMesh build() {
    final nv = vertexCount, nf = faceCount;
    assert(nv < 65535, 'Köşe sayısı Uint16 indeks sınırını aştı');

    // Konuma göre benzersiz kimlik: farklı normalli (bölünmüş) köşeler aynı kenarı paylaşabilsin.
    // Koordinatlar 5e-5 birime yuvarlanıp tek bir tam sayıda (3 × 17 bit < 2^53: web'de de kesin) paketlenir.
    final posId = <int, int>{};
    final vid = List<int>.filled(nv, 0);
    int q(double v) => (v * 2e4).round() + 65536;
    for (var i = 0; i < nv; i++) {
      final key = (q(_px[i]) * 131072 + q(_py[i])) * 131072 + q(_pz[i]);
      vid[i] = posId.putIfAbsent(key, () => posId.length);
    }

    // Kenar anahtarı → o kenarı kullanan yarım kenarlar (3f+k). Tam iki tane ve ters yönlüyse komşudur;
    // fazlası (çakışan yüzeyler) veya tekil kenar silüet yumuşatmasına katılmaz.
    final twin = Int32List(nf * 3)..fillRange(0, nf * 3, -1);
    final edges = <int, List<int>>{};
    for (var f = 0; f < nf; f++) {
      for (var k = 0; k < 3; k++) {
        final a = vid[_fi[f * 3 + k]], b = vid[_fi[f * 3 + (k + 1) % 3]];
        if (a == b) continue;
        final key = a < b ? a * 200003 + b : b * 200003 + a;
        (edges[key] ??= <int>[]).add(f * 3 + k);
      }
    }
    for (final list in edges.values) {
      if (list.length != 2) continue;
      final h0 = list[0], h1 = list[1];
      final a0 = vid[_fi[h0]], a1 = vid[_fi[h1]];
      if (a0 == a1) continue; // aynı yönde dolanıyor: komşu değil
      twin[h0] = h1;
      twin[h1] = h0;
    }

    final pos = Float64List(nv * 3), nrm = Float64List(nv * 3), col = Float64List(nv * 4);
    for (var i = 0; i < nv; i++) {
      pos[i * 3] = _px[i];
      pos[i * 3 + 1] = _py[i];
      pos[i * 3 + 2] = _pz[i];
      nrm[i * 3] = _nx[i];
      nrm[i * 3 + 1] = _ny[i];
      nrm[i * 3 + 2] = _nz[i];
      col[i * 4] = _cr[i];
      col[i * 4 + 1] = _cg[i];
      col[i * 4 + 2] = _cb[i];
      col[i * 4 + 3] = _ca[i];
    }
    final anchor = Float64List(nf * 3);
    for (var f = 0; f < nf; f++) {
      anchor[f * 3] = _fax[f];
      anchor[f * 3 + 1] = _fay[f];
      anchor[f * 3 + 2] = _faz[f];
    }
    return CameraMesh(
      vertexCount: nv,
      faceCount: nf,
      pos: pos,
      nrm: nrm,
      col: col,
      ao: Float64List.fromList(_ao),
      mat: Uint8List.fromList(_vm),
      idx: Uint16List.fromList(_fi),
      anchor: anchor,
      layer: Uint8List.fromList(_fl),
      flags: Uint8List.fromList(_ff),
      part: Uint8List.fromList(_fp),
      twin: twin,
    );
  }
}
