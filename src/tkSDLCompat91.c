/*
 * tkSDLCompat91.c --
 *
 *	Bridges Tk 8.6 -> 9.1 platform-hook renames for the SDL backend, and
 *	provides small stubs for hooks 9.1 added.  The SDL platform files still
 *	define the historical Tkp* names; Tk 9.1 generic code calls the new
 *	Tk_* / TkUnix* names.  These thin forwarders connect the two.
 */

#include "tkInt.h"

/*
 * AndroWish touch-friendly scrollbar globals.  SdlTkX.c writes these at
 * startup to size scrollbars for the display DPI.  8.6 defined them inside
 * ttkDefaultTheme.c; 9.1 restructured that theme (Tcl_Obj-based sizing) and no
 * longer reads them, so they live here for now.  TODO: rewire into the 9.1 ttk
 * default theme to restore touch-sized scrollbars.
 */
char ttkDefScrollbarWidth[TCL_INTEGER_SPACE] = "14";
int  ttkMinThumbSize = 8;

/* SDL-side implementations (historical names). */
extern Window     TkpMakeWindow(TkWindow *winPtr, Window parent);
extern int        TkpUseWindow(Tcl_Interp *interp, Tk_Window tkwin,
			const char *string);
extern void       TkpMakeContainer(Tk_Window tkwin);
extern Window     TkpContainerId(TkWindow *winPtr);
extern TkWindow  *TkpGetOtherWindow(TkWindow *winPtr);
extern int        TkpDoOneXEvent(Tcl_Time *timePtr);
extern void       TkpSetMenubar(Tk_Window tkwin, Tk_Window menubar);
extern Tcl_Obj   *TkpGetSystemDefault(Tk_Window tkwin, const char *dbName,
			const char *className);
extern void       TkpDrawHighlightBorder(Tk_Window tkwin, GC fgGC, GC bgGC,
			int highlightWidth, Drawable drawable);
extern void       TkpDrawCharsInContext(Display *display, Drawable drawable,
			GC gc, Tk_Font tkfont, const char *source, int numBytes,
			int rangeStart, int rangeLength, int x, int y);
extern int        TkpMeasureCharsInContext(Tk_Font tkfont, const char *source,
			int numBytes, int rangeStart, int rangeLength,
			int maxLength, int flags, int *lengthPtr);
extern void       TkpSetCaptureEx(Display *display, TkWindow *winPtr);

/* --- Renamed hooks: new name -> historical SDL implementation. --- */

Window
Tk_MakeWindow(Tk_Window tkwin, Window parent)
{
    return TkpMakeWindow((TkWindow *) tkwin, parent);
}

int
Tk_UseWindow(Tcl_Interp *interp, Tk_Window tkwin, const char *string)
{
    return TkpUseWindow(interp, tkwin, string);
}

void
Tk_MakeContainer(Tk_Window tkwin)
{
    TkpMakeContainer(tkwin);
}

Tk_Window
Tk_GetOtherWindow(Tk_Window tkwin)
{
    return (Tk_Window) TkpGetOtherWindow((TkWindow *) tkwin);
}

Window
TkUnixContainerId(TkWindow *winPtr)
{
    return TkpContainerId(winPtr);
}

int
TkUnixDoOneXEvent(Tcl_Time *timePtr)
{
    return TkpDoOneXEvent(timePtr);
}

void
TkUnixSetMenubar(Tk_Window tkwin, Tk_Window menubar)
{
    TkpSetMenubar(tkwin, menubar);
}

Tcl_Obj *
Tk_GetSystemDefault(Tk_Window tkwin, const char *dbName, const char *className)
{
    return TkpGetSystemDefault(tkwin, dbName, className);
}

void
Tk_DrawHighlightBorder(Tk_Window tkwin, GC fgGC, GC bgGC, int highlightWidth,
	Drawable drawable)
{
    TkpDrawHighlightBorder(tkwin, fgGC, bgGC, highlightWidth, drawable);
}

