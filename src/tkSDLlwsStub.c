/*
 * tkSDLlwsStub.c --
 *
 *	No-op libwebsockets stubs.  The prebuilt libSDL2.a contains AndroWish's
 *	"wstiles" websocket headless video driver, whose object is pulled in via
 *	SDL's static driver table even though the Cocoa driver is what runs on
 *	macOS.  These stubs satisfy the linker; the driver is never activated,
 *	so the functions are never actually called.
 */

int   lws_callback_on_writable(void *wsi) { (void) wsi; return 0; }
void  lws_context_destroy(void *ctx) { (void) ctx; }
void *lws_context_user(void *ctx) { (void) ctx; return 0; }
void *lws_create_context(void *info) { (void) info; return 0; }
void *lws_get_context(void *wsi) { (void) wsi; return 0; }
int   lws_hdr_copy(void *wsi, char *dst, int len, int h) {
    (void) wsi; (void) dst; (void) len; (void) h; return 0;
}
int   lws_hdr_total_length(void *wsi, int h) { (void) wsi; (void) h; return 0; }
int   lws_return_http_status(void *wsi, unsigned code, const char *html) {
    (void) wsi; (void) code; (void) html; return 0;
}
int   lws_service(void *ctx, int timeout_ms) {
    (void) ctx; (void) timeout_ms; return 0;
}
void  lws_set_log_level(int level, void *log_emit) {
    (void) level; (void) log_emit;
}
void  lws_set_timeout(void *wsi, int reason, int secs) {
    (void) wsi; (void) reason; (void) secs;
}
int   lws_write(void *wsi, unsigned char *buf, unsigned long len, int prot) {
    (void) wsi; (void) buf; (void) len; (void) prot; return 0;
}

/*
 * libaom (AV1) stubs — SDL2 wstiles driver's tile encoder.  Unused with the
 * Cocoa video driver; present only to satisfy the linker.
 */
void *aom_codec_av1_cx(void) { return 0; }
int   aom_codec_control(void *a, int b, ...) { (void)a; (void)b; return 1; }
int   aom_codec_destroy(void *a) { (void)a; return 0; }
int   aom_codec_enc_config_default(void *a, void *b, unsigned c) { (void)a;(void)b;(void)c; return 1; }
int   aom_codec_enc_init_ver(void *a, void *b, void *c, long d, int e) { (void)a;(void)b;(void)c;(void)d;(void)e; return 1; }
int   aom_codec_encode(void *a, void *b, long c, unsigned long d, long e) { (void)a;(void)b;(void)c;(void)d;(void)e; return 1; }
const void *aom_codec_get_cx_data(void *a, void *b) { (void)a;(void)b; return 0; }
void *aom_img_alloc(void *a, unsigned b, unsigned c, unsigned d, unsigned e) { (void)a;(void)b;(void)c;(void)d;(void)e; return 0; }
void  aom_img_free(void *a) { (void)a; }
