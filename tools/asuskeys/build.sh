#!/bin/sh
# Build asuskeysd (event-tap daemon) and asusbl (IOUserClient CLI).
set -e
cd "$(dirname "$0")"

mkdir -p bin
swiftc -O asuskeysd.swift -o bin/asuskeysd
clang -O2 asusbl.c -o bin/asusbl -framework IOKit -framework CoreFoundation

echo "built: $(pwd)/bin/asuskeysd $(pwd)/bin/asusbl"
