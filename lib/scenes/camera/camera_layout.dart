import 'dart:math' as math;
import 'dart:ui';

import '../../camera3d/camera_pose.dart';

/// Döndürme ipucunun (yay + yazı) kutu yüksekliği.
const double kHintHeight = 52;

/// Döndürme ipucunun en geniş hali (geniş ve yatay-kısa düzenlerde ürünün altında).
const double kHintMaxWidth = 360;

/// Dar düzende ürünün inebileceği en küçük yükseklik. Ürün bunun altına düşecekse önce üç not satırı gizlenir,
/// sonra metin bloğu içeride küçülür; böylece ürün hiçbir zaman metne ya da notlara binmez.
const double kMinProductHeight = 120;

/// Notların ana pozdan kaç derece uzaklıkta solmaya başladığı / tamamen kaybolduğu. Boşta salınım (±5°) solmaya
/// yol açmaz; dönerken ürün silueti notların sabit konumlarına ulaştığı için çizgiler gövdeye binmeden önce silinir.
const double kNoteFadeStartDeg = 10;
const double kNoteFadeEndDeg = 30;

/// Yaw'daki (radyan) not görünürlüğü: ana pozda (ve boşta salınımda) 1, yandan/arkadan görünümlerde 0.
/// Ana pozdan en kısa açısal uzaklığa bakar; birden çok tur dönülse de doğru çalışır.
double noteVisibilityForYaw(double yaw) {
  const deg = math.pi / 180;
  final off = (yaw - nearestHomeYaw(yaw)).abs();
  final t = ((off - kNoteFadeStartDeg * deg) / ((kNoteFadeEndDeg - kNoteFadeStartDeg) * deg)).clamp(0.0, 1.0);
  // Yumuşak (smoothstep) sönüm: başta ve sonda ani değişim olmaz.
  return 1 - t * t * (3 - 2 * t);
}

/// Sahnenin üç yerleşim kipi.
enum CameraLayoutMode {
  /// >= 900 px: metin solda, ürün sağda, çizgi-notları ürünün çevresinde.
  wide,

  /// 560-900 px genişlikte ama kısa (< 520 px) görüntü alanı, yani yatay telefon: metin solda, ürün sağda; notlar
  /// gizlenir (kısa alanda ne metne ne ürüne yer bırakır).
  compact,

  /// Telefon / dar tablet (dikey): metin üstte, ürün ortada, notlar ve ipucu altta.
  narrow,
}

/// Çizici ürünü kutuya kenar payı bırakarak sığdırır: ürünün en uzun (tam yandan, kablo dahil) görünümü kutu
/// genişliğinin yaklaşık bu kadarını kaplar (ana pozdaki 3/4 görünüm ise ~%64'ünü). Kutu, ürünün hiçbir açıda
/// metne ya da ekran kenarına taşmaması için görünür alandan bu oranda büyük seçilir.
const double kProductVisibleWidth = 0.97;

/// Bir çizgi-notunun geometrisi: ürüne yakın bir nokta, oradan dışarı çıkan ince çizgi ve etiket.
/// Çizgi `dot → elbow → end` kırık çizgisidir; etiket `end` noktasının sağına ya da soluna oturur.
class NoteGeometry {
  const NoteGeometry({required this.dot, required this.elbow, required this.end, required this.label, required this.labelRight});

  final Offset dot;
  final Offset elbow;
  final Offset end;

  /// Etiketin kapladığı kutu (çizginin ucunda, dikeyde ortalı).
  final Rect label;

  /// true: etiket çizginin sağ ucundan sağa doğru uzanır; false: sol ucundan sola doğru.
  final bool labelRight;
}

/// Bir notun, ürün kutusuna göre tarifi (kesirler ürün kutusunun genişlik/yüksekliğidir).
class _NoteSpec {
  const _NoteSpec(this.fx, this.fy, this.dx, this.dy, this.len, this.side);

  /// Ürüne yakın noktanın ürün kutusundaki yeri.
  final double fx, fy;

  /// Noktadan dirseğe yatay (yöne göre işaretlenir) ve dikey uzaklık.
  final double dx, dy;

  /// Dirsekten sonraki yatay çizgi uzunluğu.
  final double len;

  /// +1: çizgi ve etiket sağa gider; -1: sola.
  final int side;
}

