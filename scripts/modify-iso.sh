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

# Generowanie indeksu repozytorium (manualne, bez apk index)
cd modloop-modify/var/cache/apk

echo "📦 Tworzenie indeksu repozytorium APK..."

# Funkcja do generowania indeksu z paczek APK
generate_apk_index() {
    local index_file="APKINDEX"
    > "$index_file"
    
    for apk_file in *.apk; do
        [ -f "$apk_file" ] || continue
        
        echo "Processing: $apk_file"
        
        # Wyciągnij metadane z paczki APK
        if tar -tzf "$apk_file" .PKGINFO >/dev/null 2>&1; then
            # Wyciągnij .PKGINFO
            tar -xzf "$apk_file" .PKGINFO
            
            # Konwertuj do formatu APKINDEX
            {
                echo "C:$(sha256sum "$apk_file" | cut -d' ' -f1 | cut -c1-27)="
                grep "^pkgname" .PKGINFO | sed 's/pkgname = /P:/'
                grep "^pkgver" .PKGINFO | sed 's/pkgver = /V:/'
                grep "^arch" .PKGINFO | sed 's/arch = /A:/' 
                grep "^size" .PKGINFO | sed 's/size = /S:/'
                echo "I:$(stat -c%s "$apk_file")"
                grep "^pkgdesc" .PKGINFO | sed 's/pkgdesc = /T:/'
                grep "^url" .PKGINFO | sed 's/url = /U:/'
                grep "^license" .PKGINFO | sed 's/license = /L:/'
                echo "D:"
                echo "p:"
                echo "i:"
                echo ""
            } >> "$index_file"
            
            rm -f .PKGINFO
        else
            echo "⚠️  Nie można wyciągnąć metadanych z $apk_file, używam domyślnych"
            # Fallback - podstawowe metadane
            {
                echo "C:$(sha256sum "$apk_file" | cut -d' ' -f1 | cut -c1-27)="
                echo "P:${apk_file%%-*}"
                echo "V:$(echo "$apk_file" | sed 's/.*-\([0-9][0-9.]*\).*/\1/')-r0"
                echo "A:x86_64"
                echo "S:$(stat -c%s "$apk_file")"
                echo "I:$(stat -c%s "$apk_file")"
                echo "T:Custom Alpine package"
                echo "U:https://github.com/user/repo"
                echo "L:MIT"
                echo "D:"
                echo "p:"
                echo "i:"
                echo ""
            } >> "$index_file"
        fi
    done
}

# Generuj indeks
generate_apk_index

# Kompresja indeksu
tar -czf APKINDEX.tar.gz APKINDEX
rm APKINDEX

# Podpisanie indeksu (jeśli możliwe)
if [ -f "../../../signing-key.rsa" ]; then
    echo "🔐 Podpisywanie indeksu repozytorium..."
    openssl dgst -sha256 -sign ../../../signing-key.rsa APKINDEX.tar.gz > APKINDEX.tar.gz.sig
    echo "✅ Indeks podpisany"
else
    echo "⚠️  Brak klucza, pomijam podpisywanie indeksu"
fi

echo "✅ Indeks repozytorium utworzony:"
ls -la APKINDEX.tar.gz*

cd ../../..

# Modyfikacja konfiguracji APK aby wskazywała na lokalne repo
echo "📝 Konfigurowanie lokalnego repozytorium APK..."

# Dodaj lokalne repo na początku listy (wyższy priorytet)
sed -i '1i /var/cache/apk' modloop-modify/etc/apk/repositories

# Alternatywnie, jeśli plik nie istnieje, utwórz go
if [ ! -f "modloop-modify/etc/apk/repositories" ]; then
    mkdir -p modloop-modify/etc/apk
    cat > modloop-modify/etc/apk/repositories << 'REPOEOF'
/var/cache/apk
https://dl-cdn.alpinelinux.org/alpine/v3.19/main
https://dl-cdn.alpinelinux.org/alpine/v3.19/community
REPOEOF
fi

echo "✅ Konfiguracja repozytorium:"
cat modloop-modify/etc/apk/repositories

# Tworzenie skryptu autoinstalacji (z lepszą obsługą błędów)
cat > modloop-modify/etc/local.d/install-my-app.start << 'EOF'
#!/bin/sh
# Autoinstalacja naszej aplikacji przy starcie

echo "🚀 Instalowanie custom aplikacji..."

# Aktualizacja listy pakietów
apk update || {
    echo "❌ Błąd aktualizacji listy pakietów"
    exit 1
}

# Próba instalacji naszego pakietu
PACKAGE_NAME="$(ls /var/cache/apk/*.apk 2>/dev/null | head -n1 | xargs basename | cut -d'-' -f1)"
if [ -n "$PACKAGE_NAME" ]; then
    echo "📦 Instalowanie: $PACKAGE_NAME"
    apk add "$PACKAGE_NAME" || {
        echo "⚠️  Nie można zainstalować $PACKAGE_NAME z repozytorium, próbuję bezpośrednio..."
        apk add --allow-untrusted /var/cache/apk/*.apk || {
            echo "❌ Instalacja niepowodzenia"
            exit 1
        }
    }
    echo "✅ Instalacja zakończona pomyślnie"
else
    echo "❌ Nie znaleziono pakietu do instalacji"
fi

# Test czy aplikacja działa
if command -v "$PACKAGE_NAME" >/dev/null 2>&1; then
    echo "✅ Aplikacja $PACKAGE_NAME jest dostępna"
    "$PACKAGE_NAME" --version 2>/dev/null || "$PACKAGE_NAME" --help 2>/dev/null || echo "Aplikacja zainstalowana"
else
    echo "⚠️  Aplikacja może nie być w PATH lub ma inną nazwę"
fi
EOF

chmod +x modloop-modify/etc/local.d/install-my-app.start

# Włączenie local service (Alpine)
if [ ! -d "modloop-modify/etc/runlevels/default" ]; then
    mkdir -p modloop-modify/etc/runlevels/default
fi
ln -sf /etc/init.d/local modloop-modify/etc/runlevels/default/local 2>/dev/null || true

echo "Modyfikacja systemu plików zakończona."
