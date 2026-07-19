# Building Img (tkimg 1.4.11) for Tcl/Tk 9.1 arm64

tkimg is a coordinated ~24-package tree built through ONE top-level TEA
configure that recurses into every sub-package (zlib → libpng/libjpeg/libtiff
→ base → per-format handlers). Build it in-tree, not per-package.

## Recipe

1. Copy the whole `jni/tkimg` tree to a work dir.
2. **Sweep every `.c` (all depths) for the version guards** — Tcl 9 rejects a
   bare `"8.x"`:
   - `Tcl_InitStubs(interp, "8.5"` / `Tk_InitStubs(interp, "8.5"` → `"8.5-"`.
   - Do it in the sweep even for the per-handler `init.c` files: each format
     handler's real object is `png.c` etc., which does `#include "init.c"`
     (`CLEANFILES = init.c`, but there is no regeneration rule — it is a
     checked-in include). Patch the `init.c`s AND force a full `.o` clean so
     `png.c` actually recompiles with the patched include (cleaning only
     `init.o` does nothing — the handlers have no `init.o`).
3. Configure top-level with the SDL Tk 9.1 build:
   `CC=clang CFLAGS="-arch arm64 -O2 -DPLATFORM_SDL <Tcl9/generic + SDL includes>
    -include ext-compat91.h <-Wno-...>" LDFLAGS="-arch arm64 -Wl,-undefined,dynamic_lookup"
    ./configure --with-tcl=<Tcl9>/unix --with-tclinclude=<Tcl9>/generic
    --with-tk=<sdl2tkstub build> --with-tkinclude=<sdl2tk-9.1>/generic`
4. `make` → produces all 24 `*.dylib` (zlibtcl, pngtcl, jpegtcl, tifftcl,
   libtkimg + libtkimg<fmt> handlers).
5. Assemble one `Img1.4.11/` battery dir: all dylibs + the Tcl support files,
   and a pkgIndex that is the CONCATENATION of every sub-package's GENERATED
   `pkgIndex.tcl` (versions differ from the old 8.6 asset — e.g. jpegtcl is
   9.2 here, not 8.0 — so the asset pkgIndex will not match; use the generated
   ones).

## Status

- `package require Img` loads the full meta-package (all handlers). ✅
- Reading works: verified PNG (576x384) and GIF decode into photos. ✅
- imgdemo runs. ✅
- **Known issue:** PNG *write* (`$photo write x.png -format png`) SIGSEGVs
  *inside libpng* (`png_write_info_before_PLTE`, addr 0xb0000000) — a libpngtcl
  internal issue, not a tkimg Tcl_Size bug. Read path is unaffected. TODO.
