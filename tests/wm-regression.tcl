# wm-regression.tcl -- window-management regression test for undroidwish91
#
# Exercises the decorative-frame paths (move / resize / close button) of the
# SDL2 X11 emulation WITHOUT touching the real pointer, by pushing synthetic
# SDL mouse events through the debug command `uwsynthmouse` (compiled in, but
# only registered when UW_SYNTHMOUSE is set in the environment).
#
# Run:
#   rm -f /tmp/uwwm4.txt
#   UW_SYNTHMOUSE=1 undroidwish91.app/Contents/MacOS/undroidwish91 \
#       tests/wm-regression.tcl </dev/null >/dev/null 2>&1
#   cat /tmp/uwwm4.txt        # expect 5x PASS
#
# Regression covered: Tk 9.1's generic tkPointer.c releases its implicit
# pointer grab with TkpSetCapture(NULL).  When that was a no-op, one click in
# any widget left SdlTkX.capture_window set forever, SdlTkGrabCheck() then
# failed for every decorative frame, and windows could no longer be moved,
# resized or closed.
#
set f [open /tmp/uwwm4.txt w]
proc P {args} { global f; puts $f [join $args " "]; flush $f }
proc pump {{ms 150}} { set ::done 0; after $ms {set ::done 1}; vwait ::done; update }
set FW 6; set TH 20
proc fi {w} { global FW TH
  list [expr {[winfo rootx $w]-$FW}] [expr {[winfo rooty $w]-$TH}] [expr {[winfo width $w]+2*$FW}] [expr {[winfo height $w]+$TH+$FW}] }
proc click {x y} { uwsynthmouse hover $x $y -x; pump; uwsynthmouse down $x $y -x; pump; uwsynthmouse up $x $y -x; pump }
proc drag {x0 y0 x1 y1} {
  uwsynthmouse hover $x0 $y0 -x; pump; uwsynthmouse down $x0 $y0 -x; pump
  uwsynthmouse move $x1 $y1 -x; pump; uwsynthmouse up $x1 $y1 -x; pump }
proc ok {name cond} { set r [uplevel 1 [list expr $cond]]; P [format "%-28s %s" $name [expr {$r ? "PASS" : "FAIL"}]] }
wm geometry . 200x150+600+450

# --- scenario 1: menu usage then window ops
menu .m -tearoff 0
.m add command -label One -command {set ::picked 1}
toplevel .t; wm geometry .t 300x200+100+100
pack [button .t.b -text Hello] -expand 1
pump 400
tk_popup .m [expr {[winfo rootx .t]+40}] [expr {[winfo rooty .t]+40}]
pump 200
click [expr {[winfo rootx .t]+50}] [expr {[winfo rooty .t]+50}]
pump 200
catch {destroy .m}
lassign [fi .t] fx fy fw fh
drag [expr {$fx+50}] [expr {$fy+10}] [expr {$fx+80}] [expr {$fy+40}]
ok "move after menu" {[winfo rootx .t] == 136}

# --- scenario 2: resize after widget click
click [expr {[winfo rootx .t.b]+5}] [expr {[winfo rooty .t.b]+5}]
lassign [fi .t] fx fy fw fh
drag [expr {$fx+$fw-2}] [expr {$fy+$fh-2}] [expr {$fx+$fw+48}] [expr {$fy+$fh+28}]
ok "resize after widget click" {[winfo width .t] == 350 && [winfo height .t] == 230}

# --- scenario 3: destroy a window under the pointer, then operate another
toplevel .u; wm geometry .u 200x150+450+300; pack [button .u.b -text Bye -command {destroy .u}]
pump 300
click [expr {[winfo rootx .u.b]+5}] [expr {[winfo rooty .u.b]+5}]
pump 200
ok "self-destroy via button" {![winfo exists .u]}
lassign [fi .t] fx fy fw fh
drag [expr {$fx+50}] [expr {$fy+10}] [expr {$fx+70}] [expr {$fy+30}]
ok "move after dead window" {[winfo rootx .t] == 156}

# --- scenario 4: close button still works at the end
lassign [fi .t] fx fy fw fh
click [expr {$fx+$fw-20+7}] [expr {$fy+10}]
pump 200
ok "close button" {![winfo exists .t]}
close $f; exit