/// Kamera sahnesinin yerleşimi. Saf hesap: widget ağacına bağlı değildir, birim testi kolaydır.
///
/// Sahne, hero bloğundan sıkı (viewport boyutunda) kısıt alır. Üst çubuk 64 px olduğundan içerik üstte
/// [topInset] kadar boşluk bırakır. Yükseklik azaldıkça ürün ve boşluklar kontrollü küçülür.
class CameraSceneLayout {
  const CameraSceneLayout({
    required this.size,
    required this.mode,
    required this.text,
    required this.product,
    required this.hint,
    required this.notes,
    required this.noteGeometry,
    required this.glowCenter,
    required this.glowRadius,
  });

  /// Üst çubuğun (64 px) altında bırakılan boşluk.
  static const double topInset = 72;

  final Size size;
  final CameraLayoutMode mode;

  bool get wide => mode == CameraLayoutMode.wide;

  /// Etiket + başlık + gövde bloğu.
  final Rect text;

  /// Ürün kutusu (çizici ürünü bu kutuya, kenarlardan pay bırakarak sığdırır). Sürükleme alanı da budur.
  final Rect product;

  /// Döndürme ipucunun kutusu (ürünün altında).
  final Rect hint;

  /// Dar düzende üç notun alt alta durduğu kutu (geniş ve yatay-kısa düzende, ya da dar düzende ürüne yer
  /// kalmayacaksa boş: o zaman notlar gösterilmez).
  final Rect notes;

  /// Geniş düzende üç çizgi-notu (mobilde boş).
  final List<NoteGeometry> noteGeometry;

  /// Zeminin yumuşak parıltısının merkezi ve yarıçapı.
  final Offset glowCenter;
  final double glowRadius;

  /// Görüntü alanına uygun yerleşim kipi. Yalnızca genişliğe bakmak yatay telefonda (864x304 gibi) dikey düzeni
  /// seçip metin, notlar ve ürünü üst üste bindiriyordu; bu yüzden kısa yükseklik de hesaba katılır.
  static CameraLayoutMode modeFor(Size size) {
    if (size.width >= 900) return CameraLayoutMode.wide;
    if (size.width >= 560 && size.height < 520) return CameraLayoutMode.compact;
    return CameraLayoutMode.narrow;
  }

  /// Metin bloğunun genişliği. Ölçüm (widget) ve yerleşim aynı değeri kullanmalı; yoksa ölçülen yükseklik
  /// gerçek yazı yüksekliğinden farklı çıkar.
  static double textWidthFor(CameraLayoutMode mode, Size size, double sidePad) {
    switch (mode) {
      case CameraLayoutMode.wide:
        return (size.width * 0.27).clamp(300.0, 400.0);
      case CameraLayoutMode.compact:
        return (size.width * 0.46).clamp(300.0, 440.0);
      case CameraLayoutMode.narrow:
        return size.width - sidePad * 2;
    }
  }

  /// [textHeight]: metin bloğunun doğal yüksekliği ([textWidthFor] genişliğinde ölçülmüş).
  /// [aspect]: ürün kutusunun en/boy oranı.
  factory CameraSceneLayout.compute({
    required Size size,
    required CameraLayoutMode mode,
    required double textHeight,
    required double sidePad,
    required double aspect,
    List<double> noteLabelWidths = const [120, 100, 100],
  }) {
    switch (mode) {
      case CameraLayoutMode.wide:
        return _wide(size, textHeight, sidePad, aspect, noteLabelWidths);
      case CameraLayoutMode.compact:
        return _compact(size, textHeight, sidePad, aspect);
      case CameraLayoutMode.narrow:
        return _narrow(size, textHeight, sidePad, aspect);
    }
  }

  // ---- Masaüstü / geniş tablet -------------------------------------------------------------------------------

