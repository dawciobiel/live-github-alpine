#!/bin/bash
set -e

# Konfiguracja - automatyczne wykrywanie z GitHub
PACKAGE_NAME="${GITHUB_REPOSITORY##*/}"  # Nazwa z repo GitHub
PACKAGE_VERSION="$(date +%Y.%m.%d)"      # Lub wczytaj z pliku version
PACKAGE_DESCRIPTION="Custom application for Alpine Linux"
MAINTAINER="${GITHUB_ACTOR:-Unknown} <${GITHUB_ACTOR:-unknown}@users.noreply.github.com>"

# Override jeśli istnieją zmienne środowiskowe
PACKAGE_NAME="${CUSTOM_PACKAGE_NAME:-$PACKAGE_NAME}"
PACKAGE_VERSION="${CUSTOM_PACKAGE_VERSION:-$PACKAGE_VERSION}"

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

# Tworzenie metadanych APK
echo "📝 Tworzenie metadanych APK..."

# Plik .PKGINFO (główne metadane)
cat > .PKGINFO << EOF
pkgname = $PACKAGE_NAME
pkgver = $PACKAGE_VERSION-r0
pkgdesc = $PACKAGE_DESCRIPTION
url = https://github.com/$(echo ${GITHUB_REPOSITORY:-"user/repo"})
builddate = $(date -u +%s)
packager = $MAINTAINER
size = $(du -sb . | cut -f1 2>/dev/null || echo "1000")
arch = x86_64
origin = $PACKAGE_NAME
maintainer = $MAINTAINER
license = MIT
EOF

# Lista plików (bez metadanych)
find . -type f ! -name ".PKGINFO" ! -name ".*" | sed 's|^\./||' | sort > .FILELIST

echo "📦 Zawartość paczki:"
cat .FILELIST | head -20  # Pokaż pierwsze 20 plików
[ $(wc -l < .FILELIST) -gt 20 ] && echo "... i $(( $(wc -l < .FILELIST) - 20 )) więcej plików"

# Tworzenie archiwum APK
echo "📦 Tworzenie archiwum APK..."
tar -czf "../${PACKAGE_NAME}-${PACKAGE_VERSION}-r0.apk" --exclude=".FILELIST" .

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
