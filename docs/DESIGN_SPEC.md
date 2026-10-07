# Güde Teknoloji web sitesi — Tasarım ve sahne şartnamesi

Bu belge, siteyi birlikte kuran herkesin (insan veya ajan) uyacağı ortak sözleşmedir.
Amaç: ziyaretçi siteyi gezerken sakin, koyu ve premium bir teknoloji showroomunda dolaşıyormuş gibi hissetsin;
kullanım ise son derece doğal kalsın.

Ziyaretçide oluşacak temel his: **"Bu şirket yalnızca ürün satmıyor; teknolojiyi biliyor, uyguluyor ve yaptığı işin arkasında duruyor."**

> **Tema notu:** Bu belge görsel dili *koyu tema* üzerinden anlatır. Site iki temalıdır (koyu + açık); renkler tek noktadan
> (`lib/theme.dart` → `AppColors`) yönetilir ve widget'lar renkleri `context.colors` ile okur. Kurallar ve açık tema sanat yönetimi
> **docs/THEMING.md**'dedir ve bağlayıcıdır. Aşağıdaki tablodaki `Brand.*` adları koyu paletin karşılığıdır; yeni kodda `context.colors.*` kullanın.

## 1. Teknik zemin

- Flutter 3.47 / Dart 3.13, hedef: **web** (CanvasKit). Masaüstü ve mobil tarayıcı.
- Yeni bağımlılık eklenmez (mevcut: `qr_flutter`, `url_launcher`). Gerekirse `lib/` içinde kendi küçük yardımcınızı yazın.
- Tüm flutter/dart komutları `tool/flt.sh` üzerinden çalıştırılır (birden fazla ajan aynı klasörde çalışıyor, komutlar sıraya girer):
  `tool/flt.sh flutter analyze`, `tool/flt.sh flutter test test/<dosya>_test.dart`. Doğrudan `flutter ...` çalıştırmayın.
- Başkasının dosyasına dokunmayın. Yalnızca size atanan dosyaları oluşturun/değiştirin. Ortak dosyalarda
  (`lib/theme.dart`, `lib/core/*`, `lib/widgets/common.dart`, `lib/widgets/reveal.dart`, `docs/*`) değişiklik gerekiyorsa
  yapmayın; dönüş raporunuza "ortak dosya değişikliği önerisi" olarak yazın.
- Başka ajanların dosyaları yarım olabilir. `flutter analyze` çıktısında sizin dosyalarınızın dışındaki hataları yok sayın,
  işiniz bittiğinde bir kez daha çalıştırıp **kendi dosyalarınızın** temiz olduğunu doğrulayın.
- Kod okunaklı olsun: çevredeki kodun yorum yoğunluğu ve adlandırma biçimini izleyin, yorumlar Türkçe ve "neden"i anlatsın.
  `withValues(alpha:)` kullanın (`withOpacity` değil). `MaterialApp`'te debug banner kapalı olmalı.

## 2. Görsel dil

**Zemin siyah/antrasit, yazı açık gri-beyaz, tek vurgu soğuk turkuaz.** Jetonlar `lib/theme.dart` içindedir; `Colors.red`
gibi sabit renkler yerine bunları kullanın.

| Jeton | Değer | Kullanım |
|---|---|---|
| `Brand.bg` | #06080B | Ana zemin |
| `Brand.bgAlt` | #0B0E13 | Ardışık bölümleri ayırmak için hafif farklı zemin |
| `Brand.surface` / `surfaceHi` | #11151B / #181D25 | Kart, panel |
| `Brand.line` / `lineStrong` | %10 / %20 beyaz | İnce çizgiler (1 px) |
| `Brand.text` / `textDim` / `textFaint` | #F3F5F8 / #A3ACB9 / #6B7482 | Yazı |
| `Brand.accent` | #58D6CB | LED ışığı, ince çizgi, aktif durum. Ekranın en çok %2'sinde |
| `Brand.ok` | #34D399 | Yalnızca "açıldı/başarılı" durumları |

- Yoğun renk, mavi gradyan, renkli kartlar, neon **yok**. Renk gerekiyorsa ürünün kendi ışığı (LED, ekran, lens kaplaması).
- Işık: zeminde çok yumuşak radyal parıltı (beyaz %4–6 ya da vurgu ≤ %8 alfa). Gölge: geniş, yumuşak, düşük opaklık.
- Logodaki altın yalnızca logonun kendisinde görünür (üst çubuktaki vektör logo). UI'da altın/şeftali kullanmayın.
- Köşe yarıçapı: kart 20, düğme tam yuvarlak (22), küçük öğeler 10–12.
- 8 px ızgara. Bölüm dikey boşluğu `fluid(context, 64, 112)`.

