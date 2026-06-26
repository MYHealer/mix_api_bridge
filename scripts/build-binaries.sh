#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ARGS=()

if [ -n "${MIX_RUST_TARGET:-}" ]; then
  rustup target add "$MIX_RUST_TARGET"
  TARGET_ARGS=(--target "$MIX_RUST_TARGET")
fi

if [ -n "${MIX_OUT_DIR:-}" ]; then
  OUT_DIR="$MIX_OUT_DIR"
elif [ -n "${MIX_RUST_TARGET:-}" ]; then
  OUT_DIR="$ROOT/target-local/binaries/$MIX_RUST_TARGET"
else
  OUT_DIR="$ROOT/target-local/binaries"
fi

mkdir -p "$OUT_DIR"
cd "$ROOT"
pnpm build

cd "$ROOT/src-tauri"
if [ "${#TARGET_ARGS[@]}" -gt 0 ]; then
  cargo build --release "${TARGET_ARGS[@]}" --bin mix_api_bridge
  cargo build --release "${TARGET_ARGS[@]}" --features desktop --bin mix_api_bridge_desktop
else
  cargo build --release --bin mix_api_bridge
  cargo build --release --features desktop --bin mix_api_bridge_desktop
fi

target_dir="$ROOT/src-tauri/target"
if [ -n "${MIX_RUST_TARGET:-}" ]; then
  target_dir="$target_dir/$MIX_RUST_TARGET"
fi
target_dir="$target_dir/release"

server_name="mix_api_bridge"
desktop_name="mix_api_bridge_desktop"
if [[ "${MIX_RUST_TARGET:-}" == *windows* ]]; then
  server_name="$server_name.exe"
  desktop_name="$desktop_name.exe"
fi

cp -f "$target_dir/$server_name" "$OUT_DIR/"
cp -f "$target_dir/$desktop_name" "$OUT_DIR/"

if [[ "$(uname -s)" == "Darwin" && -z "${MIX_RUST_TARGET:-}" ]]; then
  app_dir="$OUT_DIR/mix_api_bridge_desktop.app"
  rm -rf "$app_dir"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp -f "$target_dir/$desktop_name" "$app_dir/Contents/MacOS/mix_api_bridge_desktop"
  chmod +x "$app_dir/Contents/MacOS/mix_api_bridge_desktop"
  if [ -f "$ROOT/src-tauri/icons/icon.icns" ]; then
    cp -f "$ROOT/src-tauri/icons/icon.icns" "$app_dir/Contents/Resources/icon.icns"
  fi
  cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>mix_api_bridge</string>
  <key>CFBundleExecutable</key>
  <string>mix_api_bridge_desktop</string>
  <key>CFBundleIconFile</key>
  <string>icon.icns</string>
  <key>CFBundleIdentifier</key>
  <string>com.neoruaa.mix-api-bridge.desktop</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>mix_api_bridge</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST
fi

echo "Binary output: $OUT_DIR"
