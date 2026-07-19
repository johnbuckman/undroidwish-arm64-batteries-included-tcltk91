# undroidwish91 boot script.
#
# Sourced automatically on a bare launch (no script argument) via tcl_rcFileName,
# set by Tcl_AppInit in tkAppInit.c.  Mirrors the shipped undroidwish's bare
# launch: it shows the console, adds a "Demos" submenu to the console's File
# menu, and places the console + the main "." window side by side.
#
# Running `undroidwish91 <script>` gives a startup script, so Tk does not source
# this file -- de1plus / explicit demo dispatchers are unaffected.

set ::uw_root [file dirname [info nameofexecutable]]

proc _uwlog {m} {
    if {[info exists ::env(UNDROIDWISH_BOOT_LOG)]} {
        catch {set fh [open $::env(UNDROIDWISH_BOOT_LOG) a]; puts $fh $m; close $fh}
    }
}
_uwlog "boot: root=$::uw_root"

# --- batteries-included packages on auto_path --------------------------------
# (No extensions are ported to Tcl 9 in this build yet; this still registers any
# that get added later, and is harmless when there are none.)
proc ::uw_add_pkgdirs {root} {
    if {[file exists [file join $root pkgIndex.tcl]] && ($root ni $::auto_path)} {
        lappend ::auto_path $root
    }
    foreach d [glob -nocomplain -type d -directory $root *] { ::uw_add_pkgdirs $d }
}
catch { ::uw_add_pkgdirs $::uw_root }

# --- demos -------------------------------------------------------------------
# key -> {menu-label  root-relative-dispatcher}.  Same list as undroidwish; the
# Tk "widget" demo ships with Tk and works, the rest need the (not-yet-ported)
# batteries and show up disabled until they are bundled.
set ::uw_demos {
    widget      {"Tk widget demo"                    widget}
    -sep0       {}
    borgdemo    {"borg — device bridge demo"         borgdemo}
    bledemo     {"Bluetooth LE debugger"             bledemo}
    -sep1       {}
    tkcon       {"tkcon — enhanced console"          tkcon}
    tkinspect   {"tkinspect — widget inspector"      tkinspect}
    tksqlite    {"TkSQLite — SQLite GUI"             tksqlite}
    tktable     {"Tktable — spreadsheet"             tktable}
    treectrl    {"TreeCtrl"                          treectrl}
    tkchat      {"tkchat"                            tkchat}
    tkpdemo     {"tkpath demos"                      tkpdemo}
    zinc-widget {"Tkzinc widget"                     zinc-widget}
    zint        {"zint — barcodes"                   zint}
    imgdemo     {"Img demo"                          imgdemo}
    notebook    {"notebook"                          notebook}
    stardom     {"stardom"                           stardom}
    vncviewer   {"VNC viewer"                        vncviewer}
    helpviewer  {"help viewer"                       helpviewer}
}
proc uw_demo_resolve {entry} {
    if {$entry eq ""} { return "" }
    # The Tk widget demo ships in the Tk script library.
    if {$entry eq "widget"} {
        set w [file join $::tk_library demos widget]
        if {[file exists $w]} { return $w }
    }
    set p [file join $::uw_root $entry]
    return [expr {[file exists $p] ? $p : ""}]
}
proc uw_run_demo {key} {
    foreach {k spec} $::uw_demos {
        if {$k ne $key} continue
        set path [uw_demo_resolve [lindex $spec 1]]
        if {$path eq ""} {
            catch {tk_messageBox -icon info -title "Demos" -message \
                "\"$key\" is not bundled in this undroidwish91 build yet\n(its Tcl 9 extension has not been ported)."}
            return
        }
        set ::argv0 $path; set ::argv {}
        if {[catch {uplevel #0 [list source $path]} err]} {
            catch {tk_messageBox -icon error -title "Demos: $key" -message $err}
        }
        return
    }
}
proc uw_demo_menuspec {} {
    set out {}
    foreach {k spec} $::uw_demos {
        if {[string match -* $k]} { lappend out $k {} 0; continue }
        lappend out $k [lindex $spec 0] [expr {[uw_demo_resolve [lindex $spec 1]] ne ""}]
    }
    return $out
}

# --- install the "Demos" submenu on the console's File menu ------------------
# The console runs in its own interp: drive it with `console eval`, and have its
# items call back into this interp via `consoleinterp eval`.  Retry until the
# console File menu is realized.
proc uw_install_demos_menu {{tries 0}} {
    if {[catch {console eval {winfo exists .menubar.file}} ok] || !$ok} {
        if {$tries < 80} { after 150 [list uw_install_demos_menu [expr {$tries+1}]] } \
        else { _uwlog "demos: gave up after $tries tries" }
        return
    }
    set rc [catch {console eval {
        if {![winfo exists .menubar.file.demos]} {
            menu .menubar.file.demos -tearoff 0
            set idx -1
            for {set i 0} {$i <= [.menubar.file index end]} {incr i} {
                if {[catch {.menubar.file type $i} t] || $t ne "command"} continue
                set l [.menubar.file entrycget $i -label]
                if {[string match -nocase *xit* $l] || [string match -nocase *quit* $l]} { set idx $i; break }
            }
            if {$idx >= 0} {
                .menubar.file insert $idx cascade -label "Demos" -menu .menubar.file.demos
            } else {
                .menubar.file add cascade -label "Demos" -menu .menubar.file.demos
            }
            foreach {k label avail} [consoleinterp eval uw_demo_menuspec] {
                if {[string match -* $k]} { .menubar.file.demos add separator; continue }
                .menubar.file.demos add command -label $label \
                    -state [expr {$avail ? "normal" : "disabled"}] \
                    -command [list consoleinterp eval [list uw_run_demo $k]]
            }
        }
        winfo exists .menubar.file.demos
    }} res]
    _uwlog "demos: installed (tries=$tries rc=$rc res=$res)"
}

# --- console + main window, placed side by side ------------------------------
catch {wm title . "undroidwish91"}
after 200 {catch {console show}}
after 200 {catch {wm geometry . +2+50}}
after 400 uw_install_demos_menu
proc uw_place_console {{tries 0}} {
    if {[catch {console eval {winfo exists .}} ok] || !$ok} {
        if {$tries < 80} { after 150 [list uw_place_console [expr {$tries+1}]] }
        return
    }
    update idletasks
    set mw [winfo width .];  if {$mw <= 1} { set mw [winfo reqwidth .] }
    set cx [expr {2 + $mw + 22}]; set cy 50
    if {$cx < 0} { set cx 0 }
    catch {console eval [format {wm title . "undroidwish91 console"; wm geometry . +%d+%d} $cx $cy]}
    _uwlog "placement: console beside main (+$cx+$cy)"
}
after 400 uw_place_console
_uwlog "boot: main.tcl scheduled afters"
