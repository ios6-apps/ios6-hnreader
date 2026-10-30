#!/bin/bash
# Builds and runs the native macOS tests. Needs Xcode's command line tools only.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun clang -fobjc-arc -Wno-deprecated-declarations -Wno-arc-retain-cycles -Isrc \
    tests/test_reader.m src/HNReaderMode.m \
    -framework Foundation -o build/tests/test_reader
build/tests/test_reader
