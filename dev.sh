#!/bin/bash
# dev.sh - MacOS development script for RustDesk with Flutter hot-reload

# Make sure we fail if any steps fail
set -e

# Setup necessary environment variables for Apple Silicon & CocoaPods
export LANG=en_US.UTF-8
export PATH=/opt/homebrew/bin:$PATH

# Automatically resolve VCPKG_ROOT relative to the script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export VCPKG_ROOT="$DIR/vcpkg"

echo "=== Compiling Rust Base Library (Release Mode) ==="
# Xcode project explicitly links against target/release/liblibrustdesk.dylib
# even when Flutter is running in debug mode
cargo build --features flutter --release

echo "=== Starting Flutter with Hot-Reload ==="
cd flutter
flutter run -d macos
