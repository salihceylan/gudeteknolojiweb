# Açık / koyu tema — tek noktadan yönetim

Site iki temalıdır (**koyu** ve **açık**). Her şey tek bir yerden yönetilir; sahne dosyalarında renk değeri tutulmaz.

## Tek nokta

| Ne | Nerede |
|---|---|
| Bütün renk değerleri (iki palet) | `lib/theme.dart` → `AppColors.dark` ve `AppColors.light` (ham değerler `_Dark` / `_Light`) |
| Varsayılan mod | `lib/theme.dart` → `kDefaultThemeMode` (şu an `ThemeMode.dark`) |
| Tema anahtarı görünürlüğü | `lib/theme.dart` → `kThemeSwitchVisible` |
| Mod denetimi, kayıt (tarayıcı `localStorage`) | `lib/core/theme_controller.dart` (`ThemeController`, `ThemeScope`) |
| MaterialApp bağlantısı, geçiş animasyonu | `lib/main.dart` (`theme: AppTheme.light`, `darkTheme: AppTheme.dark`, `themeMode`) |

Bir rengi değiştirmek için yalnızca `lib/theme.dart` içindeki ilgili paleti düzenleyin. Yeni bir renk gerekirse `AppColors`'a
anlamsal bir jeton ekleyin (iki palette de doldurun, `copyWith` ve `lerp`'e ekleyin) — sahne dosyasına renk gömmeyin.
Tema değişimi anlık değildir: `AppColors.lerp` ile renkler yumuşakça karışır (MaterialApp `themeAnimationDuration`).

## Kullanım kuralları

1. Widget içinde renk **`context.colors`** ile okunur: `final c = context.colors;` → `c.bg`, `c.text`, `c.line`, `c.accent` …
   Yazı stilleri `AppText.*(context)` ile gelir (rengi temadan alır). `Brand.*` **yeni kodda kullanılmaz** (yalnızca koyu, eski sabitler; kaldırılacak).
2. Çocuk widget'a ya da yardımcı fonksiyona renk gerekiyorsa `AppColors c` parametresi geçirin; global/sabit renk tutmayın.
3. `CustomPainter`: ihtiyaç duyduğu tema renklerini **kurucuya alan** (final alan) olarak tutun ve `shouldRepaint`'te karşılaştırın;
   böylece tema geçişi sırasında yeniden boyanır. Painter içinde `Theme`/`context` kullanılamaz.
4. `const` ifadeleri: `context.colors` const değildir; renk içeren ağaçlarda `const` kullanamazsınız (yalnızca renksiz alt ağaçlar const kalır).
5. **Ortam rengi ile malzeme rengi ayrımı.** Temaya bağlı olan yalnızca *ortamdır*: zemin, yazı, çizgi, ışık/gölge, vurgu.
   *Ürünün kendi malzeme renkleri* (kamera gövdesi, lens kaplaması, metal, LED'in rengi, telefon çerçevesi, AhbuDevice) fiziksel olduğundan
   iki temada da **aynı kalır** ve sahne dosyasında sabit durur (yorumla belirtin). Ürünün zemine oturması (yansıma/gölge/parıltı) ise temaya göre ayarlanır.
6. Işık ve gölge: koyu temada zemini aydınlatan yumuşak parıltı `c.stageGlow` (%5 beyaz); açık temada aynı jeton güçlü bir "stüdyo vurgusu"dur
   (zemin `c.stage`, merkez parlak). Ürün altı geniş yumuşak gölge `c.shadow` ile çizilir (koyuda %55 siyah, açıkta %20 koyu lacivert).
7. Vurgu: çizgi/LED/ikon için `c.accent`; **küçük yazı** için `c.accentText` (açık temada kontrastı yüksek sürüm). `c.ok` yalnızca "açıldı/başarılı".
8. Dolgulu düğme: `c.filledBg` zemin, `c.filledFg` yazı (iki temada da yüksek kontrast). Yüzeyler: `c.surface`/`c.surfaceHi`; çizgiler `c.line`/`c.lineStrong`.
9. Kontrast: ana metin ≥ 7:1, ikincil metin ≥ 4.5:1 (iki temada). `c.textFaint` yalnızca süs etiketlerinde.
10. Hareket/animasyon ilkeleri (DESIGN_SPEC §3) iki temada aynıdır.

## Açık tema sanat yönetimi

- Genel his: **sakin, ferah, premium** — saf beyaz değil, çok açık soğuk gri zemin (`#F4F5F7`), ürün sahnelerinde hafif daha koyu stüdyo zemini
  (`c.stage`) ve merkezde beyaz vurgu. Renk kısıtı aynıdır: tek vurgu turkuaz.
- Koyu ürünler (kamera, lens gövdesi, AhbuDevice, telefon) açık zeminde güçlü kontrast verir; açık gri CAD kutusu (`ahbu_box.png`) açık zeminde
  silikleşir: kutu için daha koyu/kontrastlı gradyan harmanı, belirgin temas gölgesi ve ince kenar ışığı gerekir (iki temayı da ekran görüntüsüyle doğrulayın).
- Logo (`GudeLogo`, `lib/brand/`) vektördür ve **plakasız, şeffaf zeminlidir**: koyu temada koyu, açık temada açık zeminin üstünde doğrudan durur. Renkleri `c.logo` (`LogoPalette`: yazı gradyanı, kenar, slogan, gölge) belirler; yaprak ve harf biçimleri `gude_logo_data.dart` içindedir (`tool/logo/svg_to_dart.py` üretir, elle düzenlenmez). Açık temada gölge görünür, koyuda yoktur.
- Üzerinde yazı olan fotoğrafik/çizim yüzeyler (ör. telefon ekranı, cihaz ekranı) tema değiştirmez.

## Test ve doğrulama

- Testlerde `MaterialApp`'i `test/helpers/app.dart` içindeki `testApp(home, brightness: ...)` ile kurun (iki tema yüklü).
- Her sahne **iki temada** (1440×900 ve 390×844) ekran görüntüsüyle kontrol edilir (`shot` + `Read`) ve her iki temada taşma olmamalı.
- Tema jetonlarının kontrast testi `test/theme_test.dart` içindedir; yeni jeton eklerseniz oraya da ekleyin.

## Pratik notlar (sahneleri uyarlarken öğrenilenler)

- `AppColors` alan bazlı `==`/`hashCode` taşır; painter'ın `shouldRepaint`'inde `old.colors != colors` yeterlidir. Tema geçişinde `lerp` her karede yeni
  örnek ürettiği için painter yeniden boyanır.
- `AppColors.ambient` (0 = koyu, 1 = açık) geçiş sırasında sürekli değişir; ikili `isDark` ise yarı yolda sıçrar. Yapısal ayarları (parıltı boyu, gölge
  biçimi) geçişte atlamasın diye `ambient` ile karıştırın.
- Açık zeminde *additive* (plus/screen) karışım beyaza doyar ve kaybolur: ışık/parıltı için normal alfa + halka kullanın, ya da temaya göre karışım modunu seçin.
- Gölge: `c.shadow` tek bir geniş yumuşak gölge içindir; açık temada basamaklı çift bant çıkıyorsa üst üste çok katmanlı sönüm çizin (bulanıklık filtresi kullanmadan).
- Testlerde `flutter_test` gölgeleri kapatır; `test/helpers/shot.dart` yakalama anında açıp kapatır (kendi testinizde `debugDisableShadows`'u tearDown'a bırakmayın).
- `Reveal` hareketi-azalt tercihine kendiliğinden uyar. Ekran dışında durması gereken sahneler `VisibilityProbe` kullanır.
