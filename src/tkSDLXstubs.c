/*
 * tkSDLXstubs.c --
 *
 *	Plain-named X symbols that Tk 9.1 generic code references but the SDL
 *	emulation either exports under an SdlTk* name, or does not implement.
 *
 *	The XIM / XKB / font-set entry points are the X11 internationalized
 *	input-method surface Tk 9.1 grew.  SDL2 handles IME and keyboard
 *	natively, so these are safe no-op stubs for the SDL backend.
 *
 *	This file deliberately does NOT include tkInt.h, so the SdlTkX.h
 *	X* -> SdlTkX* renaming macros are not active here and we define the
 *	plain names.
 */

#include <X11/Xlib.h>
#include <X11/Xutil.h>

/* --- Emulation funcs some generic files call by their unrenamed name. --- */

extern int SdlTkXParseColor(Display *display, Colormap colormap,
	const char *spec, XColor *colorPtr);
extern int SdlTkXPutImage(Display *display, Drawable d, GC gc, XImage *image,
	int src_x, int src_y, int dest_x, int dest_y,
	unsigned int width, unsigned int height);

int
XParseColor(Display *display, Colormap colormap, const char *spec,
	XColor *colorPtr)
{
    return SdlTkXParseColor(display, colormap, spec, colorPtr);
}

int
XPutImage(Display *display, Drawable d, GC gc, XImage *image, int src_x,
	int src_y, int dest_x, int dest_y, unsigned int width,
	unsigned int height)
{
    return SdlTkXPutImage(display, d, gc, image, src_x, src_y, dest_x, dest_y,
	    width, height);
}

/* --- XIM / XIC input-method stubs (SDL handles IME). --- */

XIM
XOpenIM(Display *dpy, struct _XrmHashBucketRec *db, char *res_name,
	char *res_class)
{
    (void) dpy; (void) db; (void) res_name; (void) res_class;
    return NULL;
}

Status
XCloseIM(XIM im)
{
    (void) im;
    return 0;
}

char *
XGetIMValues(XIM im, ...)
{
    (void) im;
    return NULL;
}

char *
XSetIMValues(XIM im, ...)
{
    (void) im;
    return NULL;
}

char *
XGetICValues(XIC ic, ...)
{
    (void) ic;
    return NULL;
}

char *
XSetICValues(XIC ic, ...)
{
    (void) ic;
    return NULL;
}

void
XSetICFocus(XIC ic)
{
    (void) ic;
}

XVaNestedList
XVaCreateNestedList(int dummy, ...)
{
    (void) dummy;
    return NULL;
}

Bool
XRegisterIMInstantiateCallback(Display *dpy, struct _XrmHashBucketRec *db,
	char *res_name, char *res_class, XIDProc callback,
	XPointer client_data)
{
    (void) dpy; (void) db; (void) res_name; (void) res_class;
    (void) callback; (void) client_data;
    return False;
}

Bool
XUnregisterIMInstantiateCallback(Display *dpy, struct _XrmHashBucketRec *db,
	char *res_name, char *res_class, XIDProc callback,
	XPointer client_data)
{
    (void) dpy; (void) db; (void) res_name; (void) res_class;
    (void) callback; (void) client_data;
    return False;
}

char *
XSetLocaleModifiers(const char *modifier_list)
{
    (void) modifier_list;
    return (char *) "";
}

/* --- Font-set stubs. --- */

XFontSet
XCreateFontSet(Display *dpy, const char *base_font_name_list,
	char ***missing_charset_list, int *missing_charset_count,
	char **def_string)
{
    (void) dpy; (void) base_font_name_list;
    if (missing_charset_list) *missing_charset_list = NULL;
    if (missing_charset_count) *missing_charset_count = 0;
    if (def_string) *def_string = (char *) "";
    return NULL;
}

void
XFreeFontSet(Display *dpy, XFontSet font_set)
{
    (void) dpy; (void) font_set;
}

void
XFreeStringList(char **list)
{
    (void) list;
}

/* --- XKB stubs. --- */

extern KeySym SdlTkXKeycodeToKeysym(Display *display, unsigned int keycode,
	int index);

KeySym
XkbKeycodeToKeysym(Display *dpy, unsigned int kc, int group, int level)
{
    (void) group;
    return SdlTkXKeycodeToKeysym(dpy, kc, level);
}

Display *
XkbOpenDisplay(const char *display_name, int *event_rtrn, int *error_rtrn,
	int *major_rtrn, int *minor_rtrn, int *reason_rtrn)
{
    (void) display_name; (void) event_rtrn; (void) error_rtrn;
    (void) major_rtrn; (void) minor_rtrn;
    if (reason_rtrn) *reason_rtrn = 0;
    return NULL;
}
