#!/bin/bash
# Rebuild the XCFramework. Requires gomobile (go install golang.org/x/mobile/cmd/gomobile@latest).
#
# -target must list all three explicitly: a bare -target=ios yields ONLY ios/arm64,
# with no simulator and no macOS slice.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/go/bin:$PATH"
export GOTOOLCHAIN=go1.25.12
gomobile bind -target=ios,iossimulator,macos \
  -o ../Frameworks/SpaceNotesPGP.xcframework \
  -ldflags="-s -w" \
  ./pgpmobile
