#!/usr/bin/env bash
# Birden fazla ajan aynı projede flutter/dart komutu çalıştırdığında Windows dosya kilitleri
# çakışmasın diye komutları sıraya sokar.  Kullanım: tool/flt.sh flutter analyze   |  tool/flt.sh flutter test test/x_test.dart
LOCK="${TEMP:-/tmp}/gudeteknolojiweb_flt.lock"
waited=0
while ! mkdir "$LOCK" 2>/dev/null; do
  # 15 dakikadan eski kilit artık kalmıştır: temizle
  if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +15 2>/dev/null)" ]; then rmdir "$LOCK" 2>/dev/null; continue; fi
  sleep 2; waited=$((waited+2))
  if [ $waited -ge 900 ]; then echo "flt.sh: kilit alınamadı (15 dk)"; exit 99; fi
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM
cd "$(dirname "$0")/.." && "$@"
