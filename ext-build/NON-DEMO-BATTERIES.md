# Non-demo batteries — status & Tcl-9 failure taxonomy

The 17 demos are done. Beyond them AndroWish ships ~60 more C extensions
(`~/iwish/build-uw-arm64/assets/*/lib*.dylib`). These are the optional long
tail. `ext-build/buildext.sh` is the workhorse; the notes below are what the
first sweep learned.

## Built + loading on Tcl/Tk 9.1 arm64 (beyond the demo set)
- **parse_args 0.5.1**, **pikchr 1.0**, **parser 1.8** (tclparser),
  **tksvg 0.14**, **tclcsv 2.3** — clean builds, load and run.

## buildext.sh now handles (added during this sweep)
- Stale prebuilt **iOS** `.dylib`s in the sources (deleted before build; else
  a failed build leaves one and dlopen says "incompatible platform").
- `-mmacosx-version-min=11.0` pins the Mach-O platform to macOS.
- Version-guard sweep is recursive (src/, generated/, unix/) and matches any
  interp arg name (critcl emits `ip`) + `Tcl_PkgRequireEx`.
- Tcl 9.1 `libtommath` on the include path.
- **pkgIndex load prefix must match the init symbol's exact case**
  (`Parse_args_Init` → prefix `Parse_args`, NOT `parse_args`).

## Failure taxonomy (what blocks the rest, by kind)
1. **Removed obj types** — e.g. rl_json caches `Tcl_GetObjType("int")`, which
   Tcl 9 removed (int/wideInt unified) → "Can't retrieve objType for int".
   Needs a newer upstream or an internal rewrite.
2. **TIP-445 shim conflict** — bundled `tip445.h` redefines
   `Tcl_ObjInternalRep` (native in Tcl 9). Fix: force `-DTIP445_SHIM=0`
   (configure mis-detects). Done for rl_json; still errors on #1.
3. **Channel driver v9** — `Tcl_DriverCloseProc` is now incomplete/`void`,
   `ThreadAction` etc.; old drivers (Memchan, tcludp) need the v5 close2/wide
   migration (cf. the tls channel patch).
4. **Removed types/macros** — tclx uses `Tcl_Value` (gone); others use
   `Tcl_SaveResult`, etc.
5. **critcl version-provide mismatch** — tcllibc loads but provides a version
   the pkgIndex doesn't expect.
6. **Missing external libs** — many need libs not installed: R (Rtcl),
   VLC (tkvlc), ImageMagick (TclMagick), librdkafka (kafka), taglib
   (tcltaglib), augeas, snap7, libmodbus, VecTcl's LAPACK is huge, etc.
7. **Bundled by Tcl 9.1 already** — itcl, thread, tdbc*, sqlite3 ship in
   `tcl9.1b0/pkgs/`; prefer those over the AndroWish copies.

Each remaining battery is an individual fix along one of these lines — a
diminishing-returns tail, not a single sweep.

## Update: +vfs 1.4.2
tclvfs builds + loads. Two fixes beyond buildext: its companion `.tcl` files
carry `package require Tcl 8.x` guards (patch to `8.x-` in the battery, like
the demo apps); nothing C-side. vfs.tcl loads `libvfs1.4.2.dylib` with no
prefix (derives `Vfs_Init` from the filename — correct).

## Channel-driver family (trofs, tcludp, Memchan, ...) — the biggest blocker
Tcl 9 turned `Tcl_DriverCloseProc` and `Tcl_DriverSeekProc` into `typedef void`
(removed; use `Tcl_DriverClose2Proc` / `Tcl_DriverWideSeekProc`). Old drivers
that forward-declare `static Tcl_DriverCloseProc DriverClose;` then become
`static void DriverClose;` -> "incomplete type" + "redefinition as different
kind of symbol", and `(*seekProc)()` calls hit "called object type void*".
Each such driver needs: explicit function prototypes instead of the removed
typedefs, a close2Proc wrapper (flags==0 => old close), and the ChannelType
bumped to VERSION_5 (cf. the tls channel patch). Individual per-extension work.
