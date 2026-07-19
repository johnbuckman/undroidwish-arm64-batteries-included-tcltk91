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
# Delete stale build artifacts copied from the source tree.  AndroWish sources
# ship PREBUILT iOS .dylibs -- if the build is interrupted or fails, that stale
# iOS dylib survives and dlopen rejects it ("incompatible platform"); nuke them
# so a "found a .dylib" only ever means OUR fresh macOS build.
find . -name '*.o' -delete -o -name '*.lo' -delete 2>/dev/null
find . -name '*.dylib' -delete 2>/dev/null
rm -f config.cache config.status

# Accept Tcl/Tk 9 in the stubs-init version guards ("8.x" -> "8.5-").
# Recursive over the whole tree -- sources live in generic/, src/, unix/, etc.
# \w+ (not just "interp") for the interp arg -- critcl-generated code uses `ip`;
# \s* tolerates `Tcl_InitStubs (interp, ...)` with a space before the paren.
grep -rlE '(Tcl|Tk)_InitStubs\s*\(\s*\w+\s*,\s*"8\.' . --include='*.c' 2>/dev/null | while read f; do
  perl -i -pe 's/((?:Tcl|Tk)_InitStubs\s*\(\s*\w+\s*,\s*")8\.[0-9]+(")/${1}8.5-${2}/g' "$f"
done

# also catch `..._version = "8.x"` strings used with InitStubs
grep -rlE '_version[^\n]*=[^\n]*"8\.[0-9]' . --include='*.c' 2>/dev/null | while read f; do perl -i -pe 's/(_version\s*=\s*")8\.[0-9]+(")/${1}8.5-${2}/g' "$f"; done

# Tcl_PkgRequire[Ex](ip/interp, "Tcl"/"Tk", "8.x", ...) -> "8.5-" (Tcl 9 rejects a
# bare "8.x" as 8-only; these can be lazy, firing well after load).
grep -rlE 'Tcl_PkgRequire\w*\s*\(\s*\w+\s*,\s*"T[ck]l?k?"\s*,\s*"8\.[0-9]' . --include='*.c' 2>/dev/null | while read f; do perl -i -pe 's/(Tcl_PkgRequire\w*\(\w+, "T[ck]l?k?", ")8\.[0-9]+(")/${1}8.5-${2}/g' "$f"; done

# Tk 9: rewrite string-based Tk_ConfigureWidget calls to the wish shim.
grep -rlE "Tk_ConfigureWidget\(" . --include=*.c 2>/dev/null | while read f; do perl -i -pe "s/\\bTk_ConfigureWidget\\s*\\(/Uw_TkConfigureWidgetStr(/g" "$f"; done

TKARGS=""
if [ "$NEEDTK" = "1" ]; then
  TKARGS="--with-tk=$BLD --with-tkinclude=$HOME/undroidwish91/sdl2tk-9.1/generic"
fi
SDLW="$HOME/undroidwish91/sdl2tk-9.1"
# Tcl 9.1 generic FIRST so its tcl.h wins over any stale /usr/local/include 8.x.
SDLINC="-I$TCL9/generic -I$TCL9/libtommath -I$SDLW/sdl -I$SDLW/xlib -I$SDLW/unix -I$SDLW/generic -I$SDLW/bitmaps -I$SDLW/sdl/agg-2.4/include -I/opt/homebrew/include/freetype2"
COMPAT="-include $BASE/ext-compat91.h"
# -mmacosx-version-min pins the Mach-O platform to macOS; without it some of
# these AndroWish TEA Makefiles (originally iOS-targeted) emit an iOS-platform
# dylib that dlopen rejects ("incompatible platform (have 'iOS', need 'macOS')").
CC="clang" \
CFLAGS="-arch arm64 -mmacosx-version-min=11.0 -O2 -DPLATFORM_SDL $SDLINC $COMPAT -Wno-implicit-int -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-function-pointer-types -Wno-macro-redefined" \
LDFLAGS="-arch arm64 -mmacosx-version-min=11.0 -Wl,-undefined,dynamic_lookup" \
  ./configure --with-tcl="$TCL9/unix" --with-tclinclude="$TCL9/generic" $TKARGS $EXTRA \
  > "$BASE/${NAME}_conf.log" 2>&1
CFG=$?
if [ $CFG -ne 0 ]; then echo "$NAME: CONFIGURE FAILED"; tail -3 "$BASE/${NAME}_conf.log"; exit 1; fi

# Extensions must resolve X drawing calls against the wish's SDL emulation, not
# real libX11 -- strip any -lX11 / X11 lib path the configure detected.
[ -f Makefile ] && perl -i -pe 's/-lX11//g; s{-L/usr/X11R?6?/lib}{}g; s{-L/opt/X11/lib}{}g' Makefile
# TCL_PREFIX=/usr/local injects -I/usr/local/include, whose stale 8.x tcl.h
# would shadow the bundled Tcl 9.1 headers -- drop it (we supply Tcl 9.1
# generic in CFLAGS).
[ -f Makefile ] && perl -i -pe 's{-I/usr/local/include}{}g' Makefile

# Prefer the TEA `binaries` target (libs only) so a broken docs/test target
# (e.g. needs doctools for man pages) doesn't fail the whole build.  Fall back
# to the default target if `binaries` doesn't exist or leaves no dylib.
make -j4 binaries > "$BASE/${NAME}_make.log" 2>&1
if ! ls *.dylib >/dev/null 2>&1; then make -j4 >> "$BASE/${NAME}_make.log" 2>&1; fi
if ! ls *.dylib >/dev/null 2>&1; then
  echo "$NAME: BUILD FAILED"
  grep -iE 'error:|undefined|not found' "$BASE/${NAME}_make.log" | grep -viE 'warning|linker command failed' | head -5
  exit 1
fi
DYL=$(ls *.dylib 2>/dev/null | head -1)
if [ -z "$DYL" ]; then echo "$NAME: no .dylib produced"; exit 1; fi
echo "$NAME: OK -> $DYL ($(lipo -info "$DYL" 2>/dev/null | grep -oE 'arm64|x86_64' | tr '\n' '+'))"
