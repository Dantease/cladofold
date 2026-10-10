#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/PerformanceModuleCache
swiftc -swift-version 5 -O -module-cache-path build/PerformanceModuleCache \
    Sources/Shared/BlurModel.swift Sources/Shared/BlurFilter.swift Tests/Performance/main.swift \
    -o build/renderer-performance
build/renderer-performance "$@"
