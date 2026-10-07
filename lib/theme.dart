import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================================
// TEMA — TEK NOKTA
// ----------------------------------------------------------------------------
// Açık ve koyu temanın bütün renkleri bu dosyadadır. Bir rengi değiştirmek için
// yalnızca aşağıdaki [AppColors.dark] / [AppColors.light] değerlerini düzenleyin.
// Varsayılan tema modunu [kDefaultThemeMode] belirler. Ayrıntı: docs/THEMING.md
// ============================================================================

/// Ziyaretçi daha önce tema seçmediyse açılışta kullanılan mod. Tek noktadan değiştirilir.
const kDefaultThemeMode = ThemeMode.dark;

/// Tema anahtarı (güneş/ay düğmesi ve yan paneldeki tema seçici) görünsün mü?
/// Tüm sahneler iki temaya uyarlandığı için açıktır; geçici olarak gizlemek için false yapın.
const kThemeSwitchVisible = true;

/// Koyu temanın ham renkleri; [AppColors.dark] bunlardan beslenir.
class _Dark {
  static const bg = Color(0xFF06080B);
  static const bgAlt = Color(0xFF0B0E13);
  static const surface = Color(0xFF11151B);
  static const surfaceHi = Color(0xFF181D25);
  static const line = Color(0x1AFFFFFF); // %10 beyaz
  static const lineStrong = Color(0x33FFFFFF); // %20 beyaz
  static const text = Color(0xFFF3F5F8);
  static const textDim = Color(0xFFA3ACB9);
  static const textFaint = Color(0xFF6B7482);
  static const accent = Color(0xFF58D6CB);
  static const ok = Color(0xFF34D399);
}

/// Açık temanın ham renkleri.
class _Light {
  static const bg = Color(0xFFF4F5F7);
  static const bgAlt = Color(0xFFEBEDF0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHi = Color(0xFFF0F2F5);
  static const line = Color(0x1A0B1016); // %10 koyu
  static const lineStrong = Color(0x2E0B1016); // %18 koyu
  static const text = Color(0xFF0B0F14);
  static const textDim = Color(0xFF4A5463);
  static const textFaint = Color(0xFF7A8494);
  static const accent = Color(0xFF0E9F94);
  static const accentText = Color(0xFF0B766D); // beyaz üzerinde küçük yazı için (≥4.5:1)
  static const ok = Color(0xFF047857);
}

/// Logonun tema renkleri. Yapı (yapraklar, harf biçimleri) `lib/brand/gude_logo_data.dart` içindeki vektör verisidir;
/// tema yalnızca yazının gradyanını, kenar rengini, sloganı ve gölgeyi belirler. Zemin şeffaftır (plaka yoktur).
@immutable
class LogoPalette {
  const LogoPalette({
    required this.wordStart,
    required this.wordMid,
    required this.wordEnd,
    required this.wordOutline,
    required this.tagline,
    required this.taglineEdge,
    required this.shadow,
  });

  /// "Güde Teknoloji" harf yüzlerinin soldan sağa gradyanı.
  final Color wordStart;
  final Color wordMid;
  final Color wordEnd;

  /// Harflerin koyu kenarı.
  final Color wordOutline;

  /// Slogan ("gelecek sizin elinizde"): dolgu ve kenar. Koyu zeminde kenar koyu olamaz (kaybolur, ince harfler cılız kalır);
  /// bu yüzden koyu temada kenar loş altın, açıkta koyu kahverengidir.
  final Color tagline;
  final Color taglineEdge;

  /// Yaprakların ve yazının altındaki yumuşak gölge (alfa içinde); koyu zeminde görünmez.
  final Color shadow;

