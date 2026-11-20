#!/bin/zsh
# Build Claude Accounts, assemble the .app bundle, install it, and set it to
# launch at login. Re-run any time after editing the Swift or the web UI
# (the panel and the tool are read live; only a Swift change needs a rebuild).
set -e
REPO="${0:A:h:h}"          # the repo this script sits in
ROOT="$REPO/app"
APP="$HOME/Applications/Claude Accounts.app"
LABEL="com.calhoun.claudeaccountsbar"
AGENT="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

echo "building release…"
cd "$ROOT"
swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/ClaudeAccountsBar"

# The build stamp: the commit, the Swift sources' hash and the build time, written
# into the bundle so a running app can say which code it is:
#   defaults read "$HOME/Applications/Claude Accounts.app/Contents/Info.plist" CCABuildCommit
STAMP_COMMIT="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
[ -n "$(git -C "$REPO" status --porcelain -- app 2>/dev/null)" ] && STAMP_COMMIT="$STAMP_COMMIT+"
STAMP_HASH="$(cat "$ROOT/Package.swift" "$ROOT"/Sources/ClaudeAccountsBar/*.swift | shasum -a 256 | cut -c1-64)"
STAMP_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "build stamp: $STAMP_COMMIT, sources ${STAMP_HASH[1,12]}, $STAMP_AT"

# Stop only this installer's owned launchd label before replacing its bundle.
# A separately launched process is never ended by name or pattern. The bootout
# is asynchronous: wait until launchd has let the job go (at most 10 s).
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
for i in {1..40}; do
  launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 || break
  sleep 0.25
done

echo "assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClaudeAccounts"
chmod +x "$APP/Contents/MacOS/ClaudeAccounts"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Claude Accounts</string>
  <key>CFBundleDisplayName</key><string>Claude Accounts</string>
  <key>CFBundleIdentifier</key><string>$LABEL</string>
  <key>CFBundleExecutable</key><string>ClaudeAccounts</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CCABuildCommit</key><string>$STAMP_COMMIT</string>
  <key>CCABuildAt</key><string>$STAMP_AT</string>
  <key>CCASourceHash</key><string>$STAMP_HASH</string>
  <key>CCAAppRoot</key><string>$REPO</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# ad-hoc codesign so macOS is happy launching it
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "(codesign skipped)"

echo "installing login item: $AGENT"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT" <<AG
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$APP/Contents/MacOS/ClaudeAccounts</string></array>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key><dict><key>CCA_APP_ROOT</key><string>$REPO</string></dict>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
AG

# one retry: a bootstrap racing the bootout's tail fails once with an I/O error
launchctl bootstrap "$DOMAIN" "$AGENT" 2>/dev/null || { sleep 1.5; launchctl bootstrap "$DOMAIN" "$AGENT"; }
echo "done. Claude Accounts is running and will start at login (build $STAMP_COMMIT)."
echo "menu bar: look for the gauge icon near your clock (move mouse to the top edge if Terminal is fullscreen)."
