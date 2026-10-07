import 'dart:math' as math;

/// Bir yüzey malzemesinin aydınlatma parametreleri. Renk köşeden gelir; burada yalnızca "nasıl ışık alır" vardır.
class Mat {
  const Mat({
    this.kd = 1,
    this.ka = 1,
    this.r0 = 0.04,
    this.fr = 0.6,
    this.tint = 0,
    this.rim = 0.5,
    this.gloss = 0.3,
    this.emissive = 0,
    this.unlit = false,
    this.sheen = 0,
    this.irid = 0,
  });

  /// Yaygın (diffuse) ve ortam ışığı katsayıları.
  final double kd, ka;

  /// Dik bakışta yansıma ve kenarda (Fresnel) ek yansıma. Ortam yansıması [r0] + [fr]·F ile ölçeklenir.
  final double r0, fr;

  /// Yansımanın malzeme rengiyle boyanma oranı (metal 1'e yakın, plastik 0).
  final double tint;

  /// Sağ-arkadan gelen soğuk kenar ışığının ağırlığı.
  final double rim;

  /// 0 = mat/saten (geniş, yumuşak vurgu), 1 = parlak (dar, keskin vurgu).
  final double gloss;

  /// Işıktan bağımsız ek parlaklık (temel rengin katı). LED'ler için.
  final double emissive;

  /// Aydınlatmasız: temel renk (ve alfa) aynen çıkar (parıltı çıkartmaları).
  final bool unlit;

  /// Cam yüzeyde ışık yönünde yumuşak degrade yansıma (düz camın ölü görünmemesi için).
  final double sheen;

  /// Lens kaplamasının açıya bağlı mavi-mor yansıması.
  final double irid;
}

/// Malzeme numaraları (köşe başına bir bayt).
class Mats {
  Mats._();

  static const graphite = 0;
  static const satin = 1;
  static const metal = 2;
  static const edge = 3;
  static const glass = 4;
  static const lens = 5;
  static const rubber = 6;
  static const led = 7;
  static const status = 8;
  static const glow = 9;
  static const bracket = 10;
  static const ball = 11;

  static const table = <Mat>[
    // graphite: mat gövde
    Mat(kd: 1.0, ka: 1.0, r0: 0.14, fr: 0.9, tint: 0, rim: 0.8, gloss: 0.35),
    // satin: güneşlik (satenize boya)
    Mat(kd: 1.0, ka: 1.0, r0: 0.17, fr: 1.0, tint: 0.1, rim: 1.0, gloss: 0.50),
    // metal: fırçalanmış koyu metal çerçeve
    Mat(kd: 0.55, ka: 0.7, r0: 0.30, fr: 0.9, tint: 0.75, rim: 0.6, gloss: 0.65),
    // edge: işlenmiş parlak pah
    Mat(kd: 0.7, ka: 0.8, r0: 0.42, fr: 0.9, tint: 0.6, rim: 0.5, gloss: 0.90),
    // glass: koyu cam
    Mat(kd: 0.03, ka: 0.2, r0: 0.05, fr: 1.4, tint: 0, rim: 0.2, gloss: 1.0, sheen: 1),
    // lens: kaplamalı ön cam
    Mat(kd: 0.10, ka: 0.5, r0: 0.28, fr: 1.4, tint: 0, rim: 0.2, gloss: 1.0, irid: 1),
    // rubber: kablo rakoru
    Mat(kd: 1.0, ka: 1.0, r0: 0.03, fr: 0.3, tint: 0, rim: 0.3, gloss: 0.15),
    // led: IR LED (koyu kırmızımsı, hafif kendi ışığı)
    Mat(kd: 0.6, ka: 0.8, r0: 0.20, fr: 0.7, tint: 0.2, rim: 0.2, gloss: 0.9, emissive: 0.3),
    // status: durum LED'i
    Mat(unlit: true),
    // glow: şeffaf parıltı çıkartması
    Mat(unlit: true),
    // bracket: koyu metal braket
    Mat(kd: 1.0, ka: 1.0, r0: 0.12, fr: 0.8, tint: 0.5, rim: 0.6, gloss: 0.5),
    // ball: parlatılmış mafsal küresi
    Mat(kd: 0.8, ka: 0.9, r0: 0.30, fr: 0.9, tint: 0.7, rim: 0.55, gloss: 0.85),
  ];
}

