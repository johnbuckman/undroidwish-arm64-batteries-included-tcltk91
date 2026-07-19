/* Force-included when building old extensions against Tcl/Tk 9.1:
 * restores macros Tk 9 removed. */
#ifndef _EXT_COMPAT91_H
#define _EXT_COMPAT91_H
#include <stddef.h>
#ifndef CONST
#define CONST const
#endif
#ifndef CONST84
#define CONST84 const
#endif
#ifndef CONST86
#define CONST86 const
#endif
#ifndef _CONST
#define _CONST const
#endif
#ifndef VOID
#define VOID void
#endif
#ifndef _ANSI_ARGS_
#define _ANSI_ARGS_(x) x
#endif
#ifndef Tk_Offset
#define Tk_Offset(type, field) offsetof(type, field)
#endif
#ifndef Tcl_Offset
#define Tcl_Offset(type, field) offsetof(type, field)
#endif
#endif

/* Tk 9 made Tk_ConfigureWidget object-based. buildext.sh rewrites extension
 * calls to this string-based shim (defined+exported by the wish). */
extern int Uw_TkConfigureWidgetStr(void *interp, void *tkwin,
	const void *specs, long argc, const char **argv, void *rec, int flags);

/* The wish implements the X region API internally as XCreateRegion() etc.
 * (Region.c) but only EXPORTS the SdlTk* variants (SdlTkXRegionFuncs).
 * Map the plain names to the exported ones so extensions that use X regions
 * (e.g. tkvnc) resolve at load time.  Applied before the SDL Xutil.h decls,
 * so both the prototypes and the call sites get rewritten. */
#define XCreateRegion          SdlTkXCreateRegion
#define XDestroyRegion         SdlTkXDestroyRegion
#define XSetRegion             SdlTkXSetRegion
#define XUnionRectWithRegion   SdlTkXUnionRectWithRegion
#define XIntersectRegion       SdlTkXIntersectRegion
#define XUnionRegion           SdlTkXUnionRegion
#define XSubtractRegion        SdlTkXSubtractRegion
#define XOffsetRegion          SdlTkXOffsetRegion
#define XPointInRegion         SdlTkXPointInRegion
#define XRectInRegion          SdlTkXRectInRegion
#define XEmptyRegion           SdlTkXEmptyRegion
#define XClipBox               SdlTkXClipBox
