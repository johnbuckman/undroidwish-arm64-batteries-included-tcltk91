# Porting the pure-Tcl demos / apps to Tcl 9.1

The C extensions are the hard part, but several demos are whole Tcl
applications (tkchat, helpviewer) that need Tcl-9 source fixes too. The
recurring patterns:

## Version guards
- `package require Tcl|Tk 8.x` → `8.x-` (Tcl 9 reads bare "8.x" as 8-only).
- `package vsatisfies [package provide Tcl] 8.x` → `8.x-` (same; else the
  pkgIndex `return`s early and the package "can't be found").
- C-extension `Tcl_InitStubs/Tk_InitStubs/Tcl_PkgRequire(interp,"Tcl"/"Tk","8.x")`
  → `"8.5-"`. NOTE: if you rebuild an extension by hand (not through
  buildext.sh) you must re-apply this yourself — buildext does it, a manual
  `make` from pristine source does not. (This bit tkhtml: `Tkhtml_Init` did
  `Tcl_InitStubs(...,"8.4")` and the load failed with "need 8.4".)

## Removed Tk commands
- `tk::unsupported::ExposePrivateCommand` is gone in Tk 9 → wrap the call
  sites in `catch { }` (tkchat's embedded console).

## Namespace variable resolution
- Tcl does NOT fall back to the global namespace when reading an unqualified
  array inside `namespace eval`. `array set wLocals [array get images]` inside
  `namespace eval ::rframe` reads the (empty) `::rframe::images`, not the
  global `::images` set at file scope → qualify it: `[array get ::images]`.
  (helpviewer's rframe rounded-frame widget.)

## Default encoding
- Tcl 9 `source` defaults to UTF-8. Latin-1 source files fail with "invalid
  or incomplete multibyte or wide character" → `iconv -f ISO-8859-1 -t UTF-8`.
  (helpviewer.tcl.)

## va_copy / implicit decls
- With `-Wno-implicit-function-declaration`, a `.c` that uses `va_copy` but
  never includes `<stdarg.h>` compiles to an undefined `_va_copy` symbol →
  add the include. (tkhtml htmltcl.c.)

## Missing pure-Tcl libraries
- tkchat needs tklib (khim, tooltip, style::as) in addition to tcllib — bundle
  tklib0.7.

## Status
- **tkchat**: WORKS (full UI: menubar, paned chat window, entry, login dialog).
- **helpviewer**: all C deps load (Tkhtml built+loads, Img, BWidget, tcllib,
  tklib); version guards + rframe scoping + UTF-8 fixed; remaining tail is
  app-config init (`app(CFG_FILE)` global/namespace scoping in the multi-file
  helpviewer app). Not yet a working demo.
