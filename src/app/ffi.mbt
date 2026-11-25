// Canvas / DOM bindings for the JS backend.
//
// Everything below is a thin `extern "js"` wrapper: the MoonBit side never
// touches `document` directly, it goes through these declarations so the whole
// editor core stays free of JavaScript types.

///|
#external
pub type Canvas

///|
#external
pub type Ctx

///|
#external
pub type JsValue

///|
extern "js" fn ffi_dom_canvas(id : String) -> Canvas =
  #| (id) => document.getElementById(id)

///|
extern "js" fn ffi_ctx(c : Canvas) -> Ctx =
  #| (c) => c.getContext("2d")

///|
extern "js" fn ffi_dpr() -> Double =
  #| () => window.devicePixelRatio || 1

///|
extern "js" fn ffi_client_width(c : Canvas) -> Double =
  #| (c) => c.clientWidth

///|
extern "js" fn ffi_client_height(c : Canvas) -> Double =
  #| (c) => c.clientHeight

///|
extern "js" fn ffi_origin_x(c : Canvas) -> Double =
  #| (c) => c.getBoundingClientRect().left

///|
extern "js" fn ffi_origin_y(c : Canvas) -> Double =
  #| (c) => c.getBoundingClientRect().top

///|
///| Monotonic milliseconds; passed into the kernel benchmark.
pub extern "js" fn ffi_now() -> Double =
  #| () => performance.now()

///| Size the backing store to `css size * dpr` and keep it in sync.
extern "js" fn ffi_ensure_size(c : Canvas, w : Double, h : Double) -> Unit =
  #| (c, w, h) => {
  #|   const dpr = window.devicePixelRatio || 1;
  #|   const pw = Math.max(1, Math.round(w * dpr));
  #|   const ph = Math.max(1, Math.round(h * dpr));
  #|   if (c.width !== pw) c.width = pw;
  #|   if (c.height !== ph) c.height = ph;
  #| }

///|
extern "js" fn ffi_reset_transform(ctx : Ctx) -> Unit =
  #| (ctx) => ctx.setTransform(1, 0, 0, 1, 0, 0)

///|
extern "js" fn ffi_scale(ctx : Ctx, sx : Double, sy : Double) -> Unit =
  #| (ctx, sx, sy) => ctx.scale(sx, sy)

///|
extern "js" fn ffi_set_fill(ctx : Ctx, color : String) -> Unit =
  #| (ctx, color) => { ctx.fillStyle = color; }

///|
extern "js" fn ffi_set_stroke(ctx : Ctx, color : String) -> Unit =
  #| (ctx, color) => { ctx.strokeStyle = color; }

///|
extern "js" fn ffi_set_line_width(ctx : Ctx, w : Double) -> Unit =
  #| (ctx, w) => { ctx.lineWidth = w; }

///|
extern "js" fn ffi_set_dash(ctx : Ctx, on : Bool) -> Unit =
  #| (ctx, on) => ctx.setLineDash(on ? [6, 4] : [])