  static LogoPalette lerp(LogoPalette a, LogoPalette b, double t) {
    Color mix(Color x, Color y) => Color.lerp(x, y, t)!;
    return LogoPalette(
      wordStart: mix(a.wordStart, b.wordStart),
      wordMid: mix(a.wordMid, b.wordMid),
      wordEnd: mix(a.wordEnd, b.wordEnd),
      wordOutline: mix(a.wordOutline, b.wordOutline),
      tagline: mix(a.tagline, b.tagline),
      taglineEdge: mix(a.taglineEdge, b.taglineEdge),
      shadow: mix(a.shadow, b.shadow),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogoPalette &&
          wordStart == other.wordStart &&
          wordMid == other.wordMid &&
          wordEnd == other.wordEnd &&
          wordOutline == other.wordOutline &&
          tagline == other.tagline &&
          taglineEdge == other.taglineEdge &&
          shadow == other.shadow;

  @override
  int get hashCode => Object.hash(wordStart, wordMid, wordEnd, wordOutline, tagline, taglineEdge, shadow);
}

/// Anlamsal renk jetonları. Widget'lar renkleri `context.colors` ile okur; böylece tema değişince
/// (animasyonlu) kendiliğinden güncellenir. Ürünün kendi malzeme renkleri (kamera gövdesi, lens, LED)
/// fiziksel olduğundan temadan bağımsızdır ve sahne dosyalarında sabit kalır; temaya bağlı olan yalnızca
/// ortam renkleridir (zemin, yazı, çizgi, ışık/gölge).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceHi,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentText,
    required this.ok,
    required this.stage,
    required this.stageGlow,
    required this.shadow,
    required this.scrim,
    required this.logo,
  });

  final Brightness brightness;

  /// Ana zemin ve ardışık bölümleri ayıran hafif farklı zemin.
  final Color bg;
  final Color bgAlt;

  /// Kart / panel yüzeyleri.
  final Color surface;
  final Color surfaceHi;

  /// 1 px çizgiler (normal ve belirgin).
  final Color line;
  final Color lineStrong;

  /// Yazı: ana, ikincil, soluk.
  final Color text;
  final Color textDim;
  final Color textFaint;

  /// Vurgu (LED/ince çizgi/aktif durum) ve küçük yazıda kullanılabilecek kontrastlı sürümü.
  final Color accent;
  final Color accentText;

  /// Başarı ("açıldı") durumu.
  final Color ok;

  /// Ürün sahnesinin arka planı ve merkezindeki yumuşak ışık (koyuda %5 beyaz parıltı, açıkta stüdyo vurgusu).
  final Color stage;
  final Color stageGlow;

  /// Geniş yumuşak gölge rengi (alfa içinde) ve panel arkasındaki karartma.
  final Color shadow;
  final Color scrim;

  /// Logo renkleri (şeffaf zeminde çizilir; koyu temada koyu, açık temada açık zemine oturur).
  final LogoPalette logo;

  bool get isDark => brightness == Brightness.dark;

  /// Dolgulu düğme: yazı rengi zemin, zemin rengi yazı olur (her iki temada yüksek kontrast).
  Color get filledBg => text;
  Color get filledFg => bg;

  /// %2'den az alanda kullanılan vurgu rengi.
  Color get accentSoft => accent.withValues(alpha: 0.2);

