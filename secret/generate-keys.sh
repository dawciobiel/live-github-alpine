#!/bin/bash

# Generowanie pary kluczy
openssl genrsa -out signing-key.rsa 2048
openssl rsa -in signing-key.rsa -pubout -out signing-key.rsa.pub

# Alternatywnie możesz użyć abuild-keygen:
# abuild-keygen -i