  static CameraSceneLayout _wide(Size size, double textHeight, double sidePad, double aspect, List<double> labelWidths) {
    final w = size.width;
    final h = size.height;
    // Diğer sahnelerle aynı hizada: en çok 1200 px içerik, yanlarda [sidePad].
    final contentL = math.max(sidePad, (w - 1200) / 2);
    final contentR = w - contentL;
    final textW = textWidthFor(CameraLayoutMode.wide, size, sidePad);
    final bottomPad = (h * 0.06).clamp(20.0, 56.0);
    final availTop = CameraSceneLayout.topInset;
    final availH = math.max(0.0, h - availTop - bottomPad);

    // Metin: sol-ortada; çok uzunsa (büyük yazı boyutu) kutu yüksekliği ile sınırlanır, içeride küçülür.
    final th = math.min(textHeight, availH);
    final textRect = Rect.fromLTWH(contentL, availTop + (availH - th) / 2, textW, th);

    // Ürün: metnin sağındaki alanda, orta-sağda. Yükseklik sahnenin ~%55'i; ürünün en uzun görünümü alana sığar.
    final areaL = contentL + textW + 16;
    final areaR = math.min(w - 16.0, contentR + 40);
    final areaW = math.max(240.0, areaR - areaL);
    // Ürünün altındaki ipucu da sahneye sığmalı (ürün dikeyde ortalı: ipucu altına kenar payından fazlası taşmamalı).
    final ph = math.min(math.min(h * 0.58, availH * 0.8), math.min(math.max(0.0, availH - 2 * (kHintHeight - 6)), areaW / kProductVisibleWidth / aspect));
    final pw = ph * aspect;
    final cx = areaL + areaW / 2;
    final cy = availTop + availH * 0.5;
    final product = Rect.fromCenter(center: Offset(cx, cy), width: pw, height: ph);

    final hintRect = Rect.fromCenter(center: Offset(cx + pw * 0.03, product.bottom + kHintHeight / 2 - 6), width: math.min(pw, kHintMaxWidth), height: kHintHeight);

    // Çizgi-notları: ürünün kutusunun çevresinde, genel konumlara işaret eder (belirli bir parçaya değil).
    // Etiket sahneye sığmıyorsa çizgi ters yöne çevrilir; böylece büyük yazı boyutunda bile taşmaz.
    Offset at(double fx, double fy) => Offset(product.left + product.width * fx, product.top + product.height * fy);
    NoteGeometry note(_NoteSpec n, double labelW) {
      // Etiket kutusu, büyütülmüş yazıda da (ölçek en çok 1.3) kırpılmasın diye 28 px yüksektir.
      const gap = 8.0, lh = 28.0, margin = 16.0;
      // Etiket sahneye sığsın diye nokta, ürün kutusu içinde gerekirse içeri çekilir (ters yöne çevirmeden önce).
      final fx = n.side > 0
          ? math.min(n.fx, (w - margin - labelW - gap - n.len - n.dx - product.left) / product.width)
          : math.max(n.fx, (margin + labelW + gap + n.len + n.dx - product.left) / product.width);
      NoteGeometry build(int side) {
        final dot = at(side == n.side ? fx : n.fx, n.fy);
        final elbow = dot + Offset(side * n.dx, n.dy);
        final end = elbow + Offset(side * n.len, 0);
        final label = side > 0
            ? Rect.fromLTWH(end.dx + gap, end.dy - lh / 2, labelW, lh)
            : Rect.fromLTWH(end.dx - gap - labelW, end.dy - lh / 2, labelW, lh);
        return NoteGeometry(dot: dot, elbow: elbow, end: end, label: label, labelRight: side > 0);
      }

      // Etiket sahne içinde kalmalı, metin bloğuna ve ipucuna binmemeli.
      final avoid = [textRect.inflate(16), hintRect.inflate(8)];
      bool fits(NoteGeometry g) =>
          g.label.left >= margin && g.label.right <= w - margin && !avoid.any((r) => r.overlaps(g.label));
      final first = build(n.side);
      if (fits(first)) return first;
      final flipped = build(-n.side);
      return fits(flipped) ? flipped : first;
    }

    // Kesirler, ürünün ana pozdaki siluetine göre seçildi: (1) gövdenin üstünde, (2) arka ucun sağ-altında,
    // (3) ayağın sol-altında boşluk var. Noktalar ürüne dokunmaz; döndürürken sabit kalan genel işaretlerdir.
    const specs = [
      _NoteSpec(0.60, 0.00, 24, -22, 70, 1),
      _NoteSpec(0.80, 0.52, 24, 24, 52, 1),
      _NoteSpec(0.33, 0.62, 24, 24, 56, -1),
    ];
    final notes = [for (var i = 0; i < specs.length; i++) note(specs[i], i < labelWidths.length ? labelWidths[i] : 100)];

    return CameraSceneLayout(
      size: size,
      mode: CameraLayoutMode.wide,
      text: textRect,
      product: product,
      hint: hintRect,
      notes: Rect.zero,
      noteGeometry: notes,
      glowCenter: at(0.45, 0.45),
      glowRadius: math.max(w * 0.42, h * 0.78),
    );
  }

  // ---- Yatay telefon / kısa görüntü alanı --------------------------------------------------------------------