  /// Ortam aydınlığı: 0 = koyu tema, 1 = açık tema; tema geçişi sırasında sürekli değişir
  /// (ikili [isDark] geçişin ortasında sıçrar). Sahne zemininin parlaklığından türetilir.
  double get ambient {
    final lo = _Dark.bg.computeLuminance();
    final hi = _lightStageLuminance;
    return ((stage.computeLuminance() - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  static final double _lightStageLuminance = const Color(0xFFE9ECF1).computeLuminance();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppColors &&
          brightness == other.brightness &&
          bg == other.bg &&
          bgAlt == other.bgAlt &&
          surface == other.surface &&
          surfaceHi == other.surfaceHi &&
          line == other.line &&
          lineStrong == other.lineStrong &&
          text == other.text &&
          textDim == other.textDim &&
          textFaint == other.textFaint &&
          accent == other.accent &&
          accentText == other.accentText &&
          ok == other.ok &&
          stage == other.stage &&
          stageGlow == other.stageGlow &&
          shadow == other.shadow &&
          scrim == other.scrim &&
          logo == other.logo;

  @override
  int get hashCode => Object.hash(brightness, bg, bgAlt, surface, surfaceHi, line, lineStrong, text, textDim, textFaint, accent, accentText, ok, stage,
      stageGlow, shadow, scrim, logo);

  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: _Dark.bg,
    bgAlt: _Dark.bgAlt,
    surface: _Dark.surface,
    surfaceHi: _Dark.surfaceHi,
    line: _Dark.line,
    lineStrong: _Dark.lineStrong,
    text: _Dark.text,
    textDim: _Dark.textDim,
    textFaint: _Dark.textFaint,
    accent: _Dark.accent,
    accentText: _Dark.accent,
    ok: _Dark.ok,
    stage: _Dark.bg,
    stageGlow: Color(0x0DFFFFFF),
    shadow: Color(0x8C000000),
    scrim: Color(0x99000000),
    logo: LogoPalette(
      wordStart: Color(0xFFC98A5B),
      wordMid: Color(0xFFF1B987),
      wordEnd: Color(0xFFFFF3E6),
      wordOutline: Color(0xFF1B2433),
      tagline: Color(0xFFF3D6A4),
      taglineEdge: Color(0xFFA9783C),
      shadow: Color(0x00000000),
    ),
  );

  static const light = AppColors(
    brightness: Brightness.light,
    bg: _Light.bg,
    bgAlt: _Light.bgAlt,
    surface: _Light.surface,
    surfaceHi: _Light.surfaceHi,
    line: _Light.line,
    lineStrong: _Light.lineStrong,
    text: _Light.text,
    textDim: _Light.textDim,
    textFaint: _Light.textFaint,
    accent: _Light.accent,
    accentText: _Light.accentText,
    ok: _Light.ok,
    stage: Color(0xFFE9ECF1),
    stageGlow: Color(0xD9FFFFFF),
    shadow: Color(0x33101820),
    scrim: Color(0x66101820),
    logo: LogoPalette(
      wordStart: Color(0xFFB4743F),
      wordMid: Color(0xFFD99A5F),
      wordEnd: Color(0xFFF0CFA6),
      wordOutline: Color(0xFF1B2433),
      tagline: Color(0xFFB98A45),
      taglineEdge: Color(0xFF3A2410),
      shadow: Color(0x40404858),
    ),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? bgAlt,
    Color? surface,
    Color? surfaceHi,
    Color? line,
    Color? lineStrong,
    Color? text,
    Color? textDim,
    Color? textFaint,
    Color? accent,
    Color? accentText,
    Color? ok,
    Color? stage,
    Color? stageGlow,
    Color? shadow,
    Color? scrim,
    LogoPalette? logo,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      bgAlt: bgAlt ?? this.bgAlt,
      surface: surface ?? this.surface,
      surfaceHi: surfaceHi ?? this.surfaceHi,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      text: text ?? this.text,
      textDim: textDim ?? this.textDim,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      ok: ok ?? this.ok,
      stage: stage ?? this.stage,
      stageGlow: stageGlow ?? this.stageGlow,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
      logo: logo ?? this.logo,
    );
  }

  /// Tema geçişi sırasında bütün renkler birlikte, yumuşakça karışır.
  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: mix(bg, other.bg),
      bgAlt: mix(bgAlt, other.bgAlt),
      surface: mix(surface, other.surface),
      surfaceHi: mix(surfaceHi, other.surfaceHi),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      text: mix(text, other.text),
      textDim: mix(textDim, other.textDim),
      textFaint: mix(textFaint, other.textFaint),
      accent: mix(accent, other.accent),
      accentText: mix(accentText, other.accentText),
      ok: mix(ok, other.ok),
      stage: mix(stage, other.stage),
      stageGlow: mix(stageGlow, other.stageGlow),
      shadow: mix(shadow, other.shadow),
      scrim: mix(scrim, other.scrim),
      logo: LogoPalette.lerp(logo, other.logo, t),
    );
  }
}

/// `context.colors` ile geçerli temanın renk jetonlarına erişim.
/// Tema uzantısı yoksa (ör. çıplak bir MaterialApp ile yazılmış test) site varsayılanı olan koyu palet kullanılır.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

/// Uygulamanın iki teması. MaterialApp'e `theme: AppTheme.light, darkTheme: AppTheme.dark` verilir;
/// hangisinin görüneceğini `themeMode` (bkz. lib/core/theme_controller.dart) belirler.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AppColors.dark);
  static ThemeData get light => _build(AppColors.light);

  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: c.brightness).copyWith(
      surface: c.bg,
      onSurface: c.text,
      primary: c.accent,
      outline: c.lineStrong,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      fontFamily: AppText.family,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.line,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent, selectionColor: c.accentSoft),
      extensions: [c],
    );
  }
}

class Contact {
  Contact._();

