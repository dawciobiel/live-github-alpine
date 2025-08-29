#!/bin/bash

# Tworzenie katalogów
mkdir -p .github/workflows
mkdir -p scripts
mkdir -p app/usr/local/bin
mkdir -p app/etc/hardclone/cli
mkdir -p config

# Tworzenie plików (pustych lub z domyślną zawartością)
touch .github/workflows/build-alpine-iso.yml

touch scripts/build-apk.sh
touch scripts/modify-iso.sh
touch scripts/create-iso.sh
chmod +x scripts/*.sh  

touch app/usr/local/bin/hardclone-cli
chmod +x app/usr/local/bin/hardclone-cli

touch app/etc/hardclone/cli/config.conf

touch config/alpine-config.env

touch README.md

