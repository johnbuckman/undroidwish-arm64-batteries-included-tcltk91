# AGENTS.md — status, build recipe, and resume notes

This document is written for an AI coding agent (or a human) picking up this port.
It states exactly what works, how to build it from scratch, the non-obvious
gotchas discovered along the way, and where to resume.

---

## 1. What this project is

Porting **undroidwish** — AndroWish's SDL2-based, batteries-included `wish` — from
**Tcl/Tk 8.6** to **Tcl/Tk 9.1b0**, built **natively for macOS arm64**.

`sdl2tk` (the thing being ported) is a fork of **Tk 8.6** whose platform layer is
replaced by an **X11-server emulation implemented on SDL2 + Anti-Grain-Geometry**.
Concretely, `sdl2tk/sdl/` is a fork of Tk's `unix/` platform files
(`tkSDLButton.c` ← `tkUnixButton.c`, etc., ~17 files) sitting on top of a ~47k-line
AGG/X11 emulation (`SdlTkX.c`, `SdlTkGfx.c`, `SdlTkAGG.cpp`, `Region.c`, `xlib/`).

Tk 9.x is an ABI break from 8.6, so this is a real port. The good news, established
early: Tk 9.1 kept the **platform contract** (`Tkp*` hooks + the Xlib surface)
essentially stable, and AndroWish's changes to Tk are almost entirely confined to
the platform layer it already forks (`generic/` is only ~50 marker lines patched).
So the port is "re-fork ~17 platform files + reconcile signatures", not a rewrite.

## 2. Current status (proof-of-concept COMPLETE)

Works:
- **Tcl 9.1b0** builds native arm64; **Tk 9.1** + the full `sdl2tk` backend
  (all 30 `.c` + `SdlTkAGG.cpp`) compile clean against Tk 9.1.
- Links into a native arm64 `sdl2wish`.
- Runtime: `package require Tk` → `9.1b0`; `tk windowingsystem` → `x11`; widgets
  (label, button, entry, checkbutton, scale) create and render; the event loop
  runs; clean exit. Fonts discovered (system + bundled DejaVu) and rendered via
  FreeType.
- A window is visibly rendered on screen (Retina) when launched as a `.app` bundle.

Not done (see [TODO.md](TODO.md)):
- The ~60 C extensions ("batteries") are **not** ported to Tcl 9 — the bulk of the
  remaining work.
- No autoconf build, no notarized packaging, no assets/battery bundling.
- In-place source edits are not yet captured as patches.

## 3. Prerequisites / sources (nothing is vendored here)

You need, laid out under a work root (the reference build used `~/tk9-spike/`):

| Component | Source | Notes |
|-----------|--------|-------|
| Tcl 9.1b0 | sourceforge Tcl/9.1b0 | build static → `libtcl9.1.a` |
| Tk 9.1b0  | sourceforge Tcl/9.1b0 | pristine tree; only the platform layer is replaced |
| AndroWish `sdl2tk` | github.com/charwliu/androwish (`jni/sdl2tk`) | provides `sdl/` + `xlib/` backend |
| SDL2 (arm64 static) | AndroWish's SDL2, or Homebrew | `libSDL2.a` + `libSDL2main.a` |
| FreeType | Homebrew `libfreetype.dylib` | |
| AGG 2.4 | inside `sdl2tk/sdl/agg-2.4` | build for arm64 (see below) |
| DejaVu fonts | AndroWish assets `sdl2tk8.6/fonts/*.ttf` | into `$tk_library/fonts/` |

Toolchain: clang (tested clang 21), macOS SDK. Use `PATH=/usr/bin:...` so real
`grep`/`egrep` are used (some setups shadow them with broken x86 Homebrew shims).

## 4. How to build (the direct recipe)

The build uses a **direct script** — no autoconf. Outline (see `build.sh` for the
actual object lists and flags):

1. **Tcl 9.1** — `cd tcl9.1b0/unix && CC=clang CFLAGS="-Wno-implicit-int
   -Wno-implicit-function-declaration -Wno-int-conversion" ./configure
   --disable-shared && make`. Verify: `./tclsh9.1` prints `9.1b0`, `pointerSize=8`.

2. **Work tree** — copy pristine `tk9.1b0` → `sdl2tk-9.1`; graft in AndroWish's
   `sdl/` and `xlib/` (clean out `*.o`/`*.a`); apply the port edits (see
   [TODO.md](TODO.md) §3 for the full list) and drop the three files from
   [`src/`](src/) into `sdl/`.

3. **tkUuid.h** — Tk 9.1 needs a generated `generic/tkUuid.h`; stub it:
   `printf '#define TK_VERSION_UUID \\\n    "sdl2tk-9.1"\n' > generic/tkUuid.h`.

4. **Fonts** — copy the DejaVu `*.ttf` into `sdl2tk-9.1/library/fonts/`.

5. **AGG** — compile `sdl/agg-2.4/{src,font_freetype,agg2d}/*.cpp` for arm64 into
   `libagg.a`. The two `font_freetype/*.cpp` need a tiny fix: cast
   `tags = (char*)(outline.tags) + first;` and `#define stricmp strcasecmp`.

6. **Build + link** — run `build.sh`. It compiles Tk 9.1 `generic/` (GENERIC +
   WIDG + CANV + IMAGE + TEXT + TTK + stubs) with `-DBUILD_tk -DBUILD_ttk
   -DPLATFORM_SDL`, the SDL platform layer + `xcolors` + the compat/stub files
   from `src/`, then links against `libtcl9.1.a`, `libSDL2.a`, `libSDL2main.a`,
   `libagg.a`, FreeType, and the Cocoa/Metal frameworks.

   Only `xcolors.o` is used from `xlib/`; `xdraw/xgc/ximage/xutil` are replaced by
   the emulation. `tkStubLib`/`ttkStubLib` are **not** linked into the wish.