  static const phoneDisplay = '(0) 543 795 6044';
  static const phoneUri = 'tel:+905437956044';
  static const email = 'bilgi@gudeteknoloji.com';
  static const whatsapp = 'https://wa.me/905437956044';
  static const address = 'Yalı Mah. 6436 Sok. No:37/A\nKarşıyaka / İzmir';
  static const teklifPro = 'https://teklif.gudeteknoloji.com/';
}

/// Bağlantının tarayıcıda hangi pencerede açılacağı: http(s) yeni sekmede, mailto:/tel: gibi uygulama şemaları aynı
/// sekmede (`_self`) işlenir. Bunlar `_blank` ile açılırsa tarayıcı boş bir sekme/pop-up oluşturur ve pop-up engelleyiciye takılır.
String linkWindowName(Uri uri) => uri.scheme == 'http' || uri.scheme == 'https' ? '_blank' : '_self';

Future<void> openLink(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, webOnlyWindowName: linkWindowName(uri));
}

/// Ekran genişliğine göre akıcı (kademesiz) boyut: 360 px genişlikte [min], 1440 px ve üzerinde [max].
double fluid(BuildContext context, double min, double max) => fluidFor(MediaQuery.sizeOf(context).width, min, max);

/// [fluid] ile aynı, doğrudan genişlikten (bağlamsız; yerleşim hesapları ve testler için).
double fluidFor(double width, double min, double max) {
  final t = ((width - 360) / (1440 - 360)).clamp(0.0, 1.0);
  return min + (max - min) * t;
}

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;
bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < 600;

/// Tipografi. Tek aile (Manrope, değişken ağırlık). Başlıklar abartılı büyük değildir;
/// ekran metinle doldurulmaz, her sahne nefes alır. Bağlam alan stillerin rengi temadan gelir.
class AppText {
  AppText._();

  static const family = 'Manrope';

  static TextStyle _s(double size, int weight, {double? height, double? spacing, required Color color}) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      height: height,
      letterSpacing: spacing,
      color: color,
    );
  }

  /// Açılış başlığı: 34 → 56 px
  static TextStyle display(BuildContext c) {
    final s = fluid(c, 34, 56);
    return _s(s, 700, height: 1.06, spacing: -s * 0.02, color: c.colors.text);
  }

  /// Sahne başlığı: 26 → 40 px
  static TextStyle h2(BuildContext c) {
    final s = fluid(c, 26, 40);
    return _s(s, 700, height: 1.1, spacing: -s * 0.015, color: c.colors.text);
  }

  /// Alt başlık / kart başlığı: 17 → 21 px
  static TextStyle h3(BuildContext c) => _s(fluid(c, 17, 21), 650, height: 1.25, spacing: -0.2, color: c.colors.text);

  /// Gövde metni: 15 → 17 px
  static TextStyle body(BuildContext c, {Color? color}) => _s(fluid(c, 15, 17), 450, height: 1.6, color: color ?? c.colors.textDim);

  /// Küçük metin: 13 px
  static TextStyle small(BuildContext c, {Color? color}) => _s(13, 500, height: 1.5, color: color ?? c.colors.textDim);

  /// Küçük, büyük harfli etiket: 11.5 px
  static TextStyle label(BuildContext c, {Color? color}) => _s(11.5, 650, height: 1.2, spacing: 1.8, color: color ?? c.colors.textDim);

  /// Üst çubuk menü bağlantısı: 13.5 px
  static TextStyle navOf(BuildContext c, {Color? color}) => _s(13.5, 550, height: 1.2, spacing: 0.1, color: color ?? c.colors.textDim);

  /// Yan panel bağlantısı: 18 → 22 px
  static TextStyle panelLink(BuildContext c, {Color? color}) {
    final s = fluid(c, 18, 22);
    return _s(s, 600, height: 1.15, spacing: -s * 0.015, color: color ?? c.colors.text);
  }

  /// Düğme metni: 14 px
  static TextStyle buttonOf(BuildContext c, {Color? color}) => _s(14, 650, height: 1.0, spacing: 0.1, color: color ?? c.colors.filledFg);
}

/// Eski giriş noktası: koyu tema. Yeni kod `AppTheme.dark` / `AppTheme.light` kullanır.
ThemeData buildTheme() => AppTheme.dark;
