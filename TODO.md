# TODO — undroidwish-arm64 on Tcl/Tk 9.1

Ordered roughly by priority. The core `undroidwish91` (Tcl 9.1 + Tk 9.1 on SDL2, native
arm64) already builds and renders a window; everything below is what stands between
that proof-of-concept and a shippable, batteries-included build.

## 1. Port the extensions ("batteries") to Tcl 9 — the long pole

The ~60 bundled C extensions have **not** been touched yet. Each must be recompiled
against the Tcl 9 stubs, and many will need source patches for the Tcl 9 ABI:

- `Tcl_Size` / TIP 494 (objc, lengths, indices → `Tcl_Size`, not `int`)
- `Tcl_ObjCmdProc2` where command procs take `Tcl_Size objc`
- removed deprecated APIs (`Tcl_SaveResult`, `_ANSI_ARGS_`, `CONST86`, …)
- channel driver version 5, `Tk_PhotoPutBlock` signature, etc.

High-value / likely-needed first: **Img/tkimg**, **tls**, **tdom**, **tkblt/BLT**,
**Memchan**, **tclvfs/zipfs**. Expect a tail of old/unmaintained extensions
(Mpexpr, augeas, kafkatcl, tclxml, …) that may need real patching or dropping.

Track per-extension status in a table here as they are done.

## 2. Real build system

The current build is a **direct script** (`build.sh`, no autoconf). For a
maintainable build:

- Port AndroWish's `sdl2tk/sdl/configure.in` + `Makefile.in` from the 8.6 TEA
  macros to the Tk 9.1 ones, OR keep/clean up the direct script as the supported
  path.
- Integrate into the existing `build-uw-arm64` recipe (the 8.6 flow) so batteries,
  assets, and the `ebuild` single-file packaging all work.

## 3. Turn the compat shims into proper, reviewable patches

The port currently edits vendored files in place plus adds three new source files.
Convert the in-place edits into unified diffs under [`patches/`](patches/) (as the
8.6 recipe repo does) so a clean `apply-patches.sh` reproduces the tree from
pristine `tk9.1b0` + AndroWish `sdl2tk`. Key edits to capture:

- `generic/tkInt.h` — `#include "SdlTkX.h"` (routes generic Tk's X calls to the
  emulation) under `PLATFORM_SDL`.
- `generic/tk.h` — `PointerUpdate` event + `XUpdatePointerEvent` struct;
  `TK_APP_TOP_LEVEL` flag (both `PLATFORM_SDL`).
- `generic/tkPort.h` — `PLATFORM_SDL → tkSDLPort.h` branch.
- `xlib/X11/Xlib.h` — compat block for Xlib funcs Tk 9.1 dropped from its X stubs
  (`XEventsQueued`, `XOpenDisplay`, `XKeycodeToKeysym`, `XLoadQueryFont`, …),
  `XIDProc` typedef, `XGetFTStream` alias.
- ~62 emulated Xlib functions changed `void → int` to match Tk 9.1's
  `tkIntXlibDecls.h` (in `SdlTkX.h` decls + the definitions).
- Command-proc / font signatures → `Tcl_ObjCmdProc2` / `Tcl_Size`
  (`Tk_WmObjCmd`, `Tk_SendObjCmd`, `Tk_MeasureChars`, `Tk_DrawChars`,
  `TkpDrawAngledCharsInContext`, `TkpTestsendCmd`, `TkpTestembedCmd`, …).
- `int → bool` returns (`TkpWmSetState`, `TkpCmapStressed`, `TkScrollWindow`).
- `TkSelUpdateClipboard` rewritten to the new `(TkWindow*, clipboardOption)` model.
- `tkSDLFont.c` — bootstrap `SdlTkFontInit` from `TkpFontPkgInit`.
- `SdlTkUtils.c` — seed `tk_library` from `$TK_LIBRARY` before font discovery;
  `int objc → Tcl_Size objc` in `SdlTkFontInit`.
- Widget files (`tkSDLButton/Scale/Scrlbr/Menu/Menubu`) re-adopted from Tk 9.1's
  `unix/` origins (the `int → Tcl_Obj*` config-option migration).
- `tkAppInit.c` — `UwFindLibraries()`: auto-discover the Tcl/Tk 9.1 script
  libraries (relative to the executable + common install locations) so
  `TCL_LIBRARY`/`TK_LIBRARY` need not be set.

## 4. Packaging

- Ship as a notarized `.app` bundle + DMG (as the 8.6 repo does; a bundle is
  **required** on macOS for a window-server connection — a bare terminal binary
  shows no window and logs `CGContext 0x0`).
- Add the batteries + assets (fonts, demos, `main.tcl` boot hook, `Borg`, etc.).

## 5. Polish

- Restore the touch-friendly ttk scrollbar sizing (`ttkDefScrollbarWidth` /
  `ttkMinThumbSize`). Tk 9.1 restructured `ttkDefaultTheme.c` to `Tcl_Obj`-based
  sizing; the two globals are currently defined but unread. Re-wire them.
- Provide real bodies for the native-bitmap hooks
  (`TkpCreateNativeBitmap` / `TkpDefineNativeBitmaps` / `TkpGetNativeAppBitmap`),
  currently minimal stubs.
- Remove the temporary libaom/libwebsockets stubs once SDL2 is rebuilt without the
  `wstiles` headless video driver (or link the real libs if that driver is wanted).

## 6. Testing

- Run the Tcl and Tk regression suites against the 9.1 build (as the 8.6 native
  arm64 build did — Tcl suite passed there).
- Validate a real app (de1app / Insight) once the batteries are ported.