### Tipografi (`AppText`, Manrope)

Başlıklar büyük ama **abartısız** (kullanıcı önceki sürümde 104 px başlığı ve 44 px menüleri çok büyük buldu):
`display` 34→56 px, `h2` 26→40 px, `h3` 17→21 px, `body` 15→17 px, `small` 13, `label` 11.5 (büyük harf, geniş aralık),
menü bağlantısı 13.5 px, yan panel bağlantısı 18→22 px. Boyutlar `fluid()` ile ekran genişliğine göre kademesiz ölçeklenir.
Bu ölçüyü aşmayın. Her sahne: en çok 1 başlık (≤ 6 kelime), 1 kısa paragraf (≤ 2 satır), ≤ 3 madde. Sahneler nefes almalı.

## 3. Hareket ilkeleri (en önemli bölüm)

1. **Dikey hareket = sayfada gezinme.** Sayfa normal dikey scroll ile gezilir; yeni bir gezinme sistemi öğretilmez.
2. **Yatay ürün sürükleme = ürünü döndürme.** Mobilde dikey parmak hareketi her zaman sayfayı kaydırır; belirgin yatay hareket ürünü döndürür.
3. **Her sahnenin tek kahramanı var.** Diğer hareketler çok küçük ve yavaş mikro animasyonlardır (periyot ≥ 8 sn, genlik küçük).
   Boşta duran kahraman ürün de hafifçe yaşar: birkaç derece yavaş dönme / perspektif değişimi / ışık kayması.
4. **Doğrusal (linear) animasyon yok.** Yay fiziği kullanın: `SpringCurve` (ζ≈0.72, hedefi ~%4 aşar) veya `Spring1D`
   (`lib/core/motion.dart`). Kullanıcının bıraktığı nesne anında eski yerine atlamaz: önce momentum ile biraz devam eder,
   yavaşlar, sonra yay fiziğiyle ana konumuna oturur (gerekirse hedefi çok az aşıp küçük salınımla). İlerleme çubukları istisnadır.
5. **Bölümler arası geçiş yumuşak, sinematik ama kısa.** Hareket asla içeriğin önüne geçmez, yorucu veya gösteriş amaçlı durmaz.
6. **Performans:** ağır video yok, aynı anda onlarca animasyon yok. Sahne ekran dışındayken tüm döngüler durur
   (`VisibilityProbe`, `FrameLoop.stop`). Ağır çizimler `RepaintBoundary` içinde, `CustomPainter(repaint: Listenable)` ile
   widget ağacı yeniden kurulmadan çizilir. Karede gereksiz nesne üretmeyin (önbellekleyin).
7. **Hareketi azalt:** `reduceMotionOf(context)` true ise boşta animasyonlar ve momentum kapatılır; geçişler anlık olur.
8. **Erişilebilirlik:** etkileşimli ürünlere `Semantics` etiketi verin; döndürülebilen ürün klavyede ←/→ ile de döner;
   düğmeler odaklanabilir. Metin kontrastı WCAG AA.

## 4. Duyarlı tasarım

Kırılımlar: `< 600` telefon, `600–900` tablet, `≥ 900` masaüstü (`isWide`). Masaüstü kompozisyonu mobilde küçültülmüş
görünmemeli: telefon için yerleşim ve etkileşim ayrıca düşünülür. Test boyutları: **1440×900, 1024×768, 390×844, 360×740**.
Taşma (overflow) olmamalı; büyük yazı boyutlarında bile (`textScaler`) içerik kırpılmadan sığmalı ya da kontrollü küçülmeli.

## 5. Sayfa akışı ve sözleşmeler

```
Üst çubuk (sabit)          lib/pages/home_page.dart  (vektör logo 84→126 px + normal menü + sandviç panel)  — ana oturum yazar
─ HeroCameraBlock          lib/scenes/hero_camera_block.dart   (sabitlenen sahne: Açılış → iris → Kamera sistemleri)
   ├─ Açılış (hero)        iris/lens kahramanı
   └─ CameraScene          lib/scenes/camera_scene.dart        360° döndürülebilir kamera
─ RemoteDoorScene          lib/scenes/remote_door_scene.dart   ilk ürün: uzaktan kapı açma (reklam animasyonu)
─ ScreenDoorScene          lib/scenes/screen_door_scene.dart   AHBU Akıllı Kapı Kontrol (ekranlı)
─ ServicesScene            lib/scenes/services_scene.dart      diğer hizmetler
─ ProcessScene             lib/scenes/process_scene.dart       çalışma şekli (4 adım)
─ ReferencesScene          lib/scenes/references_scene.dart    referanslar (STATİK; akan yazı yok)
─ TeklifBand               lib/scenes/teklif_band.dart
─ ContactScene             lib/scenes/contact_scene.dart       iletişim + alt bilgi
```

