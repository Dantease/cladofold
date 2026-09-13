#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache
swiftc -swift-version 5 -module-cache-path build/ModuleCache Sources/Shared/BlurModel.swift Tests/main.swift -o build/behavior-tests
build/behavior-tests
swiftc -swift-version 5 -module-cache-path build/ModuleCache Sources/Shared/BlurModel.swift Sources/Shared/BlurFilter.swift Tests/Rendering/main.swift -o build/render-tests
build/render-tests

swiftc -swift-version 5 -module-cache-path build/ModuleCache Sources/App/PaneInstaller.swift Tests/Installation/main.swift -o build/installation-tests
build/installation-tests build/installation-tests-data
