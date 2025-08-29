#!/bin/bash
set -e

# Konfiguracja
PACKAGE_NAME="my-app"
PACKAGE_VERSION="1.0.0"
PACKAGE_DESCRIPTION="Moja aplikacja dla Alpine Linux"
MAINTAINER="Your Name <your.email@example.com>"

# Tworzenie struktury paczki
mkdir -p build-apk/$PACKAGE_NAME
cd build-apk/$PACKAGE_NAME

# Kopiowanie plików aplikacji
cp -r ../../app/* . || echo "Brak katalogu app/, tworzę przykładową strukturę"

# Tworzenie przykładowej struktury jeśli nie istnieje
if [ ! -d "../../app" ]; then
    mkdir -p usr/local/bin
    echo '#!/bin/sh' > usr/local/bin/my-app
    echo 'echo "Hello from my custom Alpine app!"' >> usr/local/bin/my-app
    chmod +x usr/local/bin/my-app
fi

# Tworzenie pliku APKBUILD
cat > APKBUILD << EOF
# Maintainer: $MAINTAINER
pkgname=$PACKAGE_NAME
pkgver=$PACKAGE_VERSION
pkgrel=0
pkgdesc="$PACKAGE_DESCRIPTION"
url="https://github.com/$(echo $GITHUB_REPOSITORY)"
arch="all"
license="MIT"
depends=""
makedepends=""
install=""
subpackages=""
source=""
builddir="\$srcdir"

build() {
    return 0
}

check() {
    return 0
}

package() {
    # Kopiowanie plików do \$pkgdir
    if [ -d "usr" ]; then
        cp -r usr "\$pkgdir/"
    fi

    if [ -d "etc" ]; then
        cp -r etc "\$pkgdir/"
    fi

    if [ -d "var" ]; then
        cp -r var "\$pkgdir/"
    fi

    # Ustawianie uprawnień
    find "\$pkgdir" -type f -name "*.sh" -exec chmod +x {} \;
    find "\$pkgdir/usr/local/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
}
EOF

# Generowanie klucza jeśli nie istnieje (dla lokalnego testowania)
if [ ! -f "../../signing-key.rsa" ]; then
    echo "Brak klucza podpisującego, używam tymczasowego..."
    openssl genrsa -out ../../signing-key.rsa 2048
    openssl rsa -in ../../signing-key.rsa -pubout -out ../../signing-key.rsa.pub
fi

# Konfiguracja abuild
export PACKAGER="$MAINTAINER"
export PACKAGER_PRIVKEY="$(pwd)/../../signing-key.rsa"

# Instalacja publicznego klucza
sudo cp ../../signing-key.rsa.pub /etc/apk/keys/

# Budowanie paczki
abuild-keygen -ai -n
abuild checksum
abuild -r

# Kopiowanie zbudowanej paczki
find ~/packages -name "${PACKAGE_NAME}-*.apk" -exec cp {} ../.. \;

echo "Paczka APK została zbudowana pomyślnie!"
ls -la ../../*.apk
