#!/bin/bash
set -e

echo "Tworzenie nowego obrazu ISO..."

# Pakowanie zmodyfikowanego modloop
echo "Pakowanie modloop..."
MODLOOP_NAME=$(basename "$MODLOOP_FILE")
sudo mksquashfs modloop-modify "$MODLOOP_NAME" -comp xz -b 1048576

# Zastąpienie oryginalnego modloop
mv "$MODLOOP_NAME" "iso-modify/boot/"

# Aktualizacja sum kontrolnych
cd iso-modify

# Obliczanie nowych sum MD5 i SHA1
find . -type f -exec md5sum {} \; > md5sums.txt 2>/dev/null || true
find . -type f -exec sha1sum {} \; > sha1sums.txt 2>/dev/null || true

# Powrót do głównego katalogu
cd ..

# Generowanie nazwy dla nowego ISO
CUSTOM_ISO_NAME="custom-alpine-$(date +%Y%m%d_%H%M%S).iso"

# Tworzenie nowego ISO
echo "Tworzenie ISO: $CUSTOM_ISO_NAME"

# Znajdowanie etykiety ISO z oryginalnego obrazu
ISO_LABEL=$(isoinfo -d -i alpine-original.iso | grep "Volume id:" | sed 's/Volume id: //' | tr -d ' ')

if [ -z "$ISO_LABEL" ]; then
    ISO_LABEL="ALPINE_CUSTOM"
fi

# Tworzenie ISO z obsługą UEFI i BIOS
xorriso -as mkisofs \
    -J -R -v -d -N \
    -x ./lost+found \
    -V "$ISO_LABEL" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -partition_offset 16 \
    -b boot/isolinux/isolinux.bin \
    -c boot/isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-apm-hfsplus \
    -o "$CUSTOM_ISO_NAME" \
    iso-modify/

# Sprawdzenie czy ISO zostało utworzone
if [ -f "$CUSTOM_ISO_NAME" ]; then
    echo "✅ Custom ISO utworzone pomyślnie: $CUSTOM_ISO_NAME"
    echo "📏 Rozmiar: $(du -h "$CUSTOM_ISO_NAME" | cut -f1)"

    # Podstawowa weryfikacja
    if file "$CUSTOM_ISO_NAME" | grep -q "ISO 9660"; then
        echo "✅ ISO format jest poprawny"
    else
        echo "⚠️  Ostrzeżenie: Może być problem z formatem ISO"
    fi
else
    echo "❌ Błąd: Nie udało się utworzyć ISO"
    exit 1
fi

# Czyszczenie plików tymczasowych (opcjonalne)
# rm -rf iso-extract iso-modify modloop-extract modloop-modify

echo "Proces zakończony pomyślnie!"
