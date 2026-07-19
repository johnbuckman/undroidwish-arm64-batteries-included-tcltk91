#!/bin/bash
# Direct build of a undroidwish91 (Tcl/Tk 9.1) — no autoconf.
export PATH=/usr/bin:/bin:$PATH
set -u
W=~/undroidwish91/sdl2tk-9.1
TCL9=~/undroidwish91/tcl9.1b0
SDL2=~/iwish/build-uw-arm64/SDL2/include
B=~/undroidwish91/build
mkdir -p "$B"

INC="-I$W/xlib -I$W/sdl -I$W/generic -I$W/generic/ttk -I$W/unix -I$W/bitmaps \
-I$W/sdl/agg-2.4/include -I$W/sdl/agg-2.4/font_freetype -I$W/sdl/agg-2.4/agg2d \
-I$TCL9/generic -I$TCL9/unix -I$SDL2 -I/opt/homebrew/include/freetype2"
DEFS="-DBUILD_tk -DBUILD_ttk -DPLATFORM_SDL -DSTATIC_BUILD=1 -DHAVE_INTPTR_T=1 -DHAVE_UINTPTR_T=1"
FLAGS="-O1 -fPIC -Wno-implicit-int -Wno-implicit-function-declaration \
-Wno-int-conversion -Wno-incompatible-function-pointer-types -Wno-deprecated-declarations \
-Wno-unused -Wno-parentheses -Wno-return-type"

objlist() { awk "/^$1 =/{p=1} p{print} p&&!/\\\\\$/{exit}" "$W/unix/Makefile.in" | grep -oE '[A-Za-z0-9]+\.o' | sed 's/\.o//'; }

GEN=$(objlist GENERIC_OBJS)
WIDG=$(objlist WIDG_OBJS)
CANV=$(objlist CANV_OBJS)
IMG=$(objlist IMAGE_OBJS)
TEXT=$(objlist TEXT_OBJS)
TTK=$(objlist TTK_OBJS)
SDLO="tkSDL tkSDL3d tkSDLButton tkSDLColor tkSDLConfig tkSDLCursor tkSDLDraw tkSDLEmbed \
tkSDLEvent tkSDLFocus tkSDLFont tkSDLInit tkSDLKey tkSDLMenu tkSDLMenubu tkSDLScale \
tkSDLScrlbr tkSDLSelect tkSDLSend tkSDLWm tkSDLXId \
SdlTkDecframe SdlTkGfx SdlTkInt SdlTkUtils SdlTkX Region PolyReg tkSDLCompat91 tkSDLXstubs tkSDLlwsStub"
GENX="tkPointer tkImgUtil"   # in generic/, listed in SDL_OBJS
XLIB="xcolors"   # SDL build replaces xdraw/xgc/ximage/xutil with SdlTkX/SdlTkGfx emulation
STUBS="tkStubInit"
TTKSTUB=""

fail=0
cc_one() { # dir base
  local src="$1/$2.c" out="$B/$2.o"
  [ -f "$src" ] || { echo "MISSING $src"; return 1; }
  if ! clang -c $FLAGS $DEFS $INC "$src" -o "$out" 2>"$B/$2.log"; then
    echo "FAIL cc $2"; grep -m2 'error:' "$B/$2.log" | sed -E 's|^/[^ ]+/||'; fail=1; return 1
  fi
}

echo "== generic core / widgets / canvas / image / text =="
for f in $GEN $WIDG $CANV $IMG $TEXT $STUBS $GENX; do cc_one "$W/generic" "$f"; done
echo "== ttk =="
for f in $TTK $TTKSTUB; do cc_one "$W/generic/ttk" "$f"; done
echo "== sdl platform + xlib =="
for f in $SDLO; do cc_one "$W/sdl" "$f"; done
for f in $XLIB; do cc_one "$W/xlib" "$f"; done
echo "== AGG (c++) =="
if ! clang++ -c $FLAGS $DEFS $INC "$W/sdl/SdlTkAGG.cpp" -o "$B/SdlTkAGG.o" 2>"$B/SdlTkAGG.log"; then
  echo "FAIL cc SdlTkAGG"; grep -m3 'error:' "$B/SdlTkAGG.log" | sed -E 's|^/[^ ]+/||'; fail=1
fi
echo "== wish main =="
cc_one "$W/sdl" "tkAppInit"

if [ $fail -ne 0 ]; then echo "=== COMPILE FAILURES, stopping before link ==="; exit 1; fi

echo "== archive libsdl2tk9.1.a =="
ar cr "$B/libsdl2tk9.1.a" "$B"/*.o 2>/dev/null
# (wish links directly against the .o set below)

echo "== link undroidwish91 =="
clang++ -o "$B/undroidwish91" \
  "$B"/*.o \
  "$TCL9/unix/libtcl9.1.a" \
  ~/iwish/build-uw-arm64/SDL2/build/.libs/libSDL2.a \
  ~/iwish/build-uw-arm64/SDL2/build/.libs/libSDL2main.a \
  ~/undroidwish91/build/libagg.a \
  /opt/homebrew/lib/libfreetype.dylib \
  -lz -lpthread \
  -framework Cocoa -framework IOKit -framework CoreVideo -framework CoreAudio \
  -framework AudioToolbox -framework CoreFoundation -framework Carbon \
  -framework ForceFeedback -framework Metal -framework GameController \
  -framework CoreHaptics -framework CoreGraphics -liconv \
  2>"$B/link.log"
if [ $? -ne 0 ]; then
  echo "=== LINK ERRORS ==="; grep -iE 'undefined|error|symbol' "$B/link.log" | head -40; exit 1
fi
echo "LINK OK -> $B/undroidwish91"; file "$B/undroidwish91" | sed 's/,.*//'

# ---------------------------------------------------------------------------
# Package a self-contained undroidwish91.app.  The Tcl/Tk 9.1 script libraries
# are placed under Contents/Resources so the binary finds them relative to
# itself (see UwFindLibraries() in tkAppInit.c) -- no TCL_LIBRARY / TK_LIBRARY
# needed.  On macOS a .app bundle is also required for a window-server
# connection (a bare terminal binary renders nothing).
# ---------------------------------------------------------------------------
echo "== package undroidwish91.app =="
APP="$HOME/undroidwish91/undroidwish91.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$B/undroidwish91"          "$APP/Contents/MacOS/undroidwish91"
cp -R "$TCL9/library"          "$APP/Contents/Resources/tcl9.1"
cp -R "$W/library"             "$APP/Contents/Resources/tk9.1"   # includes fonts/
# boot script sourced on a bare launch (console + Demos menu + placement)
[ -f "$HOME/undroidwish91/main.tcl" ] && cp "$HOME/undroidwish91/main.tcl" "$APP/Contents/Resources/main.tcl"
# app icon (the undroidwish icon)
[ -f "$HOME/undroidwish91/undroidwish91.icns" ] && cp "$HOME/undroidwish91/undroidwish91.icns" "$APP/Contents/Resources/undroidwish91.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>undroidwish91</string>
  <key>CFBundleIdentifier</key><string>org.tcltk.undroidwish91</string>
  <key>CFBundleName</key><string>undroidwish91</string>
  <key>CFBundleIconFile</key><string>undroidwish91.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>9.1</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST
codesign -f -s - "$APP" >/dev/null 2>&1
echo "APP -> $APP"
echo "Run:  open $APP --args yourscript.tcl        (no env vars needed)"
