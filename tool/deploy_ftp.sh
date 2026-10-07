#!/usr/bin/env bash
# Derlenmiş siteyi (build dizini) FTP ile canlı sunucuya yükler.
#
#   FTP_USER=... FTP_PASS=... tool/deploy_ftp.sh <derleme-dizini> [--dry-run]
#
# Güvenlik: kimlik bilgileri dosyada tutulmaz, ortam değişkeninden okunur.
# Davranış:
#  1) Sunucudaki mevcut index.html ve .htaccess yedeklenir (yedek_canli_site/<zaman>/).
#  2) index.html HARİÇ tüm dosyalar önce yüklenir; index.html en SON yüklenir (yarım site görünmesin).
#  3) .htaccess ve sunucudaki eski klasörler (css, js, images, vendor, ...) DOKUNULMAZ; hiçbir şey silinmez.
#  4) Yükleme sonrası canlı adres doğrulanır.
set -euo pipefail

SRC="${1:?kullanım: deploy_ftp.sh <derleme-dizini> [--dry-run]}"
DRY="${2:-}"
HOST="${FTP_HOST:-ftp.gudeteknoloji.com}"
REMOTE_DIR="${FTP_DIR:-public_html}"
: "${FTP_USER:?FTP_USER tanımlı olmalı}"
: "${FTP_PASS:?FTP_PASS tanımlı olmalı}"
BASE="ftp://${HOST}/${REMOTE_DIR}"
CURL=(curl -s -S -m 180 --ftp-ssl -k --user "${FTP_USER}:${FTP_PASS}")

[ -f "$SRC/index.html" ] || { echo "HATA: $SRC/index.html yok"; exit 1; }
# Önizleme derlemesi yanlışlıkla yüklenmesin
if grep -q "PREVIEW" "$SRC/main.dart.js" 2>/dev/null && grep -q "menu=1\|theme=light" "$SRC/main.dart.js" 2>/dev/null; then
  echo "UYARI: main.dart.js önizleme (PREVIEW) kodu içeriyor olabilir; üretim derlemesi (bayraksız) kullanın." >&2
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="$(cd "$(dirname "$0")/.." && pwd)/yedek_canli_site/$STAMP"
mkdir -p "$BACKUP"
echo "== Yedek: $BACKUP"
for f in index.html .htaccess; do
  "${CURL[@]}" -o "$BACKUP/$f" "$BASE/$f" || echo "  (uyarı) $f yedeklenemedi"
done
ls -la "$BACKUP" | tail -n +2

mapfile -t FILES < <(cd "$SRC" && find . -type f ! -name '.last_build_id' | sed 's#^\./##' | sort)
echo "== Yüklenecek dosya: ${#FILES[@]} (index.html en son)"
if [ "$DRY" = "--dry-run" ]; then printf '  %s\n' "${FILES[@]}" | head -60; echo "(kuru çalıştırma: yükleme yapılmadı)"; exit 0; fi

fail=0
for f in "${FILES[@]}"; do
  [ "$f" = "index.html" ] && continue
  "${CURL[@]}" --ftp-create-dirs -T "$SRC/$f" "$BASE/$f" || { echo "HATA: $f"; fail=1; }
done
[ "$fail" = 0 ] || { echo "Yükleme hataları var; index.html yüklenmedi (eski sayfa yerinde)."; exit 2; }
"${CURL[@]}" -T "$SRC/index.html" "$BASE/index.html"
echo "== index.html yüklendi"

echo "== Doğrulama"
for u in http://gudeteknoloji.com/ http://gudeteknoloji.com/main.dart.js http://gudeteknoloji.com/assets/AssetManifest.bin.json http://gudeteknoloji.com/canvaskit/canvaskit.wasm; do
  curl -s -m 60 -o /dev/null -w "%{http_code} %{size_download}B $u\n" "$u"
done
echo "Geri alma: yedek_canli_site/$STAMP/index.html dosyasını public_html/index.html olarak yeniden yükleyin."
