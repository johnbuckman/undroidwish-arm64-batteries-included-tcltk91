# AGENTS.md — status, build recipe, and resume notes

> **Resuming cold?** Read [`BOOTSTRAP.md`](BOOTSTRAP.md) first — it maps the
> machine layout, the rebuild + headless-verification recipes, and the open work.

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

## 2. Current status — ALL 17 DEMOS WORKING, batteries substantially ported

Core (done):
- **Tcl 9.1b0** builds native arm64; **Tk 9.1** + the full `sdl2tk` backend
  (all 30 `.c` + `SdlTkAGG.cpp`) compile clean against Tk 9.1.
- Links into a native arm64 `undroidwish91`; runs as a self-contained `.app`
  (a bundle is **required** on macOS for a window-server connection).
- Bare launch reproduces undroidwish: console + Tk window + **Demos ▸** menu,
  bundled icon, and auto-discovery of the Tcl/Tk 9.1 script libraries (no
  `TCL_LIBRARY`/`TK_LIBRARY` needed).

**Demos: 17 of 17 enabled and working** (was 1): widget, tkcon, tkinspect,
notebook, tksqlite, stardom, tktable, treectrl, tkchat, zint, imgdemo,
borgdemo, bledemo, helpviewer, zinc-widget, tkpdemo, vncviewer.

**C-extension stacks ported for the demos (13):** sqlite3 3.50.4, tdom 0.9.3,
Tktable 2.11, treectrl 2.4.2, tls 1.7.22, itcl 4.3.8 + itk 4.1.0 (+iwidgets),
borg 1.0, zint 2.13.0, tkhtml 3.0, **Img/tkimg 1.4.11 (24 dylibs)**,
Tkzinc 3.3.6, tkpath 0.3.3, tkvnc 0.5.

**Non-demo batteries ported (8):** parse_args 0.5.1, pikchr 1.0, parser 1.8,
tksvg 0.14, tclcsv 2.3, vfs 1.4.2, udp 1.0.11, Memchan 2.4.

Caveats / known issues:
- **Not self-contained:** tls links Homebrew openssl@3; tkpath links Homebrew
  cairo (same trade-off as the 8.6 build's Homebrew-dependent extensions).
- **PNG *write*** SIGSEGVs inside libpng (`png_write_info_before_PLTE`); the
  read path (what imgdemo uses) is fine. See `ext-build/BUILD-Img.md`.
- **Bluetooth requires `NSBluetoothAlwaysUsageDescription`** in the app's
  Info.plist (build.sh emits it) — without it macOS silently denies
  CoreBluetooth. Test BLE only via a `.app` launch (`open -n app --args x.tcl`);
  the bare binary has no app-bundle TCC identity and is always denied.

Not done (see [TODO.md](TODO.md)):
- ~40 remaining non-demo batteries — an individual-fix tail; see
  `ext-build/NON-DEMO-BATTERIES.md` for the status and Tcl-9 failure taxonomy.
- No autoconf build; no notarized packaging/DMG.
- In-place SDL-backend edits still aren't captured as patches (the extension
  fixes are, under `ext-build/patches/`).

## 2a. Where the porting knowledge lives

| Doc | Covers |
|-----|--------|
| [`PORTING-TCL-DEMOS.md`](PORTING-TCL-DEMOS.md) | Recurring **pure-Tcl** Tcl-9 fixes: version guards (`8.x`→`8.x-`, incl. `vsatisfies`), removed `tk::unsupported::ExposePrivateCommand`, namespace-scoped global array reads, UTF-8 default source encoding, missing tklib |
| [`ext-build/BUILD-Img.md`](ext-build/BUILD-Img.md) | The coordinated 24-package tkimg build + its gotchas |
| [`ext-build/NON-DEMO-BATTERIES.md`](ext-build/NON-DEMO-BATTERIES.md) | Non-demo battery status + the **Tcl-9 failure taxonomy** |
| [`ext-build/buildext.sh`](ext-build/buildext.sh) | The extension build workhorse (see §4a) |
| [`ext-build/patches/`](ext-build/patches/) | Per-extension Tcl-9 diffs (tls channel, itk Tcl_Size, zint, tkhtml, tkzinc, tkpath, tcludp, memchan) |

