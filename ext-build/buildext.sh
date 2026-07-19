#!/bin/bash
# buildext.sh <name> <srcdir> <tk:0|1> [extra configure args...]
# Builds an AndroWish/TEA extension as a loadable Tcl 9.1 arm64 .dylib.
export PATH=/usr/bin:/bin:$PATH
set -u
NAME="$1"; SRC="$2"; NEEDTK="$3"; shift 3
EXTRA="$*"
TCL9="$HOME/undroidwish91/tcl9.1b0"
BLD="$HOME/undroidwish91/build"
BASE="$HOME/undroidwish91/ext-build"
D="$BASE/$NAME"

rm -rf "$D"; cp -R "$SRC" "$D"; cd "$D" || exit 2
find . -name '*.o' -delete -o -name '*.lo' -delete 2>/dev/null
rm -f config.cache config.status

# Accept Tcl/Tk 9 in the stubs-init version guards ("8.x" -> "8.5-").
grep -rlE 'Tcl_InitStubs\(interp, "8\.|Tk_InitStubs\(interp, "8\.' generic *.c 2>/dev/null | while read f; do
  perl -i -pe 's/(Tcl_InitStubs\(interp, ")8\.[0-9]+(")/${1}8.5-${2}/g; s/(Tk_InitStubs\(interp, ")8\.[0-9]+(")/${1}8.5-${2}/g' "$f"
done

# also catch `..._version = "8.x"` strings used with InitStubs
grep -rlE '_version[^\n]*=[^\n]*"8\.[0-9]' generic *.c 2>/dev/null | while read f; do perl -i -pe 's/(_version\s*=\s*")8\.[0-9]+(")/${1}8.5-${2}/g' "$f"; done

# Tk 9: rewrite string-based Tk_ConfigureWidget calls to the wish shim.
grep -rlE "Tk_ConfigureWidget\(" generic *.c 2>/dev/null | while read f; do perl -i -pe "s/\\bTk_ConfigureWidget\\s*\\(/Uw_TkConfigureWidgetStr(/g" "$f"; done

TKARGS=""
if [ "$NEEDTK" = "1" ]; then
  TKARGS="--with-tk=$BLD --with-tkinclude=$HOME/undroidwish91/sdl2tk-9.1/generic"
fi
SDLW="$HOME/undroidwish91/sdl2tk-9.1"
SDLINC="-I$SDLW/sdl -I$SDLW/xlib -I$SDLW/unix -I$SDLW/generic -I$SDLW/bitmaps -I$SDLW/sdl/agg-2.4/include -I/opt/homebrew/include/freetype2"
COMPAT="-include $BASE/ext-compat91.h"
CC="clang" \
CFLAGS="-arch arm64 -O2 -DPLATFORM_SDL $SDLINC $COMPAT -Wno-implicit-int -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-function-pointer-types -Wno-macro-redefined" \
LDFLAGS="-arch arm64 -Wl,-undefined,dynamic_lookup" \
  ./configure --with-tcl="$TCL9/unix" --with-tclinclude="$TCL9/generic" $TKARGS $EXTRA \
  > "$BASE/${NAME}_conf.log" 2>&1
CFG=$?
if [ $CFG -ne 0 ]; then echo "$NAME: CONFIGURE FAILED"; tail -3 "$BASE/${NAME}_conf.log"; exit 1; fi

# Extensions must resolve X drawing calls against the wish's SDL emulation, not
# real libX11 -- strip any -lX11 / X11 lib path the configure detected.
[ -f Makefile ] && perl -i -pe 's/-lX11//g; s{-L/usr/X11R?6?/lib}{}g; s{-L/opt/X11/lib}{}g' Makefile

make -j4 > "$BASE/${NAME}_make.log" 2>&1
if [ $? -ne 0 ]; then
  echo "$NAME: BUILD FAILED"
  grep -iE 'error:|undefined|not found' "$BASE/${NAME}_make.log" | grep -viE 'warning|linker command failed' | head -5
  exit 1
fi
DYL=$(ls *.dylib 2>/dev/null | head -1)
if [ -z "$DYL" ]; then echo "$NAME: no .dylib produced"; exit 1; fi
echo "$NAME: OK -> $DYL ($(lipo -info "$DYL" 2>/dev/null | grep -oE 'arm64|x86_64' | tr '\n' '+'))"