**Akan/kayan yazı (marquee, ticker) kullanılmaz.** Kullanıcı bunu açıkça istemedi.

### 5.1 Açılış → Kamera geçişi (`HeroCameraBlock`)

```dart
class HeroCameraBlock extends StatefulWidget {
  const HeroCameraBlock({super.key, required this.cameraBuilder, required this.onExplore, required this.onContact});
  /// Kamera sahnesi; geçiş ilerledikçe `reveal` 0→1 olur (kaydırma ile oynatılır, kendi zamanı yoktur).
  final Widget Function(BuildContext context, ValueListenable<double> reveal) cameraBuilder;
  final VoidCallback onExplore; // "Kamera Sistemlerini Keşfedin"
  final VoidCallback onContact; // "Bize Ulaşın"
  /// Sabitlenmiş sahnenin kaydırma mesafesi.
  static double transitionDistance(double viewportHeight) => viewportHeight * 0.95;
  /// Bloğun toplam yüksekliği = viewport + geçiş mesafesi.
  static double totalHeight(double viewportHeight) => viewportHeight + transitionDistance(viewportHeight);
}
```

- Blok kaydırma alanının **ilk çocuğudur**; `ScrollScope.of(context)` ile `controller` ve `viewportHeight` alır.
  `p = (controller.offset / transitionDistance).clamp(0,1)`.
- Sahne (stage), `0 ≤ offset ≤ D` aralığında görünür alanın tepesine sabitlenir (`Transform.translate(dy: offset.clamp(0, D))`),
  sonra normal kayar. Stage'in yüksekliği = `viewportHeight`.
- Stage'in alt katmanı `cameraBuilder` (kamera sahnesi, tam boyut), üst katmanı açılış sahnesidir.
- Açılışın kahramanı bir **lens/iris**tir (kamera firması klişesi değil: temiz, mühendislik hissi veren, tırtıklı halka,
  diyafram ölçeği işaretleri, ince turkuaz LED halka, cam kaplama yansıması, 9 yapraklı diyafram). Kaydırma ilerledikçe:
  başlık/metin hızla solar, lens büyür ve diyaframın açıklığı genişleyerek **altındaki Kamera sahnesini açıklıktan** gösterir;
  sonunda açıklık ekranı kaplar ve kamera sahnesi tam görünür ("görüntünün içinden geçmek"). Kısa, sakin, yorucu değil.
  Delik, üst katmanın `saveLayer + BlendMode.clear` ile kesilmesiyle yapılır.
- Geçiş sırasında kamera sahnesine `pointer` olayları `p < 0.98` iken kapalıdır; açılış sahnesi `p > 0.3` iken kapalıdır.
- Açılışta kahramanın boşta mikro hareketleri: halka parlaklığı çok yavaş kayar, diyafram nefes alır (±%3), LED çok yavaş nabız atar.
  Masaüstünde fare konumuna doğru ±6 px paralaks.
- Üst çubuk 64 px yüksekliğinde sabit; içerik üstte 72 px boşluk bırakır.

### 5.2 Kamera sahnesi (`CameraScene`)

```dart
class CameraScene extends StatefulWidget {
  const CameraScene({super.key, required this.reveal}); // reveal: 0→1 (açıklıktan görünme); 1 = tam görünür, serbest etkileşim
  final ValueListenable<double> reveal;
}
```

- Verilen kısıtlar sıkıdır (viewport boyutu). İçerik `reveal` ile sahneye girer (kamera ölçek/opaklık, yazılar gecikmeli).
- Kahraman: **tek bir kaliteli kamera** (aşağıdaki "yer tutucu" notu). Masaüstünde basılı tutup sürükleyince 360° döner;
  bırakınca momentum (sürtünmeyle sönen), sonra yay fiziğiyle başlangıç açısına dönüş (en yakın eşdeğer açı; ζ≈0.65).
  Boşta: yaw ±5° / periyot ~14 sn, pitch ±1.5° / ~9 sn, ışık yansıması çok yavaş kayar.
