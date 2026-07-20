# patches/

Unified diffs of the changes made to the **vendored** sources (which this repo
does not redistribute).  Apply against a pristine checkout.

| Patch | Against | What it does |
|-------|---------|--------------|
| `tk91-generic-platform-sdl.patch` | pristine `tk9.1b0/generic/` | Re-applies the AndroWish `#ifdef PLATFORM_SDL` hunks that the port lost by building on *pristine* Tk 9.1 `generic/`: the DejaVu/Droid/Noto **font alias + fallback tables** (without them XLFD names such as `-*-dejavu sans-...` do not resolve, so window titles render blank), the **DPI-max font sizing** in `TkFontGetPixels`/`TkFontGetPoints`, registration of the **`sdltk` ensemble command**, and the **`-sdl*` command-line options** (`-sdlresizable`, `-sdlfixedsize`, `-sdlwidth`, `-sdlheight`, `-sdlnogl`, …). |
| `sdl2tk-SdlTkInt-91.patch` | AndroWish `sdl2tk/sdl/SdlTkInt.c` (8.6) | Tcl 9 fixes for the SDL platform core, plus `SdlTkReleaseCapture()` / `SdlTkGetCapture()` (the capture-release entry points Tk 9.1 needs) and the env-gated `uwsynthmouse` test hooks. |

| `sdl2tk-SdlTkDecframe-91.patch` | AndroWish `sdl2tk/sdl/SdlTkDecframe.c` (8.6) | Title-bar cursor tweak (4-way "move" cursor while dragging a window). |

Remaining in-place edits to the `sdl/` backend are not yet extracted here; see
[`../AGENTS.md`](../AGENTS.md).