void
Tk_DrawCharsInContext(Display *display, Drawable drawable, GC gc,
	Tk_Font tkfont, const char *string, Tcl_Size numBytes,
	Tcl_Size rangeStart, Tcl_Size rangeLength, int x, int y)
{
    TkpDrawCharsInContext(display, drawable, gc, tkfont, string,
	    (int) numBytes, (int) rangeStart, (int) rangeLength, x, y);
}

int
Tk_MeasureCharsInContext(Tk_Font tkfont, const char *string, Tcl_Size numBytes,
	Tcl_Size rangeStart, Tcl_Size rangeLength, int maxPixels, int flags,
	int *lengthPtr)
{
    return TkpMeasureCharsInContext(tkfont, string, (int) numBytes,
	    (int) rangeStart, (int) rangeLength, maxPixels, flags, lengthPtr);
}

/* --- Hooks new in 9.1: minimal stubs for the SDL backend. --- */

void
TkpSetCapture(TkWindow *winPtr)
{
    extern void SdlTkReleaseCapture(void);

    extern int SdlTkDbgSetCount;

    if (winPtr != NULL) {
	SdlTkDbgSetCount++;
	TkpSetCaptureEx(winPtr->display, winPtr);
    } else {
	/*
	 * CRITICAL: TkpSetCapture(NULL) is how Tk 9.1's generic tkPointer.c
	 * *releases* the implicit pointer grab it takes on every ButtonPress.
	 * Dropping it (as this stub originally did) left SdlTkX.capture_window
	 * set forever after the first click in any widget, which made
	 * SdlTkGrabCheck() fail for every decorative frame -- windows could no
	 * longer be moved, resized or closed.
	 */
	SdlTkReleaseCapture();
    }
}

Tk_Window
TkpGetCapture(void)
{
    extern Tk_Window SdlTkGetCapture(void);

    return SdlTkGetCapture();
}

int
TkpWindowIsDark(Tk_Window tkwin, bool *isdark)
{
    (void) tkwin;
    if (isdark != NULL) {
	*isdark = 0;
    }
    return 0;
}

/*
 * Tk 9 changed Tk_ConfigureWidget from string-based (int argc, const char
 * **argv) to object-based (Tcl_Size objc, Tcl_Obj *const *objv).  Old widget
 * extensions (tktable, treectrl, ...) still pass string argv; this shim bridges
 * them.  Extensions reach it via the macro in ext-build/ext-compat91.h; the
 * wish exports it for load-time binding.
 */
int
Uw_TkConfigureWidgetStr(Tcl_Interp *interp, Tk_Window tkwin,
	const Tk_ConfigSpec *specs, Tcl_Size argc, const char **argv,
	void *widgRec, int flags)
{
    Tcl_Obj **ov = NULL;
    Tcl_Size i;
    int result;

    if (argc > 0) {
	ov = (Tcl_Obj **) ckalloc(argc * sizeof(Tcl_Obj *));
	for (i = 0; i < argc; i++) {
	    ov[i] = Tcl_NewStringObj(argv[i] ? argv[i] : "", -1);
	    Tcl_IncrRefCount(ov[i]);
	}
    }
    result = Tk_ConfigureWidget(interp, tkwin, specs, argc, ov, widgRec, flags);
    if (ov != NULL) {
	for (i = 0; i < argc; i++) {
	    Tcl_DecrRefCount(ov[i]);
	}
	ckfree((char *) ov);
    }
    return result;
}

/*
 * TclGetIntForIndex (internal, string "end"/"N" index parsing) was removed as a
 * public-ish symbol in Tcl 9 in favour of Tcl_GetIntForIndex with Tcl_Size.
 * Old extensions (treectrl) still call the int-based one; shim it.
 */
int
TclGetIntForIndex(Tcl_Interp *interp, Tcl_Obj *objPtr, int endValue,
	int *indexPtr)
{
    Tcl_Size idx;
    int result = Tcl_GetIntForIndex(interp, objPtr, endValue, &idx);

    if ((result == TCL_OK) && (indexPtr != NULL)) {
	*indexPtr = (int) idx;
    }
    return result;
}