/// Sahne ışıkları (görünüm uzayında, izleyiciye göre sabit; ürün dönerken yansımalar yüzeyde kayar).
///
/// * Ana ışık: sol-üst-önden büyük, sıcak beyaz yumuşak kutu.
/// * Şerit ışık: üstten, ince; silindirlerde uzunlamasına parlak bir çizgi bırakır.
/// * Kenar ışığı: sağ-arkadan, çok hafif soğuk.
/// * Ortam: üstü az açık, altı çok koyu yarım-küre.
///
/// Yansıma, bu ışıkların küçük bir "ortam haritası" olarak yansıma vektörüne göre toplanmasıyla bulunur;
/// pow() çağrısı yoktur (2'nin kuvvetleri art arda çarpılır).
class LightRig {
  // Ana ışık yönü (nesneden ışığa)
  double kdx = -0.55, kdy = 0.62, kdz = 0.56;

  // Ana ışığın yatay ve dikey teğet eksenleri (yansıma penceresi için)
  double kux = 0.71, kuy = 0, kuz = 0.70, kwx = -0.43, kwy = 0.78, kwz = 0.45;

  // Şerit ışık yönü
  double sx = -0.15, sy = 0.95, sz = -0.25;

  // Kenar ışığı yönü
  double rx = 0.80, ry = 0.30, rz = -0.52;

  // Lens parlaması için iki sanal ışık yönü: sol-üst ve sağ-üst (yalnızca parlama/cam degradesi için)
  double gx = -0.82, gy = 0.46, gz = 0.20;
  double hx = 0.78, hy = 0.44, hz = 0.28;

  /// Soğuk kenar ışığının çarpanı (1 = koyu zemin için tasarlanan şiddet; açık zeminde azaltılır).
  double rimGain = 1.0;

  /// Işık yönlerini [phase] (0..2π) ile çok yavaş kaydırır.
  void update(double phase) {
    final s = math.sin(phase), c = math.cos(phase);
    // ana ışık: yatayda ±0.3 rad, yükseklikte hafif
    final az = 0.30 * s;
    final ca = math.cos(az), sa = math.sin(az);
    const bx = -0.55, bz = 0.56;
    var x = bx * ca + bz * sa;
    var z = -bx * sa + bz * ca;
    var y = 0.62 + 0.07 * math.sin(phase * 0.5 + 1.0);
    var l = 1 / math.sqrt(x * x + y * y + z * z);
    kdx = x * l;
    kdy = y * l;
    kdz = z * l;
    // yatay teğet: Y × K (normalize), dikey teğet: K × U
    var ux = kdz, uz = -kdx;
    final ul = 1 / math.sqrt(ux * ux + uz * uz);
    ux *= ul;
    uz *= ul;
    kux = ux;
    kuy = 0;
    kuz = uz;
    kwx = kdy * uz;
    kwy = kdz * ux - kdx * uz;
    kwz = -kdy * ux;

    x = -0.15 + 0.22 * math.sin(phase + 1.3);
    z = -0.25 + 0.12 * c;
    l = 1 / math.sqrt(x * x + 0.95 * 0.95 + z * z);
    sx = x * l;
    sy = 0.95 * l;
    sz = z * l;

    x = 0.80 - 0.10 * s;
    z = -0.52 + 0.08 * c;
    l = 1 / math.sqrt(x * x + 0.30 * 0.30 + z * z);
    rx = x * l;
    ry = 0.30 * l;
    rz = z * l;

    x = -0.82 + 0.10 * s;
    z = 0.20 + 0.06 * c;
    l = 1 / math.sqrt(x * x + 0.46 * 0.46 + z * z);
    gx = x * l;
    gy = 0.46 * l;
    gz = z * l;

    x = 0.78 - 0.10 * s;
    z = 0.28 + 0.06 * c;
    l = 1 / math.sqrt(x * x + 0.44 * 0.44 + z * z);
    hx = x * l;
    hy = 0.44 * l;
    hz = z * l;
  }

