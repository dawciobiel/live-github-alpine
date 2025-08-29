#!/bin/bash
set -e

echo "Rozpakowywanie ISO Alpine Linux..."

# Tworzenie katalogów roboczych
mkdir -p iso-extract iso-modify

# Montowanie oryginalnego ISO
sudo mount -o loop alpine-original.iso iso-extract

# Kopiowanie zawartości ISO
cp -r iso-extract/* iso-modify/
sudo umount iso-extract

# Rozpakowanie squashfs (główny system plików)
if [ -f "iso-modify/boot/modloop-lts" ]; then
    MODLOOP_FILE="iso-modify/boot/modloop-lts"
elif [ -f "iso-modify/boot/modloop-virt" ]; then
    MODLOOP_FILE="iso-modify/boot/modloop-virt"
else
    MODLOOP_FILE=$(find iso-modify/boot -name "modloop-*" | head -n1)
fi

echo "Rozpakowywanie modloop: $MODLOOP_FILE"
mkdir -p modloop-extract modloop-modify
sudo unsquashfs -d modloop-extract "$MODLOOP_FILE"

# Kopiowanie zawartości modloop
cp -r modloop-extract/* modloop-modify/

# Tworzenie lokalnego repozytorium APK
mkdir -p modloop-modify/var/cache/apk
mkdir -p modloop-modify/etc/apk/keys

# Kopiowanie naszej paczki APK
cp *.apk modloop-modify/var/cache/apk/

# Kopiowanie klucza publicznego
cp signing-key.rsa.pub modloop-modify/etc/apk/keys/

# Generowanie indeksu repozytorium
cd modloop-modify/var/cache/apk
apk index -o APKINDEX.tar.gz *.apk
abuild-sign -k ../../../signing-key.rsa APKINDEX.tar.gz
cd ../../..

# Modyfikacja konfiguracji APK aby wskazywała na lokalne repo
echo "/var/cache/apk" >> modloop-modify/etc/apk/repositories

# Tworzenie skryptu autoinstalacji (opcjonalne)
cat > modloop-modify/etc/local.d/install-my-app.start << 'EOF'
#!/bin/sh
# Autoinstalacja naszej aplikacji przy starcie
apk update
apk add my-app
EOF
chmod +x modloop-modify/etc/local.d/install-my-app.start

# Włączenie local service (Alpine)
if [ ! -d "modloop-modify/etc/runlevels/default" ]; then
    mkdir -p modloop-modify/etc/runlevels/default
fi
ln -sf /etc/init.d/local modloop-modify/etc/runlevels/default/local 2>/dev/null || true

echo "Modyfikacja systemu plików zakończona."