  static CameraSceneLayout _compact(Size size, double textHeight, double sidePad, double aspect) {
    final w = size.width;
    final h = size.height;
    final top = CameraSceneLayout.topInset + (h * 0.02).clamp(6.0, 18.0);
    final bottomPad = (h * 0.03).clamp(14.0, 28.0);
    final availH = math.max(0.0, h - top - bottomPad);

    // Metin solda, dikeyde ortalı; çok uzunsa (büyük yazı boyutu) kutuya sığacak kadar içeride küçülür.
    final textW = textWidthFor(CameraLayoutMode.compact, size, sidePad);
    final th = math.min(textHeight, availH);
    final textRect = Rect.fromLTWH(sidePad, top + (availH - th) / 2, textW, th);

    // Ürün + altındaki ipucu sağdaki alanda tek bir grup olarak dikeyde ortalanır. Ürünün en uzun (yandan)
    // görünümü alana sığar; böylece hiçbir açıda metne binmez. Notlar bu kipte gösterilmez.
    final areaL = textRect.right + 16;
    final areaW = math.max(0.0, w - sidePad - areaL);
    final ph = math.max(0.0, math.min(availH - kHintHeight, areaW / kProductVisibleWidth / aspect));
    final pw = ph * aspect;
    final cx = areaL + areaW / 2;
    final groupTop = top + (availH - (ph + kHintHeight)) / 2;
    final product = Rect.fromLTWH(cx - pw / 2, groupTop, pw, ph);
    final hintRect = Rect.fromCenter(center: Offset(cx, product.bottom + kHintHeight / 2), width: math.min(areaW, kHintMaxWidth), height: kHintHeight);

    return CameraSceneLayout(
      size: size,
      mode: CameraLayoutMode.compact,
      text: textRect,
      product: product,
      hint: hintRect,
      notes: Rect.zero,
      noteGeometry: const [],
      glowCenter: Offset(product.left + product.width * 0.45, product.top + product.height * 0.45),
      glowRadius: math.max(w * 0.42, h * 0.78),
    );
  }

  // ---- Telefon / dar tablet ----------------------------------------------------------------------------------

  static CameraSceneLayout _narrow(Size size, double textHeight, double sidePad, double aspect) {
    final w = size.width;
    final h = size.height;
    final topPad = CameraSceneLayout.topInset + (h * 0.02).clamp(6.0, 18.0);
    final bottomPad = (h * 0.03).clamp(14.0, 28.0);
    final contentW = w - sidePad * 2;

    // Alt bölge: ipucu en altta, üstünde üç satır not.
    const hintH = kHintHeight;
    const notesH = 3 * 30.0;
    const notesGap = 14.0;
    final hintRect = Rect.fromLTWH(sidePad, h - bottomPad - hintH, contentW, hintH);

    // Metin üstte; ekranın en çok %46'sını kaplar (fazlası içeride kontrollü küçülür).
    var th = math.min(textHeight, h * 0.46);

    // Ürüne [kMinProductHeight] kalmıyorsa önce notlar gizlenir; yine de kalmıyorsa metin küçülür. Eskiden ürün
    // yüksekliği 120'ye zorlanıyor, kısa ekranlarda metne ve notlara biniyordu.
    final topOf = topPad + th + 8;
    final showNotes = hintRect.top - notesGap - notesH - 8 - topOf >= kMinProductHeight;
    final notesRect = showNotes ? Rect.fromLTWH(sidePad, hintRect.top - notesGap - notesH, contentW, notesH) : Rect.zero;
    final bottom = (showNotes ? notesRect.top : hintRect.top) - 8;
    th = math.min(th, math.max(0.0, bottom - kMinProductHeight - 8 - topPad));
    final textRect = Rect.fromLTWH(sidePad, topPad, contentW, th);

    // Ürün: metin ile notlar arasındaki boşlukta ortalanır; kenarlara yakın, geniş.
    final top = textRect.bottom + 8;
    final freeH = math.max(0.0, bottom - top);
    // Kutu ekran genişliğinden biraz büyüktür (ana pozdaki ürün büyük görünür); ürünün en uzun, yandan görünümü
    // ise kenarlarda 12 px pay bırakarak ekrana sığar.
    var pw = math.min((w - 24) / kProductVisibleWidth, 620.0);
    var ph = pw / aspect;
    if (ph > freeH) {
      ph = freeH;
      pw = ph * aspect;
    }
    final cy = (top + freeH * 0.55).clamp(top + ph / 2, math.max(top + ph / 2, bottom - ph / 2)).toDouble();
    final product = Rect.fromCenter(center: Offset(w / 2, cy), width: pw, height: ph);

    return CameraSceneLayout(
      size: size,
      mode: CameraLayoutMode.narrow,
      text: textRect,
      product: product,
      hint: hintRect,
      notes: notesRect,
      noteGeometry: const [],
      glowCenter: Offset(product.left + product.width * 0.45, product.top + product.height * 0.45),
      glowRadius: math.max(w * 0.9, h * 0.5),
    );
  }
}