///|
extern "js" fn ffi_fill_rect(
  ctx : Ctx,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #| (ctx, x, y, w, h) => ctx.fillRect(x, y, w, h)

///|
extern "js" fn ffi_stroke_rect(
  ctx : Ctx,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #| (ctx, x, y, w, h) => ctx.strokeRect(x, y, w, h)

///|
extern "js" fn ffi_begin_path(ctx : Ctx) -> Unit =
  #| (ctx) => ctx.beginPath()

///|
extern "js" fn ffi_move_to(ctx : Ctx, x : Double, y : Double) -> Unit =
  #| (ctx, x, y) => ctx.moveTo(x, y)

///|
extern "js" fn ffi_line_to(ctx : Ctx, x : Double, y : Double) -> Unit =
  #| (ctx, x, y) => ctx.lineTo(x, y)

///|
extern "js" fn ffi_close_path(ctx : Ctx) -> Unit =
  #| (ctx) => ctx.closePath()

///|
extern "js" fn ffi_fill(ctx : Ctx) -> Unit =
  #| (ctx) => ctx.fill()

///|
extern "js" fn ffi_stroke(ctx : Ctx) -> Unit =
  #| (ctx) => ctx.stroke()

///|
extern "js" fn ffi_round_rect(
  ctx : Ctx,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  r : Double,
) -> Unit =
  #| (ctx, x, y, w, h, r) =>
  #|   ctx.roundRect(x, y, w, h, Math.max(0, Math.min(r, Math.min(w, h) / 2)))

///|
extern "js" fn ffi_ellipse(
  ctx : Ctx,
  x : Double,
  y : Double,
  rx : Double,
  ry : Double,
) -> Unit =
  #| (ctx, x, y, rx, ry) =>
  #|   ctx.ellipse(x, y, Math.max(0, rx), Math.max(0, ry), 0, 0, Math.PI * 2)

///|
extern "js" fn ffi_fill_text(
  ctx : Ctx,
  text : String,
  x : Double,
  y : Double,
) -> Unit =
  #| (ctx, text, x, y) => ctx.fillText(text, x, y)

///|
extern "js" fn ffi_measure_text(ctx : Ctx, text : String) -> Double =
  #| (ctx, text) => ctx.measureText(text).width

///|
extern "js" fn ffi_set_font(ctx : Ctx, font : String) -> Unit =
  #| (ctx, font) => { ctx.font = font; }

///|
extern "js" fn ffi_set_text_align(ctx : Ctx, align : String) -> Unit =
  #| (ctx, align) => {
  #|   ctx.textAlign = align;
  #|   ctx.textBaseline = "middle";
  #| }

///| Wire pointer / keyboard / resize events into MoonBit callbacks.
extern "js" fn ffi_attach(
  c : Canvas,
  on_down : (Double, Double, Int, Bool) -> Unit,
  on_move : (Double, Double) -> Unit,
  on_up : (Double, Double) -> Unit,
  on_dbl : (Double, Double) -> Unit,
  on_wheel : (Double, Double, Double) -> Unit,
  on_key : (String, Bool, Bool) -> Unit,
  on_resize : () -> Unit,
) -> Unit =
  #| (c, down, move, up, dbl, wheel, key, resize) => {
  #|   const pt = (e) => {
  #|     const r = c.getBoundingClientRect();
  #|     return [e.clientX - r.left, e.clientY - r.top];
  #|   };
  #|   c.addEventListener("mousedown", (e) => {
  #|     const [x, y] = pt(e);
  #|     down(x, y, e.button, e.shiftKey);
  #|     e.preventDefault();
  #|   });
  #|   window.addEventListener("mousemove", (e) => {
  #|     const [x, y] = pt(e);
  #|     move(x, y);
  #|   });
  #|   window.addEventListener("mouseup", (e) => {
  #|     const [x, y] = pt(e);
  #|     up(x, y);
  #|   });
  #|   c.addEventListener("dblclick", (e) => {
  #|     const [x, y] = pt(e);
  #|     dbl(x, y);
  #|   });
  #|   c.addEventListener("wheel", (e) => {
  #|     const [x, y] = pt(e);
  #|     wheel(x, y, e.deltaY);
  #|     e.preventDefault();
  #|   }, { passive: false });
  #|   window.addEventListener("keydown", (e) => {
  #|     const t = e.target;
  #|     if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
  #|     key(e.key, e.ctrlKey || e.metaKey, e.shiftKey);
  #|   });
  #|   window.addEventListener("resize", () => resize());
  #| }

///| A real DOM textarea floats above the canvas so Chinese IME composition
///| works exactly as in a native input (canvas has no IME support).
extern "js" fn ffi_open_editor(
  left : Double,
  top : Double,
  w : Double,
  h : Double,
  text : String,
  font : String,
  on_commit : (String) -> Unit,
) -> Unit =
  #| (left, top, w, h, text, font, commit) => {
  #|   let el = document.getElementById("inline-editor");
  #|   if (!el) {
  #|     el = document.createElement("textarea");
  #|     el.id = "inline-editor";
  #|     el.spellcheck = false;
  #|     document.body.appendChild(el);
  #|   }
  #|   el.value = text;
  #|   el.style.display = "block";
  #|   el.style.left = left + "px";
  #|   el.style.top = top + "px";
  #|   el.style.width = Math.max(80, w) + "px";
  #|   el.style.height = Math.max(30, h) + "px";
  #|   el.style.font = font;
  #|   el.focus();
  #|   el.select();
  #|   let done = false;
  #|   const finish = (ok) => {
  #|     if (done) return;
  #|     done = true;
  #|     const v = el.value;
  #|     el.style.display = "none";
  #|     el.onblur = null;
  #|     el.onkeydown = null;
  #|     if (ok) commit(v);
  #|   };
  #|   el.onblur = () => finish(true);
  #|   el.onkeydown = (e) => {
  #|     if (e.key === "Enter" && !e.shiftKey) {
  #|       e.preventDefault();
  #|       finish(true);
  #|     } else if (e.key === "Escape") {
  #|       e.preventDefault();
  #|       finish(false);
  #|     }
  #|     e.stopPropagation();
  #|   };
  #| }

///|
extern "js" fn ffi_editor_open() -> Bool =
  #| () => {
  #|   const el = document.getElementById("inline-editor");
  #|   return !!el && el.style.display === "block";
  #| }

///| Offscreen canvas used for whole-diagram export.
extern "js" fn ffi_new_canvas(w : Double, h : Double) -> Canvas =
  #| (w, h) => {
  #|   const c = document.createElement("canvas");
  #|   c.width = Math.max(1, Math.round(w));
  #|   c.height = Math.max(1, Math.round(h));
  #|   return c;
  #| }

///|
extern "js" fn ffi_set_canvas_size(
  c : Canvas,
  w : Double,
  h : Double,
  factor : Double,
) -> Unit =
  #| (c, w, h, factor) => {
  #|   c.width = Math.max(1, Math.round(w * factor));
  #|   c.height = Math.max(1, Math.round(h * factor));
  #| }

///| Open a local file and hand its text to MoonBit.
extern "js" fn ffi_open_file(
  accept : String,
  on_text : (String, String) -> Unit,
) -> Unit =
  #| (accept, cb) => {
  #|   const input = document.createElement("input");
  #|   input.type = "file";
  #|   input.accept = accept;
  #|   input.id = "file-input";
  #|   input.style.display = "none";
  #|   document.body.appendChild(input);
  #|   input.addEventListener("change", () => {
  #|     const f = input.files && input.files[0];
  #|     if (!f) { input.remove(); return; }
  #|     const reader = new FileReader();
  #|     reader.onload = () => {
  #|       input.remove();
  #|       cb(String(reader.result ?? ""), f.name);
  #|     };
  #|     reader.onerror = () => { input.remove(); };
  #|     reader.readAsText(f);
  #|   });
  #|   input.click();
  #| }

///|
extern "js" fn ffi_status(s : String) -> Unit =
  #| (s) => {
  #|   const el = document.getElementById("status");
  #|   if (el) el.textContent = s;
  #| }

///|
extern "js" fn ffi_local_get(key : String) -> String =
  #| (key) => {
  #|   try { return localStorage.getItem(key) ?? ""; } catch (_) { return ""; }
  #| }

///|
extern "js" fn ffi_local_set(key : String, value : String) -> Unit =
  #| (key, value) => {
  #|   try { localStorage.setItem(key, value); } catch (_) {}
  #| }

///|
extern "js" fn ffi_download_text(
  name : String,
  text : String,
  mime : String,
) -> Unit =
  #| (name, text, mime) => {
  #|   const blob = new Blob([text], { type: mime });
  #|   const url = URL.createObjectURL(blob);
  #|   const a = document.createElement("a");
  #|   a.href = url;
  #|   a.download = name;
  #|   document.body.appendChild(a);
  #|   a.click();
  #|   a.remove();
  #|   setTimeout(() => URL.revokeObjectURL(url), 2000);
  #| }

///|
extern "js" fn ffi_download_png(c : Canvas, name : String) -> Unit =
  #| (c, name) => {
  #|   const a = document.createElement("a");
  #|   a.href = c.toDataURL("image/png");
  #|   a.download = name;
  #|   document.body.appendChild(a);
  #|   a.click();
  #|   a.remove();
  #| }

///|
extern "js" fn ffi_parse_json(s : String) -> JsValue =
  #| (s) => {
  #|   try { return JSON.parse(s); } catch (_) { return null; }
  #| }

///|
extern "js" fn ffi_is_null(v : JsValue) -> Bool =
  #| (v) => v === null || v === undefined

///|
extern "js" fn ffi_get(v : JsValue, key : String) -> JsValue =
  #| (v, key) => v[key]

///|
extern "js" fn ffi_index(v : JsValue, i : Int) -> JsValue =
  #| (v, i) => v[i]

///|
extern "js" fn ffi_len(v : JsValue) -> Int =
  #| (v) => (v && v.length) ? v.length : 0

///|
extern "js" fn ffi_num(v : JsValue) -> Double =
  #| (v) => Number(v)

///|
extern "js" fn ffi_str(v : JsValue) -> String =
  #| (v) => String(v)

///|
extern "js" fn ffi_stringify(v : JsValue) -> String =
  #| (v) => {
  #|   try { return JSON.stringify(v); } catch (_) { return ""; }
  #| }

///|
extern "js" fn ffi_log(s : String) -> Unit =
  #| (s) => console.log(s)

///|
pub fn log(s : String) -> Unit {
  ffi_log(s)
}