- Mobil: yalnızca yatay sürükleme ürünü döndürür; dikey sürükleme sayfayı kaydırır (`GestureDetector` yalnızca `onHorizontalDrag*`).
- İlk etkileşimden sonra kaybolan sade bir ipucu: "Sürükleyerek döndürün" (mobilde "Yatay çevirerek döndürün").
- Metin: etiket "KAMERA SİSTEMLERİ", başlık "Her açıdan net görüntü.", gövde "IP ve analog kamera sistemleri, kayıt çözümleri,
  ağ altyapısı ve profesyonel görüntüleme sistemleri." Ürünün yanında 3 ince çizgi-notu: "IP ve analog sistemler",
  "Kayıt çözümleri", "Ağ altyapısı". Başka teknik özellik **uydurmayın**.
- **Yer tutucu notu:** elimizde gerçek kamera modeli/fotoğrafı yok. Kamera, kodla üretilen genel bir "bullet" kameradır
  (mat grafit gövde, güneşlik, ön lens kaplaması, IR LED halkası, ayak). Gerçek ürün görseli gelince değiştirilecek;
  kodda `// YER TUTUCU:` notuyla belirtin.
- Üç boyut: kod içinde yazılmış hafif yazılım 3B (Canvas, painter's algorithm / `drawVertices`). WebGL/üçüncü parti paket yok.

### 5.3 Ürünler

İki ürün sahnesi vardır. Sıra: önce **ilk ürün** (uzaktan açma kutusu), sonra **ekranlı** cihaz.

**RemoteDoorScene** — "İlk ürünümüz": yalnızca mobil uygulamayla uzaktan kapı açan kompakt kutu. Görsel:
`assets/images/ahbu_box.png` (şeffaf zeminli CAD render; `ahbu_box.json` içinde normalize işaret noktaları: `led_blue`, `light_hole`,
`usb_c`, `dot`, `aspect`). Bu bir **reklam gibi** animasyonlu sahnedir (≈9 sn döngü, sahne ekrandayken oynar, dışındayken durur):
telefon (kodla çizilmiş AHBU uygulaması) → parmak dokunuşu "KAPIYI AÇ" → telefondan kutuya giden sinyal darbeleri →
kutudaki mavi LED parlar, çok kısa "klik" halkası → kapı/kapak açılır, ışık sızar, telefonda "Kapı açıldı" ✓ → bekleme → döngü.
Kutu hafifçe yüzer, yüzeyinde çok yavaş ışık süpürmesi gezer. Mobilde sahne dikey kompozisyona geçer.
Metin: etiket "İLK ÜRÜNÜMÜZ", başlık "Kapıyı telefonunuzdan açın.", gövde "Yalnızca mobil uygulamayla, uzaktan kapı açan ilk AHBU cihazı.
Kompakt kutu, tek dokunuşla açma.", maddeler: "Mobil uygulamayla uzaktan açma", "Wi-Fi ile bağlantı", "Kompakt, USB-C girişli gövde".
Düğme: "Teklif İsteyin" (`onContact`). Ürün adı yer tutucudur (`// YER TUTUCU:`).

**ScreenDoorScene** — "AHBU Akıllı Kapı Kontrol": mevcut `lib/widgets/ahbu_device.dart` (kodla çizilmiş, karekodlu ekranlı cihaz;
kullanıcı bu çizimi onayladı, **değiştirmeyin**). Metin: etiket "YENİ NESİL", başlık "AHBU Akıllı Kapı Kontrol", gövde
"Site ve apartman girişleri için geliştirdiğimiz, ekranlı kapı kontrol cihazı. Şifre ve kart taşımadan, telefonla güvenli giriş.",
maddeler (ikon + başlık + tek satır): "Dinamik karekod — Ekrandaki karekod 30 saniyede bir yenilenir; kopyalanan kod işe yaramaz.",
"Mobil uygulama — Kapı telefondan uzaktan açılır; misafirlere süreli bağlantı gönderilir.",
"İnternet kesilse de çalışır — Yerel ağ üzerinden açma ve çevrimdışı kayıtların sonradan eşitlenmesi.",
"Uzaktan güncelleme — Cihaz yazılımı sahaya gitmeden, güvenli şekilde güncellenir."


> **Güncel imza notu:** `RemoteDoorScene({super.key, onContact, @visibleForTesting debugClock})`; sahnede `Reveal` yalnızca metindedir, reklam sahnesi
> ekrana her girişte baştan oynar. `CameraScene` ürün kutusu ekran genişliğinden biraz büyüktür (profil görünümü sığsın diye).

### 5.4 Diğer bölümler (kısa, sakin, tek tip)

- **ServicesScene** ("Hizmetler"): etiket "HİZMETLERİMİZ", başlık "Teknolojiyi projenin ihtiyacına göre uygularız."
  Kamera sahnesi zaten ayrı olduğundan 5 hizmet: İnterkom Sistemleri (IP ve iki telli görüntülü interkom sistemleri, güvenlik ve daire iletişim çözümleri),
  Geçiş Kontrol (Kartlı geçiş, kapı kontrolü, personel erişimi ve merkezi yönetim sistemleri), Turnike ve Bariyer (Personel ve araç geçişlerinin kontrolü için
  turnike ve bariyer çözümleri), Yangın Algılama (Yangın algılama, ihbar ve projeye uygun güvenlik sistemleri), Akıllı Ev Sistemleri (Aydınlatma, kontrol, güvenlik ve
  otomasyon sistemlerinin entegre çözümleri). Renkli kart yok: grafit yüzeyli, ince çizgili, tek renkli çizgi ikonlu sade liste/kartlar; üzerine gelince ince vurgu.
- **ProcessScene**: etiket "ÇALIŞMA ŞEKLİMİZ", başlık "Projeden sahaya tek noktadan çözüm.", gövde "Sadece ürün temin eden değil, doğru sistemi tasarlayan ve sahada çalışır
  hale getiren bir teknik çözüm yaklaşımıyla çalışıyoruz." 4 adım: Keşif (Saha ve ihtiyaç analizi), Projelendirme (Doğru ürün ve altyapı seçimi),
  Uygulama (Kurulum ve devreye alma), Servis (Bakım ve teknik destek). Adımlar birbirine ince çizgiyle bağlanır; kaydırınca çizgi yayla uzar.
- **ReferencesScene**: etiket "REFERANSLAR", başlık "Bazı projelerimiz." Folkart Life, Folkart Time, Sinpaş Aqua City, Manisa Meydan Projesi, TÜPRAŞ Teknik Yapı.
  **Statik** tipografik liste/ızgara (akan yazı yok), üzerine gelince ince vurgu.
- **TeklifBand**: etiket "TEKLİF PRO", başlık "Teklif süreçlerini hızlı ve düzenli yönetin.", gövde "Teklif hazırlama, ürün yönetimi, revizyon takibi ve proje süreçlerini
  daha hızlı ve düzenli yönetmek için geliştirdiğimiz sistem.", düğme "Teklif Pro" → `openLink(Contact.teklifPro)`.
- **ContactScene**: etiket "İLETİŞİM", başlık "Projenizi konuşalım." (büyük değil: `h2`/`display` ölçüsünde), gövde "Yeni sistem kurulumu, mevcut sistemlerin yenilenmesi veya teknik servis
  ihtiyaçlarınız için bizimle iletişime geçebilirsiniz.", düğme "WhatsApp'tan Ulaşın", Telefon/E-posta/Adres satırları (`Contact.*`), en altta "© 2026 Güde Teknoloji. Tüm hakları saklıdır."

Ortak sahne imzası: `const XScene({super.key})` (ürün sahnelerinde ayrıca `VoidCallback? onContact`). Sahneler tam genişlik bir `Section` döner;
içerideki kaydırma yoktur (sayfa kaydırması kullanılır). Giriş animasyonu için `lib/widgets/reveal.dart` içindeki `Reveal` kullanılabilir.

## 6. İçerik kuralları

- Dil Türkçe; yazım ve noktalama doğru. Metinleri bu belgedeki gibi kullanın; uydurma teknik özellik, rakam, sertifika, müşteri iddiası **yok**.
- Eksik varlık için yer tutucu kullanın ve kodda `// YER TUTUCU:` ile işaretleyin.
- Telefon/e-posta/adres/WhatsApp/Teklif Pro bağlantıları yalnızca `Contact` sınıfından gelir.

## 7. Test ve görsel doğrulama

- Her sahne için `test/<sahne>_test.dart`: temel render, taşma yok (390 ve 1440 genişlikte), etkileşim (sürükleme, dokunma), `reveal`/ilerleme sınırları.
- `test/helpers/shot.dart`: `loadAppFonts()` + `shot(tester, app, size:, name:)` gerçek yazı tipiyle PNG üretir (`<geçici>/gt_shots/<ad>.png`);
  `Read` aracıyla görüp kendi işinizi eleştirin. **Birkaç durum/boyut/açı için görüntü alın, bakın, düzeltin** (en az 2 tur).
  Testlerde varsayılan "Ahem" yazı tipi yanlış taşma üretir; `setUpAll(loadAppFonts)` kullanın.
- Hedef: kendi gözünüzle "premium, sakin, net" derecesine ulaşana dek yineleyin; ilk çalışan sürümle yetinmeyin.
