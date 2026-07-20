# BOOTSTRAP.md — restore full working state of this port

**Purpose:** this file is the single entry point for picking the port back up
cold (new session, new agent, new machine). It records *where everything lives*,
*how to rebuild and verify*, *what is done*, *what broke and why*, and *what is
left*. Read this first, then [`AGENTS.md`](AGENTS.md) for the deep build recipe
and gotcha list.

Last updated: 2026-07-20 (after the window-management fix).

---

## 0. One-paragraph summary

`undroidwish91` is **undroidwish** — AndroWish's SDL2-based, batteries-included
Tk `wish`, whose platform layer is an X11-server emulation on SDL2 + AGG — ported
from **Tcl/Tk 8.6.10 to Tcl/Tk 9.1b0**, built **natively for macOS arm64**.
Status: builds, runs as a self-contained `.app`, **all 17 bare-launch demos work**,
**21 C-extension stacks ported**, Bluetooth works, window management works. Left:
a tail of ~40 non-demo batteries, packaging/notarization, and the unreviewed part
of the AndroWish `generic/` patch surface.

---

## 1. Machine layout (all local, none of it in this repo)

| Path | What it is | Under VCS? |
|------|------------|-----------|
| `~/undroidwish91/` | **the build tree** — everything below lives here | no (plain dir) |
| `~/undroidwish91/tcl9.1b0/` | Tcl 9.1b0 source + built `unix/libtcl9.1.a` | no |
| `~/undroidwish91/tk9.1b0/` | **pristine** Tk 9.1b0 (reference for diffs) | no |
| `~/undroidwish91/sdl2tk-9.1/` | **the work tree**: pristine Tk 9.1 + grafted AndroWish `sdl/`, `xlib/` + port edits | no |
| `~/undroidwish91/build/` | objects, `libsdl2tk9.1.a`, the linked `undroidwish91` | no |
| `~/undroidwish91/batteries/` | the batteries-included payload (Tcl packages + built `.dylib`s, 47 dylibs) | no |
| `~/undroidwish91/ext-build/` | per-extension build dirs + logs + `buildext.sh` | no |
| `~/undroidwish91/undroidwish91.app` | the packaged app (58 MB) | no |
| `~/undroidwish91/main.tcl` | bare-launch boot script (console + Demos menu) | copy in repo |
| `~/undroidwish-arm64-batteries-included-tcltk91/` | **this repo** (public, GitHub `johnbuckman`) | git |

Upstream / reference trees used for diffing:

| Path | What |
|------|------|
| `~/iwish/build-uw-arm64/sdl2tk/` | the **8.6 sdl2tk** source this port forked (diff against it to find lost hunks) |
| `~/iwish/build-uw-arm64/SDL2/` | the prebuilt SDL2 (`build/.libs/libSDL2.a`, `libSDL2main.a`) |
| `/Applications/undroidwish-arm64.app` | the **working 8.6 build** — the behavioural reference; run it side by side |
| `/opt/homebrew/lib/libfreetype.dylib`, `/opt/homebrew/include/freetype2` | FreeType |
| `~/undroidwish91/build/libagg.a` | AGG 2.4, built from `sdl2tk-9.1/sdl/agg-2.4` |

The repo contains **patches, new sources, docs and tests only** — it never
redistributes Tcl, Tk, AndroWish, SDL2, FreeType or AGG sources.

---

## 2. Rebuild in one line

```bash
cd ~/undroidwish91 && bash build.sh
```