/*
 * ---------------------------------------------------------------------------
 * uwsynthmouse -- debug/test hook (enabled only when UW_SYNTHMOUSE is set in
 * the environment).  Pushes a synthetic SDL mouse event into the SDL queue so
 * the window-management paths (decorative frame: drag / resize / close button)
 * can be exercised head-lessly, without driving the real pointer.
 *
 *   uwsynthmouse down|up x y
 *   uwsynthmouse move x y
 * ---------------------------------------------------------------------------
 */
#include "SDL.h"

static int lastSynthX = 0, lastSynthY = 0;

static int
UwSynthMouseCmd(void *clientData, Tcl_Interp *interp, int objc,
	Tcl_Obj *const objv[])
{
    SDL_Event ev;
    int x, y;
    const char *what;
    (void) clientData;

    if ((objc == 2) && (strcmp(Tcl_GetString(objv[1]), "state") == 0)) {
	extern void SdlTkDebugGrabState(char *buf, int len);
	char buf[256];

	SdlTkDebugGrabState(buf, sizeof (buf));
	Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, -1));
	return TCL_OK;
    }
    if ((objc != 4) && (objc != 5)) {
	Tcl_WrongNumArgs(interp, 1, objv, "down|up|move x y ?-x?");
	return TCL_ERROR;
    }
    what = Tcl_GetString(objv[1]);
    if (strcmp(what, "state") == 0) {
	extern void SdlTkDebugGrabState(char *buf, int len);
	char buf[256];

	SdlTkDebugGrabState(buf, sizeof (buf));
	Tcl_SetObjResult(interp, Tcl_NewStringObj(buf, -1));
	return TCL_OK;
    }
    if ((Tcl_GetIntFromObj(interp, objv[2], &x) != TCL_OK) ||
	(Tcl_GetIntFromObj(interp, objv[3], &y) != TCL_OK)) {
	return TCL_ERROR;
    }
    if (objc == 5) {
	/* coordinates are X-screen coords: map back to device coords */
	extern void SdlTkTranslatePointerPub(int rev, int *x, int *y);

	SdlTkTranslatePointerPub(1, &x, &y);
    }
    memset(&ev, 0, sizeof (ev));
    if ((strcmp(what, "move") == 0) || (strcmp(what, "hover") == 0)) {
	ev.type = SDL_MOUSEMOTION;
	ev.motion.timestamp = SDL_GetTicks();
	ev.motion.x = x;
	ev.motion.y = y;
	ev.motion.xrel = x - lastSynthX;
	ev.motion.yrel = y - lastSynthY;
	ev.motion.state = (strcmp(what, "hover") == 0) ? 0 : SDL_BUTTON_LMASK;
    } else {
	ev.type = (strcmp(what, "down") == 0) ? SDL_MOUSEBUTTONDOWN
					      : SDL_MOUSEBUTTONUP;
	ev.button.timestamp = SDL_GetTicks();
	ev.button.button = SDL_BUTTON_LEFT;
	ev.button.state = (ev.type == SDL_MOUSEBUTTONDOWN) ? SDL_PRESSED
							   : SDL_RELEASED;
	ev.button.clicks = 1;
	ev.button.x = x;
	ev.button.y = y;
    }
    lastSynthX = x;
    lastSynthY = y;
    if (SDL_PushEvent(&ev) < 0) {
	Tcl_SetObjResult(interp, Tcl_NewStringObj(SDL_GetError(), -1));
	return TCL_ERROR;
    }
    return TCL_OK;
}

void
Uw_InstallSynthMouse(Tcl_Interp *interp)
{
    if (getenv("UW_SYNTHMOUSE") != NULL) {
	Tcl_CreateObjCommand(interp, "uwsynthmouse", UwSynthMouseCmd,
		NULL, NULL);
    }
}
