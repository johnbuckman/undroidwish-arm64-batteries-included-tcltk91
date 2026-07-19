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
