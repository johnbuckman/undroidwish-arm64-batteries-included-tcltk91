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
    if (winPtr != NULL) {
	TkpSetCaptureEx(winPtr->display, winPtr);
    }
}

Tk_Window
TkpGetCapture(void)
{
    return NULL;
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
