# undroidwish-arm64 on Tcl/Tk 9.1

A work-in-progress port of **undroidwish** — the SDL2-based, batteries-included
`wish` from [AndroWish](https://www.androwish.org/) — to **Tcl/Tk 9.1b0**,
built **natively for Apple Silicon (arm64)** on macOS.

> **Status: all 17 bare-launch demos work.** `undroidwish91` builds and runs
> natively on arm64 as a self-contained `.app`, reproducing undroidwish's bare
> launch (console + Tk window + **Demos ▸** menu), and **every one of the 17
> demos is enabled and working** — including the extension-heavy ones (Img,
> tkchat, helpviewer, zinc-widget, tkpdemo, vncviewer, tksqlite, …).
> 21 C-extension stacks are ported to Tcl 9.1. See [TODO.md](TODO.md).

## What this is

undroidwish is "AndroWish without the Android" — it runs Tcl/Tk GUI programs on
desktop platforms using an **X11-server emulation layer implemented on top of
SDL2** (with Anti-Grain-Geometry for rendering) instead of a real X server,
Cocoa, or Win32. That backend, `sdl2tk`, is a fork of **Tk 8.6**.

This repository documents porting that backend forward to **Tk 9.1** — the first
Tcl/Tk 9.x release able to run on the SDL2 backend. Tk 9.x is a major release
with an ABI break from 8.6 (`Tcl_Size`/TIP 494, removed deprecated APIs, renamed
platform hooks, `Tcl_ObjCmdProc2`, etc.), so this is a genuine port rather than a
version bump.

It is the Tcl/Tk-9.1 sibling of the existing 8.6 recipe repo,
[`undroidwish-arm64-batteries-included`](https://github.com/johnbuckman/undroidwish-arm64-batteries-included).

## What works today

- **Tcl 9.1b0** and **Tk 9.1b0** compile and link into a native arm64 `undroidwish91`.
- The whole `sdl2tk` backend (platform layer + AGG/X11 emulation + AGG renderer)
  compiles clean against Tk 9.1.
- At runtime: `package require Tk` → `9.1b0`, `tk windowingsystem` → `x11`,
  widgets create and render, event loop runs, clean exit.
- Fonts are discovered (system fonts + bundled DejaVu) and rendered via FreeType.
- **Bare launch matches undroidwish**: `open undroidwish91.app` (no script) shows
  the main window **and** a Tk console, and installs a **Demos** submenu on the
  console's File menu (via the bundled [`main.tcl`](main.tcl)). Passing a script
  (`open … --args foo.tcl`) skips all this.
- **All 17 demos**: widget, tkcon, tkinspect, notebook, tksqlite, stardom,
  tktable, treectrl, tkchat, zint, imgdemo, borgdemo, bledemo, helpviewer,
  zinc-widget, tkpdemo, vncviewer.
- **Extensions ported to Tcl 9.1** (21 stacks): sqlite3, tdom, Tktable,
  treectrl, tls, itcl+itk (+iwidgets), borg, zint, tkhtml, **Img/tkimg
  (24 dylibs)**, Tkzinc, tkpath, tkvnc — plus the non-demo batteries
  parse_args, pikchr, parser, tksvg, tclcsv, vfs, udp, Memchan.
- **Bluetooth** (the `ble` battery / bledemo) scans and finds real devices.
- **Window management**: decorative frames move, resize and close; the `sdltk`
  command and the `-sdl*` command-line options are wired up; window titles and
  the active-window highlight render; the macOS desktop window is resizable by
  default (`-sdlfixedsize` restores the 8.6 behaviour).

## What does **not** work yet

- **~40 remaining non-demo batteries** (BLT, tclx, nsf, trofs, Rtcl, TclMagick,
  …) — an individual-fix tail. Status + the Tcl-9 failure taxonomy are in
  [`ext-build/NON-DEMO-BATTERIES.md`](ext-build/NON-DEMO-BATTERIES.md); several
  need external libraries (R, VLC, ImageMagick, librdkafka, taglib) that aren't
  installed.
- **Not self-contained**: `tls` links Homebrew openssl@3 and `tkpath` links
  Homebrew cairo.
- **PNG *write*** crashes inside libpng (read is fine) — see
  [`ext-build/BUILD-Img.md`](ext-build/BUILD-Img.md).
- No autoconf integration, no notarized `.app`/DMG yet (built with a direct
  script, see below).
- Touch-friendly ttk scrollbar sizing is not yet re-wired (uses 9.1 defaults).
- Only some of the AndroWish `generic/` `#ifdef PLATFORM_SDL` hunks have been
  re-applied to pristine Tk 9.1 (see
  [`patches/tk91-generic-platform-sdl.patch`](patches/tk91-generic-platform-sdl.patch));
  the rest of that surface (tkBind, tkCmds, tkImgPhInstance, ttk themes, …) is
  still unreviewed.

## Building

The current build uses a **direct build script** (no autoconf) that compiles Tk
9.1's `generic/` sources plus the SDL platform layer and links against a
prebuilt Tcl 9.1, SDL2, FreeType, and AGG. See [`build.sh`](build.sh) and the
detailed, reproducible recipe in **[AGENTS.md](AGENTS.md)**.

At a high level:

1. Build Tcl 9.1b0 static (`libtcl9.1.a`).
2. Lay down a work tree: pristine `tk9.1b0` + the grafted `sdl/` and `xlib/`
   backend from AndroWish's `sdl2tk`, with the port patches applied.
3. Add the three small port source files from [`src/`](src/) to the backend.
4. Run `build.sh` — it compiles + links the `undroidwish91` executable **and**
   packages a self-contained `undroidwish91.app`.
5. Run it: `open undroidwish91.app --args yourscript.tcl`.

The `.app` bundle is **self-contained** — the Tcl/Tk 9.1 script libraries live
under `Contents/Resources`, and the binary discovers them automatically relative
to itself, so **`TCL_LIBRARY` / `TK_LIBRARY` do not need to be set**. (If set, they
win; otherwise the binary also searches common install locations such as
`/opt/homebrew/lib/tcl9.1`.) A bundle is required on macOS regardless — a bare
terminal binary gets no window-server connection and renders nothing.

Full step-by-step instructions, dependency locations, and every gotcha are in
**[AGENTS.md](AGENTS.md)** — written so a human or an AI agent can resume the work.

## Contents of this repo

| Path | What it is |
|------|-----------|
| [`README.md`](README.md) | This file |
| [`BOOTSTRAP.md`](BOOTSTRAP.md) | **Start here to resume the work cold** — machine layout, rebuild + headless-verification recipes, what's done, what's open |
| [`AGENTS.md`](AGENTS.md) | Detailed status + full build recipe + resume notes (for humans and AI) |
| [`TODO.md`](TODO.md) | Remaining work to reach a shippable build |
| [`main.tcl`](main.tcl) | Bare-launch boot script (console + Demos menu + window placement) |
| [`PORTING-TCL-DEMOS.md`](PORTING-TCL-DEMOS.md) | Recurring **pure-Tcl** Tcl-9 fixes (version guards, removed Tk commands, namespace scoping, UTF-8 encoding) |
| [`ext-build/buildext.sh`](ext-build/buildext.sh) | Extension build workhorse — handles the Tcl-9 traps automatically |
| [`ext-build/ext-compat91.h`](ext-build/ext-compat91.h) | Force-included compat header (restores removed macros; maps X region API to the wish's exports) |
| [`ext-build/patches/`](ext-build/patches/) | Per-extension Tcl-9 diffs (tls, itk, zint, tkhtml, tkzinc, tkpath, tcludp, memchan) |
| [`ext-build/BUILD-Img.md`](ext-build/BUILD-Img.md) | The coordinated 24-package tkimg (Img) build recipe |
| [`ext-build/NON-DEMO-BATTERIES.md`](ext-build/NON-DEMO-BATTERIES.md) | Non-demo battery status + Tcl-9 failure taxonomy |
| [`src/`](src/) | New source files authored for the 9.1 port (compat bridges + stubs) |
| [`patches/`](patches/) | Unified diffs of the changes to the vendored Tk 9.1 `generic/` and AndroWish `sdl/` sources |
| [`tests/wm-regression.tcl`](tests/wm-regression.tcl) | Head-less window-management test (synthetic SDL mouse events, no real pointer) |
| [`build.sh`](build.sh) | The direct build/link script |
| [`LICENSE`](LICENSE) | Tcl/Tk (BSD-style) license |

This repo contains **patches, new sources, and documentation only**. It does not
redistribute the AndroWish, Tcl, Tk, SDL2, FreeType, or AGG sources — fetch those
from their upstreams (see [AGENTS.md](AGENTS.md)).

## License

The port sources here are released under the **[Tcl/Tk license](LICENSE)**
(BSD-style), matching the upstream Tcl/Tk and AndroWish licensing. The AndroWish/
`sdl2tk` sources this port builds on are themselves under the Tcl/Tk license;
Tcl and Tk are under the Tcl/Tk license; SDL2 is zlib; AGG 2.4 is under its own
permissive license; FreeType under FTL/GPL.

## Credits

- **AndroWish / undroidwish / sdl2tk** — Christian Werner
  ([androwish.org](https://www.androwish.org/)).
- **Tcl/Tk** — the Tcl Core Team.
- **SDL2**, **FreeType**, **Anti-Grain-Geometry 2.4** — their respective authors.
- Original x86_64 → arm64 native port and this 9.1 port: John Buckman.