  // --- Çıktı (shade çağrısının sonucu) ---
  double outR = 0, outG = 0, outB = 0;

  // Cam degradesi için: kamera ekseni ve camın merkezi (görünüm uzayı); her karede ayarlanır.
  double axX = 0, axY = 0, axZ = 1;
  double glassX = 0, glassY = 0, glassZ = 0;

  /// Bir köşeyi aydınlatır. [px,py,pz]: görünüm konumu; [nx,ny,nz]: görünüm normali (birim);
  /// [vx,vy,vz]: köşeden göze birim vektör; [ar,ag,ab]: doğrusal temel renk; [ao]: önceden pişirilmiş ortam
  /// kapanması (0..1); [m]: malzeme. Sonuç doğrusal renk olarak outR/outG/outB'ye yazılır (henüz gamma yok).
  void shade(
    double px,
    double py,
    double pz,
    double nx,
    double ny,
    double nz,
    double vx,
    double vy,
    double vz,
    double ar,
    double ag,
    double ab,
    double ao,
    Mat m,
  ) {
    if (m.unlit) {
      outR = ar;
      outG = ag;
      outB = ab;
      return;
    }

    final nvRaw = nx * vx + ny * vy + nz * vz;
    final ndv = nvRaw < 0 ? 0.0 : nvRaw;

    // --- Yaygın aydınlatma ---
    var ndl = (nx * kdx + ny * kdy + nz * kdz + 0.20) / 1.20; // hafif sarma: gölge sınırı sert değil
    if (ndl < 0) ndl = 0;
    var ndt = nx * sx + ny * sy + nz * sz;
    if (ndt < 0) ndt = 0;
    // sağ-ön dolgu (çok zayıf): gölgedeki yüzün tamamen ölü görünmesini önler
    var ndf = 0.55 * nx + 0.05 * ny + 0.83 * nz;
    if (ndf < 0) ndf = 0;
    var ndr = nx * rx + ny * ry + nz * rz;
    if (ndr < 0) ndr = 0;

    final hemi = ny * 0.5 + 0.5;
    final amb = (0.010 + 0.060 * hemi) * m.ka;
    final key = ndl * 1.9 * m.kd;
    final top = ndt * 0.30 * m.kd;
    final fill = ndf * 0.075 * m.kd;
    final dr = key * 1.00 + top * 0.95 + fill * 0.80 + amb * 0.92;
    final dg = key * 0.96 + top * 0.98 + fill * 0.88 + amb * 0.98;
    final db = key * 0.90 + top * 1.00 + fill * 1.00 + amb * 1.06;
    var r = ar * dr * ao;
    var g = ag * dg * ao;
    var b = ab * db * ao;

    // --- Yansıma (küçük bir ortam haritası) ---
    final qx = 2 * nvRaw * nx - vx, qy = 2 * nvRaw * ny - vy, qz = 2 * nvRaw * nz - vz;
    // Taban: üstü açık, altı yer sekmesiyle hafif aydınlık bir stüdyo (alt kenarlar zeminde kaybolmasın).
    final h = qy * 0.5 + 0.5;
    final fl = qy < 0 ? -qy : 0.0;
    var eR = 0.012 + 0.050 * h * h + 0.34 * fl * fl, eG = 0.014 + 0.056 * h * h + 0.35 * fl * fl, eB = 0.018 + 0.066 * h * h + 0.37 * fl * fl;

    final gl = m.gloss;
    // ana yumuşak kutu: yansıma vektörünün ışık düzlemindeki konumuna göre yumuşak kenarlı dikdörtgen pencere
    var d = qx * kdx + qy * kdy + qz * kdz;
    if (d > 0.15) {
      final aa = qx * kux + qy * kuy + qz * kuz;
      final bb = qx * kwx + qy * kwy + qz * kwz;
      final edge = 0.26 + (1 - gl) * 0.30;
      final win = _soft(aa, 0.50, edge) * _soft(bb, 0.30, edge);
      final d2 = d * d, d4 = d2 * d2, d8 = d4 * d4, d16 = d8 * d8, d32 = d16 * d16;
      final k = win * 1.0 + gl * (0.45 * d16 + 2.4 * d32) + (1 - gl) * 0.30 * d4;
      eR += k * 1.00;
      eG += k * 0.97;
      eB += k * 0.92;
    }
    // üst şerit ışık
    d = qx * sx + qy * sy + qz * sz;
    if (d > 0) {
      final d2 = d * d, d4 = d2 * d2, d8 = d4 * d4, d16 = d8 * d8;
      final k = (1 - gl) * 0.5 * d4 + gl * 0.9 * d16 + 0.35 * d8;
      eR += k * 0.95;
      eG += k * 0.98;
      eB += k * 1.00;
    }
    // sağ-arka soğuk kenar ışığı (yansımada)
    d = qx * rx + qy * ry + qz * rz;
    if (d > 0) {
      final d2 = d * d, d4 = d2 * d2, d8 = d4 * d4;
      final k = 0.55 * d8 * rimGain;
      eR += k * 0.55;
      eG += k * 0.75;
      eB += k * 0.95;
    }

    // Fresnel (Schlick)
    final tt = 1 - ndv;
    final t2 = tt * tt;
    final f5 = t2 * t2 * tt;
    final refl = (m.r0 + m.fr * (1 - m.r0) * f5) * ao;

    // yansımanın malzeme rengiyle boyanması (metal)
    final ti = m.tint;
    final tr = 1 - ti + ti * math.min(1.0, ar * 3.0);
    final tg = 1 - ti + ti * math.min(1.0, ag * 3.0);
    final tb = 1 - ti + ti * math.min(1.0, ab * 3.0);
    r += eR * refl * tr;
    g += eG * refl * tg;
    b += eB * refl * tb;

    // Kenar (rim) ışığı: yalnızca ışığa dönük silüet kenarında ince, soğuk ve nötr bir çizgi
    if (m.rim > 0 && ndr > 0) {
      final rr = tt * tt * (0.2 + 0.8 * ndr) * ndr * 0.85 * m.rim * rimGain;
      r += rr * 0.52;
      g += rr * 0.62;
      b += rr * 0.74;
    }

    // Cam degradesi: ışığın cam düzlemine izdüşümü yönünde yumuşak parlaklık
    if (m.sheen > 0) {
      final dxp = px - glassX, dyp = py - glassY, dzp = pz - glassZ;
      final ld = gx * axX + gy * axY + gz * axZ;
      var tx = gx - ld * axX, ty = gy - ld * axY, tz = gz - ld * axZ;
      final tl = math.sqrt(tx * tx + ty * ty + tz * tz);
      if (tl > 1e-4) {
        tx /= tl;
        ty /= tl;
        tz /= tl;
        final s = (dxp * tx + dyp * ty + dzp * tz) / 0.42; // -1..1
        var w = (s + 0.55) / 1.4;
        w = w < 0 ? 0 : (w > 1 ? 1 : w);
        w = w * w * (3 - 2 * w);
        final amt = m.sheen * w * (0.030 + 0.110 * tt);
        r += amt * 0.78;
        g += amt * 0.86;
        b += amt * 1.00;
      }
    }

    // Lens kaplaması: eğik bakışta mavi-mor, dik bakışta koyu
    if (m.irid > 0) {
      final w = m.irid * (0.18 + 0.82 * tt * tt);
      r += w * 0.070;
      g += w * 0.030;
      b += w * 0.150;
    }

    if (m.emissive > 0) {
      r += ar * m.emissive;
      g += ag * m.emissive;
      b += ab * m.emissive;
    }

    outR = r;
    outG = g;
    outB = b;
  }
}

/// Yumuşak kenarlı pencere: |x| < half içinde 1, half+2·edge dışında 0 (smoothstep).
double _soft(double x, double half, double edge) {
  final t = (half + edge - (x < 0 ? -x : x)) / (2 * edge);
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  return t * t * (3 - 2 * t);
}

/// Doğrusal renk bileşenini 0..255 ekran değerine çevirir: hafif omuz (parlak vurguları yumuşatır) + gamma ≈ 2.
int toByte(double c) {
  if (!(c > 0)) return 0; // negatif ve NaN → 0
  final x = c / (1 + 0.18 * c);
  final v = (math.sqrt(x) * 255 + 0.5).toInt();
  return v > 255 ? 255 : v;
}
