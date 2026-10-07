# Logo (vektör) işlem hattı

Güde Teknoloji logosu, kullanıcının verdiği 1600×1056 PNG'den vektöre çevrilmiştir ve sitede **şeffaf zeminli vektör** olarak çizilir
(plaka yok: koyu temada koyu, açık temada açık zeminin üstünde durur).

| Dosya | Görev |
|---|---|
| `gude_logo.svg` | Vektör kaynağı (tek doğruluk kaynağı). Aşağıdaki sözleşmeye uyar. |
| `source_1600.png` | Vektörleştirmenin çıktığı özgün görsel (beyaz zeminli). |
| `svg_to_dart.py` | `gude_logo.svg` → `lib/brand/gude_logo_data.dart` (üretilmiş dosya, elle düzenlenmez). |
| `make_icons.py` | Yapraklardan `web/favicon.png` ve `web/icons/*` simgelerini üretir. |
| `render_svg.mjs` | SVG'yi Chrome ile PNG'ye çizer (önizleme/doğrulama). |

## Yeniden üretme

```
python tool/logo/svg_to_dart.py tool/logo/gude_logo.svg      # lib/brand/gude_logo_data.dart
python tool/logo/make_icons.py  tool/logo/gude_logo.svg      # web/favicon.png, web/icons/*
```

Logoyu değiştirmek için yalnızca `gude_logo.svg` yenilenir ve iki komut yeniden çalıştırılır; bileşen (`lib/brand/gude_logo.dart`) ve tema renkleri
(`AppColors.logo`, `lib/theme.dart`) değişmez.

## SVG sözleşmesi

- `viewBox="0 0 W H"`, arka plan dikdörtgeni yok (dış alan şeffaf).
- Yalnızca `svg, defs, linearGradient, radialGradient, stop, g, path`; `text/image/filter/mask/clipPath/transform/style` yok. Yazılar yol olarak çizilmiştir.
- Yol komutları yalnızca mutlak `M L C Z`. Gradyanlar `gradientUnits="userSpaceOnUse"`.
- Üst düzey gruplar (alttan üste): `shadow` (yumuşak gölge şekilleri; çalışma zamanında hafifçe bulanıklaştırılır, **koyu temada çizilmez**),
  `leaves` (`leaf1..leaf4`), `wordmark` (`wordmark-outline` koyu kenar, `wordmark-fill` harf yüzleri, `url(#wordmarkGradient)`), `tagline` (`tagline-outline`, `tagline-fill`).
- Temaya bağlı olanlar çalışma zamanında `AppColors.logo` (`LogoPalette`) ile verilir: harf yüzü gradyanının renk durakları (yön SVG'den), harf kenarı,
  slogan dolgusu ve kenarı, gölge rengi. Yapraklar SVG'deki gradyanlarla çizilir (iki temada aynı).
