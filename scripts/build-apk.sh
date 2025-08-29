#!/bin/bash
set -e

# Konfiguracja
PACKAGE_NAME="hardclone-cli"
PACKAGE_VERSION="2.1.4"
PACKAGE_DESCRIPTION="Interactive partition backup creator with encryption, compression, and file splitting for Linux"
MAINTAINER="Dawid Bielecki<dawciobiel@gmail.com>"

echo "🔨 Budowanie paczki APK: ${PACKAGE_NAME}-${PACKAGE_VERSION}"

# Tworzenie struktury paczki
mkdir -p build-apk/${PACKAGE_NAME}
cd build-apk/${PACKAGE_NAME}

# Kopiowanie plików aplikacji
if [ -d "../../app" ]; then
    echo "📁 Kopiowanie plików z katalogu app/"
    cp -r ../../app/* . 2>/dev/null || echo "Katalog app/ jest pusty"
else
    echo "📁 Brak katalogu app/, tworzę przykładową strukturę"
    mkdir -p usr/local/bin
    cat > usr/local/bin/my-app << 'EOF'
#!/bin/sh
echo "Hello from my custom Alpine app!"
echo "Version: 1.0.0"
echo "Installed successfully!"
EOF
    chmod +x usr/local/bin/my-app
fi

# Tworzenie struktury metadanych APK
mkdir -p .PKGINFO
cat > .PKGINFO << EOF
pkgname = $PACKAGE_NAME
pkgver = $PACKAGE_VERSION-r0
pkgdesc = $PACKAGE_DESCRIPTION
url = https://github.com/$(echo ${GITHUB_REPOSITORY:-"user/repo"})
builddate = $(date -u +%s)
packager = $MAINTAINER
size = $(du -sb . | cut -f1)
arch = x86_64
origin = $PACKAGE_NAME
maintainer = $MAINTAINER
license = MIT
EOF

# Tworzenie listy plików
find . -type f ! -path "./.PKGINFO" ! -name ".*" | sed 's|^\./||' | sort > .PKGINFO/FILES

echo "📦 Zawartość paczki:"
cat .PKGINFO/FILES

# Tworzenie archiwum tar
echo "📦 Tworzenie archiwum APK..."
tar -czf "../${PACKAGE_NAME}-${PACKAGE_VERSION}-r0.apk" .

# Podpisywanie paczki (jeśli klucz istnieje)
if [ -f "../../signing-key.rsa" ]; then
    echo "🔐 Podpisywanie paczki..."
    cd ..
    
    # Tworzenie podpisu
    openssl dgst -sha256 -sign ../signing-key.rsa \
        "${PACKAGE_NAME}-${PACKAGE_VERSION}-r0.apk" > \
        "${PACKAGE_NAME}-${PACKAGE_VERSION}-r0.apk.sig"
    
    # Weryfikacja podpisu (opcjonalne)
    if openssl dgst -sha256 -verify ../signing-key.rsa.pub \
        -signature "${PACKAGE_NAME}-${PACKAGE_VERSION}-r0.apk.sig" \
        "${PACKAGE_NAME}-${PACKAGE_VERSION}-r0.apk"; then
        echo "✅ Podpis zweryfikowany pomyślnie"
    else
        echo "⚠️  Ostrzeżenie: Nie można zweryfikować podpisu"
    fi
    
    cd ..
else
    echo "⚠️  Brak klucza podpisującego, pomijam podpisywanie"
    cd ..
fi

# Kopiowanie zbudowanej paczki do głównego katalogu
cp build-apk/${PACKAGE_NAME}-*.apk . 2>/dev/null || true

echo "✅ Paczka APK została zbudowana pomyślnie!"
echo "📋 Pliki:"
ls -la *.apk