7. **Bundle + run** (REQUIRED on macOS — a bare binary gets no window-server
   connection and renders nothing, logging `CGContextFillRects: invalid context
   0x0`):
   ```sh
   # minimal sdl2wish.app: Contents/MacOS/sdl2wish + Contents/Info.plist
   #   (CFBundleExecutable=sdl2wish, CFBundlePackageType=APPL,
   #    NSHighResolutionCapable, NSPrincipalClass=NSApplication); codesign -f -s -
   launchctl setenv TCL_LIBRARY /path/to/tcl9.1b0/library
   launchctl setenv TK_LIBRARY  /path/to/sdl2tk-9.1/library
   open sdl2wish.app --args yourscript.tcl
   ```

## 5. The port's new source files (in `src/`)

- **`tkSDLCompat91.c`** — bridges Tk 8.6→9.1 platform-hook renames (the SDL layer
  still defines the historical `Tkp*` names; Tk 9.1 generic calls the new `Tk_*` /
  `TkUnix*` names): `Tk_MakeWindow`, `Tk_UseWindow`, `Tk_GetOtherWindow`,
  `Tk_MakeContainer`, `Tk_GetSystemDefault`, `Tk_DrawHighlightBorder`,
  `TkUnixContainerId`, `TkUnixDoOneXEvent`, `TkUnixSetMenubar`,
  `Tk_DrawCharsInContext`, `Tk_MeasureCharsInContext`. Also stubs `TkpSetCapture`,
  `TkpGetCapture`, `TkpWindowIsDark`, and defines the `ttkDefScrollbarWidth` /
  `ttkMinThumbSize` globals.
- **`tkSDLXstubs.c`** — the X Input-Method / XKB / font-set surface Tk 9.1 grew
  (`XOpenIM`, `XCreateFontSet`, `XSetLocaleModifiers`, `XkbKeycodeToKeysym`, …) as
  no-op stubs (SDL2 handles IME/keyboard natively), plus plain-name aliases for
  `XParseColor` / `XPutImage`.
- **`tkSDLlwsStub.c`** — no-op `lws_*` (libwebsockets) and `aom_*` (AV1) stubs. The
  prebuilt AndroWish `libSDL2.a` contains a `wstiles` websocket headless video
  driver pulled in via SDL's static driver table; unused with Cocoa. Drop these if
  SDL2 is rebuilt without `wstiles`.

## 6. Non-obvious gotchas (learned the hard way)

- **Font system was never initialized.** `SdlTkFontInit` (which `Tcl_InitHashTable`s
  the font hashes and discovers fonts) is only called by the `sdltk fonts`/`addfont`
  commands, which a bare wish never runs → Tcl 9's `Tcl_FindHashEntry` dereferenced a
  NULL `findProc` → SIGSEGV. **Fix:** call `SdlTkFontInit(mainPtr->interp)` from
  `TkpFontPkgInit` (the Tk startup hook, `tkSDLFont.c`).
- **`tk_library` not set that early.** `TkpFontPkgInit` runs before Tk sets the
  `tk_library` Tcl var, so the font-discovery `glob` script failed with
  `can't read "tk_library"`. **Fix:** in `SdlTkFontInit`, seed `tk_library` from
  `getenv("TK_LIBRARY")` before the eval.
- **`int` vs `Tcl_Size`.** `Tcl_ListObjGetElements` in Tcl 9 writes a `Tcl_Size`;
  passing `&objc` where `objc` is `int` corrupts the stack. Thread `Tcl_Size`
  through. (This pattern recurs across the extensions.)
- **`X* → SdlTkX*` renames.** `sdl/SdlTkX.h` renames the emulated Xlib functions to
  `SdlTkX*` on macOS. For generic Tk to reach them, `generic/tkInt.h` must
  `#include "SdlTkX.h"` (an AndroWish hook). Some generic files still reference a
  few plain names (`XParseColor`, `XPutImage`) → provide plain aliases (in
  `tkSDLXstubs.c`).
- **Only `xcolors.o` from `xlib/`.** The SDL build replaces `xdraw/xgc/ximage/xutil`
  with the emulation; compiling them causes conflicts (e.g. `#define XSetFunction 0`
  vs a real definition).
- **macOS threading.** SDL/Cocoa must run on the **main thread**; Tk runs on a
  worker thread (`tkAppInit.c` → `Tcl_CreateThread(TkMainThread)`, then `main()`
  runs `SdlTkEventThread()` on the main thread). This is already correct in the
  vendored code — don't "fix" it.
- **`.app` bundle is mandatory** for on-screen rendering (see §4.7).
- **Debugging.** The dummy SDL video driver **hangs** Tk init — use the real Cocoa
  driver. `timeout` is absent on macOS. For crash backtraces, parse
  `~/Library/Logs/DiagnosticReports/sdl2wish*.ips` (JSON), or run lldb with the
  post-crash commands as `-k` (not `-o`):
  `lldb -b -o run -k "register read lr" -k "image lookup -v -a \$lr" -k quit -- ./sdl2wish script.tcl`.

## 7. Where to resume

The next big chunk is **§1 of [TODO.md](TODO.md): porting the ~60 extensions to
Tcl 9.** Start with Img/tkimg, tls, tdom, tkblt. Each is the same class of
mechanical ABI work (`Tcl_Size`, `Tcl_ObjCmdProc2`, removed APIs) already exercised
on the core here. After that: real build integration, patch extraction, and
notarized packaging (§2–4).
