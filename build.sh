#!/bin/bash
# Direct build of a bare sdl2wish 9.1 (spike) — no autoconf.
export PATH=/usr/bin:/bin:$PATH
set -u
W=~/tk9-spike/sdl2tk-9.1
TCL9=~/tk9-spike/tcl9.1b0
SDL2=~/iwish/build-uw-arm64/SDL2/include
B=~/tk9-spike/build
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

echo "== link sdl2wish =="
clang++ -o "$B/sdl2wish" \
  "$B"/*.o \
  "$TCL9/unix/libtcl9.1.a" \
  ~/iwish/build-uw-arm64/SDL2/build/.libs/libSDL2.a \
  ~/iwish/build-uw-arm64/SDL2/build/.libs/libSDL2main.a \
  ~/tk9-spike/build/libagg.a \
  /opt/homebrew/lib/libfreetype.dylib \
  -lz -lpthread \
  -framework Cocoa -framework IOKit -framework CoreVideo -framework CoreAudio \
  -framework AudioToolbox -framework CoreFoundation -framework Carbon \
  -framework ForceFeedback -framework Metal -framework GameController \
  -framework CoreHaptics -framework CoreGraphics -liconv \
  2>"$B/link.log"
if [ $? -eq 0 ]; then echo "LINK OK -> $B/sdl2wish"; file "$B/sdl2wish" | sed 's/,.*//';
else echo "=== LINK ERRORS ==="; grep -iE 'undefined|error|symbol' "$B/link.log" | head -40; fi
