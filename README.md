# Güde Teknoloji web sitesi

Flutter web ile hazırlanmış, koyu/açık temalı, sahne tabanlı kurumsal tanıtım sitesi (http://gudeteknoloji.com).

## Yapı

| Yol | İçerik |
|---|---|
| `lib/main.dart` | Uygulama girişi, iki temalı MaterialApp, `tr` dil ayarı |
| `lib/theme.dart` | **Renk paletleri (koyu + açık) tek yerde**, tipografi, iletişim bilgileri |
| `lib/core/` | Yay fiziği, kaydırma kapsamı, görünürlük, tema denetleyicisi ve kaydı |
| `lib/pages/` | Sayfa birleşimi, üst çubuk (normal menü + sandviç), yan panel, sahne mıknatısı |
| `lib/scenes/` | Açılış/iris geçişi, kamera sahnesi, ilk ürün reklamı, ekranlı ürün, hizmetler, süreç, referanslar, teklif, iletişim |
| `lib/camera3d/` | Kodla üretilen hafif yazılım-3B kamera (yer tutucu model) |
| `lib/brand/` | Vektör logo: `gude_logo.dart` (bileşen), `gude_logo_data.dart` (üretilmiş yollar), `logo_model.dart` |
| `assets/images/` | Kutu cihaz görseli (`ahbu_box.png`) |
| `tool/logo/` | Logo SVG'sini Dart verisine çeviren betik (`svg_to_dart.py`) ve sözleşmesi |
| `docs/` | `DESIGN_SPEC.md` (tasarım sözleşmesi), `THEMING.md` (tema kuralları) |
| `tool/` | Yayın betiği (`deploy_ftp.sh`), komut kilidi (`flt.sh`), tarayıcı sınama araçları (`tool/qa/`) |

## Temayı tek noktadan yönetme

Bütün renkler `lib/theme.dart` içindeki `AppColors.dark` ve `AppColors.light` paletlerindedir; widget'lar renkleri `context.colors` ile okur.
Varsayılan mod `kDefaultThemeMode`, tema anahtarı görünürlüğü `kThemeSwitchVisible`. Ayrıntı: `docs/THEMING.md`.

## Çalıştırma ve test

```
flutter pub get
flutter run -d chrome          # geliştirme
flutter test                   # testler (600+)
flutter analyze
```

Önizleme bayrağı (yalnızca sınama için): `flutter build web --release --dart-define=PREVIEW=true` derlemesinde adrese
`?scroll=<ekran yüksekliği katı>`, `?menu=1`, `?theme=light|dark` eklenebilir. **Canlıya bu bayrakla derlenmiş sürüm yüklenmez.**

## Canlıya yükleme

1. Üretim derlemesi (bayraksız): `flutter build web --release -o <klasör>`.
   CanvasKit kendi alan adımızdan yüklenir (`web/flutter_bootstrap.js`); Google CDN'ine bağımlılık yoktur.
2. Kullanılmayan CanvasKit varyantları (`skwasm*`, `wimp*`, `webparagraph`, `*.symbols`) yüklemeden önce ayıklanabilir (41 MB → 17 MB);
   Chrome/Edge için `canvaskit/chromium/*`, diğer tarayıcılar için `canvaskit/canvaskit.*` kalmalıdır.
3. `FTP_USER=... FTP_PASS=... tool/deploy_ftp.sh <klasör>`: önce `index.html` ve `.htaccess` yedeklenir (`yedek_canli_site/<zaman>/`),
   `index.html` en son yüklenir, hiçbir şey silinmez. Şifre dosyada tutulmaz.
4. **Sunucuda `.htaccess` içinde `AddType application/wasm .wasm` bulunmalıdır** (yoksa tarayıcı CanvasKit'i reddeder ve site açılmaz). Mevcut dosyada vardır;
   `.htaccess` üzerine yazılmamalı, yalnızca eklenmelidir (içinde `teklif` alt alanının yönlendirmesi var).
5. Yükleme sonrası canlı adres gerçek tarayıcıda açılıp konsol hatası olmadığı doğrulanmalıdır.

Geri alma: `yedek_canli_site/<zaman>/index.html` dosyasını `public_html/index.html` olarak yeniden yükleyin.

## Bilinen eksikler

- Alan adı için SSL sertifikası yoktur (sunucu `*.srvpanel.com` sertifikası gösterir); `https://` adresi tarayıcıda uyarı verir. cPanel → SSL/TLS Durumu → AutoSSL ile alınmalıdır.
- Kamera modeli kodla üretilmiş yer tutucudur; gerçek ürün görseli gelince `lib/scenes/camera/product_layer.dart` tek bağlantı noktasıdır.
- Ürün adı ("AHBU") ve ilk ürünün teknik maddeleri onay bekler (`// YER TUTUCU:` notları).
- Sunucuda brotli/gzip ve uzun önbellek ayarı yapılırsa ilk yükleme belirgin hızlanır.