## 4a. Building an extension (`ext-build/buildext.sh <name> <src> <0|1 tk>`)

It clean-copies the source and handles the traps that bite nearly every
AndroWish extension under Tcl 9:

- deletes stale **prebuilt iOS `.dylib`s** shipped in the sources (else a failed
  build leaves one and dlopen says "incompatible platform");
- `-mmacosx-version-min=11.0` pins the Mach-O platform to macOS;
- rewrites version guards `"8.x"` → `"8.5-"` **recursively** (`src/`,
  `generated/`, not just `generic/`), for any interp arg name (critcl emits
  `ip`), tolerating whitespace (`Tcl_InitStubs (interp, …)`), and for
  `Tcl_PkgRequire`/`…Ex` as well as `*_InitStubs`;
- rewrites string-based `Tk_ConfigureWidget(` → the wish's
  `Uw_TkConfigureWidgetStr` shim (Tk 9 made it object-based);
- puts Tcl 9.1 `generic` + `libtommath` first in the include path and strips
  `-I/usr/local/include` (a stale 8.x `tcl.h` there shadows everything);
- strips `-lX11` (extensions must bind the wish's SDL X emulation);
- prefers the TEA `binaries` target so a docs target needing `doctools` doesn't
  fail the build.

**Two things buildext can't do for you:**
1. The **pkgIndex load prefix must match the init symbol's exact case** —
   `Parse_args_Init` → prefix `Parse_args` (not `parse_args`).
2. Companion **`.tcl`** files carry their own `package require Tcl 8.x` guards —
   patch those in the assembled battery.

## 3. Prerequisites / sources (nothing is vendored here)

You need, laid out under a work root (the reference build used `~/undroidwish91/`):

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

7. **Bundle + run.** `build.sh` packages a self-contained `undroidwish91.app`
   automatically. A `.app` bundle is REQUIRED on macOS — a bare binary gets no
   window-server connection and renders nothing, logging `CGContextFillRects:
   invalid context 0x0`.
   ```sh
   open undroidwish91.app --args yourscript.tcl     # no env vars needed
   ```
   The bundle layout is self-contained and needs **no `TCL_LIBRARY` /
   `TK_LIBRARY`**:
   ```
   undroidwish91.app/Contents/MacOS/undroidwish91
   undroidwish91.app/Contents/Resources/tcl9.1/     (Tcl 9.1 library, init.tcl)
   undroidwish91.app/Contents/Resources/tk9.1/      (Tk 9.1 library + fonts/)
   undroidwish91.app/Contents/Info.plist            (APPL, NSHighResolutionCapable)
   ```

### Library auto-discovery

`main()` in `tkAppInit.c` calls `UwFindLibraries()` before Tcl initializes. If
`TCL_LIBRARY` / `TK_LIBRARY` are not already set, it locates the script libraries
by probing, in order:

1. relative to the executable (`realpath` of `_NSGetExecutablePath`):
   `../Resources/tcl9.1`, `../lib/tcl9.1`, `../../lib/tcl9.1`, `library`, … (the
   `../Resources/*` entries cover the `.app` bundle; `../lib/*` covers a normal
   `<prefix>/bin` + `<prefix>/lib` install), validated by the presence of
   `init.tcl` (Tcl) / `tk.tcl` (Tk);
2. common absolute locations: `/opt/homebrew/lib/tcl9.1`,
   `/usr/local/lib/tcl9.1`, `/Library/Tcl/tcl9.1`, `/usr/lib/tcl9.1` (and the
   `tk9.1` equivalents).

The first match wins; a caller-provided env var always takes precedence. This is
why the app runs with no environment setup. (The SDL font discovery in
`SdlTkUtils.c` reads `$TK_LIBRARY`, which is now populated by this step, so bundled
fonts are found too.)

## 5. The port's new source files (in `src/`)

- **`tkSDLCompat91.c`** — bridges Tk 8.6→9.1 platform-hook renames (the SDL layer
  still defines the historical `Tkp*` names; Tk 9.1 generic calls the new `Tk_*` /
  `TkUnix*` names): `Tk_MakeWindow`, `Tk_UseWindow`, `Tk_GetOtherWindow`,
  `Tk_MakeContainer`, `Tk_GetSystemDefault`, `Tk_DrawHighlightBorder`,
  `TkUnixContainerId`, `TkUnixDoOneXEvent`, `TkUnixSetMenubar`,
  `Tk_DrawCharsInContext`, `Tk_MeasureCharsInContext`. Also implements
  `TkpSetCapture` / `TkpGetCapture` (see §6, capture release), stubs
  `TkpWindowIsDark`, defines the `ttkDefScrollbarWidth` / `ttkMinThumbSize`
  globals, and provides the env-gated `uwsynthmouse` test command
  (`UW_SYNTHMOUSE=1`) used by `tests/wm-regression.tcl`.
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
- **Capture release killed window management.** Tk 9.1's generic `tkPointer.c`
  takes an implicit pointer grab on every ButtonPress (`TkpSetCapture(winPtr)`)
  and releases it with **`TkpSetCapture(NULL)`**. The first shim ignored the NULL
  case, so `SdlTkX.capture_window` stayed set forever after the first click in any
  widget; `SdlTkGrabCheck()` then returned false for every decorative frame and
  windows could no longer be moved, resized or closed (widgets kept working, which
  makes this look like a decoration bug). **Fix:** route NULL to
  `TkpSetCaptureEx(<capture window's display>, NULL)` — note it must be the
  *capturing window's* `Display`, since sdl2tk hands out one `Display` per
  interpreter (console vs. main) and `TkpSetCaptureEx` answers `GrabFrozen` on a
  mismatch. Regression test: `tests/wm-regression.tcl`.
- **Pristine `generic/` silently drops AndroWish hooks.** Building on *pristine*
  Tk 9.1 `generic/` loses every `#ifdef PLATFORM_SDL` hunk AndroWish had there.
  Re-applied so far (`patches/tk91-generic-platform-sdl.patch`): the DejaVu / Droid
  / Noto **font alias + fallback tables** in `tkFont.c` (without them XLFD names
  like `-*-dejavu sans-...` don't resolve — the bundled family is actually
  *"DejaVu LGC Sans"* — so decorative-frame **window titles render blank**), the
  DPI-max **font sizing** in `TkFontGetPixels`/`TkFontGetPoints`, registration of
  the **`sdltk` ensemble** in the `tkWindow.c` command table (its 35 subcommand
  procs must be re-typed to `Tcl_Size objc` — Tk 9.1's `TkEnsemble` holds
  `Tcl_ObjCmdProc2 *`), and the **`-sdl*` argv options** in `Tk_Init`'s
  `Tcl_ArgvInfo` table. Still unreviewed: `tkBind.c`, `tkCmds.c`,
  `tkImgPhInstance.c`, `tkGrab.c`, `tkPointer.c`, `tkEvent.c`, ttk themes.
- **Head-less UI testing.** Don't drive the real pointer: `uwsynthmouse
  down|up|move|hover x y ?-x?` (registered only when `UW_SYNTHMOUSE` is set)
  pushes synthetic SDL mouse events; `-x` means the coordinates are X-screen
  coordinates (translated back through the device mapping). `uwsynthmouse state`
  dumps capture/focus/window-flag state. `UW_EVLOG=1` traces `SDL_WINDOWEVENT`s.
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
  `~/Library/Logs/DiagnosticReports/undroidwish91*.ips` (JSON), or run lldb with the
  post-crash commands as `-k` (not `-o`):
  `lldb -b -o run -k "register read lr" -k "image lookup -v -a \$lr" -k quit -- ./undroidwish91 script.tcl`.

## 7. Where to resume

The next big chunk is **§1 of [TODO.md](TODO.md): porting the ~60 extensions to
Tcl 9.** Start with Img/tkimg, tls, tdom, tkblt. Each is the same class of
mechanical ABI work (`Tcl_Size`, `Tcl_ObjCmdProc2`, removed APIs) already exercised
on the core here. After that: real build integration, patch extraction, and
notarized packaging (§2–4).