(`bash build.sh`, not `./build.sh` — the file isn't chmod +x.) It compiles Tk 9.1
`generic/` + the SDL platform layer, links `build/undroidwish91`, and **packages
`undroidwish91.app`** (Tcl/Tk script libraries under `Contents/Resources`, so no
`TCL_LIBRARY`/`TK_LIBRARY` needed). Takes a few minutes; watch for `FAIL cc`,
`error:`, and the final `APP ->` line.

Run it:

```bash
open ~/undroidwish91/undroidwish91.app                      # bare launch (console + Demos menu)
open -n ~/undroidwish91/undroidwish91.app --args foo.tcl    # with a script
~/undroidwish91/undroidwish91.app/Contents/MacOS/undroidwish91 foo.tcl   # direct (keeps env vars)
```

Notes:
- `open` on an **already-running** app ignores `--args`; use `open -n` or `pkill` first.
- A `.app` bundle is mandatory on macOS: a bare terminal binary gets no
  window-server connection (renders nothing) and no TCC identity (no Bluetooth).
- Run the binary **inside the bundle** when you need env vars (`UW_SYNTHMOUSE=1`,
  `UW_EVLOG=1`) — it keeps the bundle identity.

Extensions are built with `ext-build/buildext.sh <name> <srcdir> <tk:0|1> [args]`,
which auto-fixes the recurring Tcl-9 traps; see [`AGENTS.md`](AGENTS.md) §4a and
[`ext-build/NON-DEMO-BATTERIES.md`](ext-build/NON-DEMO-BATTERIES.md).

---

## 3. Verification without taking over the machine

Rule: **do not drive John's real mouse/keyboard.** Everything below is headless.

### 3.1 Synthetic mouse (the UI test harness)

Compiled in, registered **only** when `UW_SYNTHMOUSE` is set:

```tcl
uwsynthmouse down|up|move|hover X Y ?-x?   ;# -x => coords are X-screen coords
uwsynthmouse state                         ;# capture/focus/SDL-window-flags dump
```

`move` carries button-1 state (drag), `hover` carries none. `-x` runs the
coordinates back through the device↔X mapping (`SdlTkTranslatePointerPub`).

Regression suite (5 checks; writes `/tmp/uwwm4.txt`):

```bash
rm -f /tmp/uwwm4.txt
UW_SYNTHMOUSE=1 ~/undroidwish91/undroidwish91.app/Contents/MacOS/undroidwish91 \
    tests/wm-regression.tcl </dev/null >/dev/null 2>&1
cat /tmp/uwwm4.txt      # expect 5 x PASS
```

Decoration geometry constants used by the test: frame width **6**, title height
**20** (`SdlTkX.dec_frame_width` / `dec_title_height` at this DPI). Close button
bounds: `x = frameWidth - (fw + buttonSize)*n` with `fw = 5`, `buttonSize = 15`.

### 3.2 SDL event tracing

`UW_EVLOG=1` prints every `SDL_WINDOWEVENT` (id, window match) to stderr.

### 3.3 Screenshots without hiding John's windows

```bash
# tiny helper: CGWindowListCopyWindowInfo -> "<id> <owner> <x,y> <WxH>"
clang -o /tmp/wl wl.c -framework ApplicationServices    # source in §3.4
/tmp/wl
screencapture -x -o -l <windowid> /tmp/shot.png         # single window, no focus steal
```

Then `Read` the PNG. Compare against the same script run in
`/Applications/undroidwish-arm64.app` (the 8.6 reference) — that side-by-side is
how the blank-title-bar and missing-active-highlight regressions were spotted.
**Never publish these screenshots to the public repo** (full-screen captures leak
private content) — describe results in text instead.

### 3.4 `wl.c`

```c
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
int main(){
  CFArrayRef a=CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly|
      kCGWindowListExcludeDesktopElements,kCGNullWindowID);
  for(CFIndex i=0;i<CFArrayGetCount(a);i++){
    CFDictionaryRef d=CFArrayGetValueAtIndex(a,i);
    CFStringRef o=CFDictionaryGetValue(d,kCGWindowOwnerName);
    char buf[256]=""; if(o) CFStringGetCString(o,buf,256,kCFStringEncodingUTF8);
    if(!strstr(buf,"undroid")) continue;
    int num=0; CFNumberGetValue(CFDictionaryGetValue(d,kCGWindowNumber),kCFNumberIntType,&num);
    CGRect r; CGRectMakeWithDictionaryRepresentation(CFDictionaryGetValue(d,kCGWindowBounds),&r);
    printf("%d %s %.0f,%.0f %.0fx%.0f\n",num,buf,r.origin.x,r.origin.y,r.size.width,r.size.height);
  }
  return 0;
}
```

### 3.5 Quick functional probes

Any Tcl script that writes to a file and calls `exit` works as a headless probe
(remember `flush`, or the file is empty if the app dies). Useful one-liners:
`winfo screenwidth .`, `wm geometry .`, `sdltk size`, `encoding names`,
`font families`, `uwsynthmouse state`.

---

## 4. What is done

- **Tcl 9.1b0 + Tk 9.1b0** compile and link native arm64; the whole `sdl2tk`
  backend (30 `.c` + `SdlTkAGG.cpp`) compiles against Tk 9.1.
- **All 17 demos** work: widget, tkcon, tkinspect, notebook, tksqlite, stardom,
  tktable, treectrl, tkchat, zint, imgdemo, borgdemo, bledemo, helpviewer,
  zinc-widget, tkpdemo, vncviewer.
- **21 extension stacks ported**: sqlite3, tdom, Tktable, treectrl, tls,
  itcl+itk (+iwidgets), borg, zint, tkhtml, Img/tkimg (24 dylibs), Tkzinc,
  tkpath, tkvnc, parse_args, pikchr, parser, tksvg, tclcsv, vfs, udp, Memchan.
- **Bluetooth** works (needs `NSBluetoothAlwaysUsageDescription` in the
  Info.plist *and* launching as a `.app`).
- **Window management** works (see §5), incl. `sdltk`, the `-sdl*` options,
  window titles, the active-window highlight, and a resizable desktop window.

---

## 5. The window-management fix (2026-07-20) — the deepest trap so far

Symptom: *"cannot resize or close windows"*. Decorations drew fine; clicks on
them did nothing — but only **after the first click in any widget**.

Root cause: Tk 9.1's generic `tkPointer.c` takes an implicit pointer grab on
every ButtonPress (`TkpSetCapture(winPtr)`) and releases it with
**`TkpSetCapture(NULL)`**. The 9.1 compat shim implemented only the "set" case,
so `SdlTkX.capture_window` stayed set forever; `SdlTkGrabCheck()` then returned
false for every decorative frame and `SdlTkDecFrameEvent()` dropped every
title-bar / resize-edge / close-button click. Widgets kept working, which
disguises this as a decoration bug.

Second half of the fix: the release must target the **capturing window's**
`Display`. sdl2tk hands out one `Display` per interpreter (console vs. main) and
`TkpSetCaptureEx` answers `GrabFrozen` on a mismatch — passing `SdlTkX.display`
silently did nothing.

Then, from the same investigation, three regressions caused by building on
**pristine Tk 9.1 `generic/`** (which drops every AndroWish `#ifdef PLATFORM_SDL`
hunk):

1. `tkFont.c` **font alias + fallback tables** (DejaVu / Droid / Noto) were gone,
   so XLFD names like `-*-dejavu sans-...` never resolved — the bundled family is
   actually **"DejaVu LGC Sans"** — and decorative-frame **titles rendered blank**.
   Also restored the DPI-max sizing in `TkFontGetPixels`/`TkFontGetPoints`.
2. The **`sdltk` ensemble** was never registered (it lived in AndroWish's
   `tkWindow.c` command table). Its 35 subcommand procs had to be re-typed to
   `Tcl_Size objc` because Tk 9.1's `TkEnsemble` holds `Tcl_ObjCmdProc2 *`.
3. The **`-sdl*` argv options** were gone (`-sdlwidth`, `-sdlheight`, `-sdlnogl`,
   `-sdlresizable`, `-sdlxdpi`, …), now in `Tk_Init`'s `Tcl_ArgvInfo` table.

Deliberate behaviour change: the macOS desktop window is **resizable by default**
(a double-clicked `.app` can't pass `-sdlresizable`); **`-sdlfixedsize`** restores
the 8.6 behaviour. Verified: `sdltk size 900 700` resizes the X desktop cleanly.

Artefacts: [`patches/tk91-generic-platform-sdl.patch`](patches/tk91-generic-platform-sdl.patch),
[`patches/sdl2tk-SdlTkInt-91.patch`](patches/sdl2tk-SdlTkInt-91.patch),
[`src/tkSDLCompat91.c`](src/tkSDLCompat91.c),
[`tests/wm-regression.tcl`](tests/wm-regression.tcl).

**Generalised lesson:** whenever something "works in 8.6, broken in 9.1", first
diff the 8.6 tree's `generic/` against ours:

```bash
cd ~/iwish/build-uw-arm64/sdl2tk/generic
grep -rn PLATFORM_SDL <file>.c        # then check our sdl2tk-9.1/generic/<file>.c
```

Still **unreviewed** PLATFORM_SDL surface: `tkBind.c` (7 hunks), `tkCmds.c` (11),
`tkEvent.c` (10), `tkGrab.c` (5), `tkPointer.c` (11), `tkImgPhInstance.c` (13),
`tkListbox.c`, `tkObj.c`, `tkSelect.c`, `tkTextDisp.c`, `tkMain.c`, `tkConsole.c`,
`tkCanvPs.c`, `tkColor.c`, `tkGet.c`, `tkFrame.c`, `tkRectOval.c`, `tkTest.c`,
`tkZipMain.c`, and the whole `ttk/` set (themes, `ttkTrack.c`, `ttkTreeview.c`).
`tkStubInit.c`/`tkInt.decls`/`*Decls.h` differ too but are generated/declarative.

---

## 6. Earlier hard-won knowledge (do not re-derive)

Full list in [`AGENTS.md`](AGENTS.md) §6; the headline items:

- **Font system was never initialized** → call `SdlTkFontInit()` from
  `TkpFontPkgInit`, and seed `tk_library` from `getenv("TK_LIBRARY")` first.
- **`int` vs `Tcl_Size`**: Tcl 9 writes 8 bytes through length out-params
  (`Tcl_SplitList`, `Tcl_ListObjGetElements`, `Tcl_GetStringFromObj`). Passing
  `&someInt` corrupts the stack — this caused itk's `EXC_BAD_ACCESS`.
- **Version guards**: Tcl 9 reads a bare `"8.x"` as 8-only; every `Tcl_InitStubs`
  / `Tk_InitStubs` / `Tcl_PkgRequire*` / `package require` / `package vsatisfies`
  needs `"8.x-"`. `buildext.sh` does this automatically for `.c` files — **not**
  for companion `.tcl` files.
- **pkgIndex load prefix must match the init symbol's capitalization**
  (`Parse_args_Init` → prefix `Parse_args`; `Vnc_Init` → `Vnc`).
- **Channel drivers**: only `TCL_CHANNEL_VERSION_5` survives;
  `Tcl_DriverCloseProc`/`Tcl_DriverSeekProc` are now `typedef void` → migrate to
  `close2Proc` / `wideSeekProc`.
- **macOS threading**: SDL/Cocoa on the main thread, Tk on a worker thread — this
  is already correct in the vendored code, don't "fix" it.
- **Stale prebuilt iOS dylibs** ship inside AndroWish extension sources; a failed
  build leaves them behind and `dlopen` rejects them. `buildext.sh` deletes all
  `*.dylib`/`*.o` before configuring. Always pass `-mmacosx-version-min`.
- **auto_path isolation**: `main.tcl` strips `/usr/local`, `/opt`, `/Library/Tcl`
  etc. from `auto_path` and eagerly sources each bundled `pkgIndex.tcl` **inside a
  scope where `$dir` is set** (`apply {{dir} {source ...}} $root`) — otherwise the
  system sqlite3/tdom shadow the bundled ones.

---

## 7. Open work (rough priority)

1. **~40 non-demo batteries** — status + failure taxonomy in
   [`ext-build/NON-DEMO-BATTERIES.md`](ext-build/NON-DEMO-BATTERIES.md).
   Documented next targets: `trofs` (completes the channel-driver family),
   newer upstreams for `rl_json` / `nsf` that already support Tcl 9, `tclx`
   (`Tcl_Value` removed), `tbcload`/`Trf` (untriaged). Several need external libs
   that aren't installed (R, VLC, ImageMagick, librdkafka, taglib, augeas, snap7,
   modbus, LAPACK for VecTcl).
2. **Review the rest of the `generic/` PLATFORM_SDL surface** (§5 list).
3. **Self-containment**: `tls` links Homebrew openssl@3, `tkpath` links Homebrew
   cairo.
4. **PNG *write*** crashes inside libpng (read is fine) —
   [`ext-build/BUILD-Img.md`](ext-build/BUILD-Img.md).
5. **Packaging**: no autoconf integration; no notarized `.app`/DMG yet.
6. **Touch-friendly ttk scrollbar sizing** not re-wired (`ttkDefScrollbarWidth` /
   `ttkMinThumbSize` exist in `tkSDLCompat91.c` but 9.1's ttk theme no longer
   reads them).
7. **Capture the remaining `sdl/` in-place edits as patches** (only `SdlTkInt.c`
   and `SdlTkDecframe.c` are extracted so far).

---

## 8. Working conventions (John's)

- **Never `git commit` / `git push` until John has reviewed and says so.**
- Don't drive his computer with computer-use/synthetic input — launch the app and
  tell him what to look at; verify headlessly (§3).
- Don't publish screenshots to the public repo.
- Third-party battery packages are **not** committed here.
- GitHub "personal" = `johnbuckman`. Commits end with
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## 9. Map of the other docs

| File | Read it for |
|------|-------------|
| [`AGENTS.md`](AGENTS.md) | full build recipe, dependency locations, every gotcha |
| [`README.md`](README.md) | public-facing status |
| [`TODO.md`](TODO.md) | remaining work to a shippable build |
| [`PORTING-TCL-DEMOS.md`](PORTING-TCL-DEMOS.md) | recurring **pure-Tcl** Tcl-9 fixes |
| [`ext-build/buildext.sh`](ext-build/buildext.sh) | the extension build workhorse |
| [`ext-build/ext-compat91.h`](ext-build/ext-compat91.h) | force-included compat header |
| [`ext-build/BUILD-Img.md`](ext-build/BUILD-Img.md) | the 24-package Img build |
| [`ext-build/NON-DEMO-BATTERIES.md`](ext-build/NON-DEMO-BATTERIES.md) | battery status + failure taxonomy |
| [`patches/README.md`](patches/README.md) | what each patch is, and against what |
| [`tests/wm-regression.tcl`](tests/wm-regression.tcl) | the headless WM test |
