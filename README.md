# undroidwish-arm64 on Tcl/Tk 9.1

A work-in-progress port of **undroidwish** — the SDL2-based, batteries-included
`wish` from [AndroWish](https://www.androwish.org/) — to **Tcl/Tk 9.1b0**,
built **natively for Apple Silicon (arm64)** on macOS.

> **Status: working proof-of-concept.** A bare `undroidwish91` 9.1 builds, links, and
> runs natively on arm64 — it initializes Tk, creates widgets, and renders a full
> window on screen through the SDL2 backend. The ~60 bundled extensions
> ("batteries") have **not** yet been ported to Tcl 9. See [TODO.md](TODO.md).

Verified end-to-end: `package require Tk` → `9.1b0`, `tk windowingsystem` → `x11`,
and a window with a label, button, entry, checkbutton, and scale renders correctly
on a Retina display and exits cleanly.

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
  console's File menu (via the bundled [`main.tcl`](main.tcl)). The Tk `widget`
  demo runs; the extension-backed demos are present but disabled until the
  batteries are ported. Passing a script (`open … --args foo.tcl`) skips all this.

## What does **not** work yet

- **The extensions ("batteries")** — Img, tls, tdom, BLT/tkblt, etc. — are not
  yet rebuilt against Tcl 9. This is the bulk of the remaining work.
- No autoconf integration, no notarized `.app`/DMG yet (built with a direct
  script, see below).
- Touch-friendly ttk scrollbar sizing is not yet re-wired (uses 9.1 defaults).

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
| [`AGENTS.md`](AGENTS.md) | Detailed status + full build recipe + resume notes (for humans and AI) |
| [`TODO.md`](TODO.md) | Remaining work to reach a shippable build |
| [`main.tcl`](main.tcl) | Bare-launch boot script (console + Demos menu + window placement) |
| [`src/`](src/) | New source files authored for the 9.1 port (compat bridges + stubs) |
| [`patches/`](patches/) | (Reserved) unified diffs of the changes to vendored sources |
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
