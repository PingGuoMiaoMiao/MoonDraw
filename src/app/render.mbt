// Canvas rendering. Everything here takes an explicit `View`, so the same
// code draws the interactive canvas and the offscreen export canvas.

///|
pub fn set_font(ctx : Ctx, size : Double, weight : String) -> Unit {
  ffi_set_font(
    ctx,
    weight + " " + size.to_string() + "px -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif",
  )
}

///| Dot grid: 1px marks on a 20px lattice, drawn only when readable.
pub fn draw_grid(ctx : Ctx, v : @k.View, w : Double, h : Double) -> Unit {
  let step = 20.0 * v.zoom
  if step < 10.0 {
    return
  }
  ffi_set_fill(ctx, "#e0e0e0")
  let ox = v.cam_x - (v.cam_x / step).floor() * step
  let oy = v.cam_y - (v.cam_y / step).floor() * step
  let mut x = ox
  let mut drawn = 0
  while x < w && drawn < 200000 {
    let mut y = oy
    while y < h && drawn < 200000 {
      ffi_fill_rect(ctx, x, y, 1.0, 1.0)
      drawn = drawn + 1
      y = y + step
    }
    x = x + step
  }
}

///|
pub fn draw_arrow(
  ctx : Ctx,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Unit {
  let dx = x2 - x1
  let dy = y2 - y1
  let len = @k.sqrt_d(dx * dx + dy * dy)
  if len < 0.001 {
    return
  }
  let ux = dx / len
  let uy = dy / len
  let size = 9.0
  let bx = x2 - ux * size
  let by = y2 - uy * size
  let px = -uy * size * 0.45
  let py = ux * size * 0.45
  ffi_begin_path(ctx)
  ffi_move_to(ctx, x2, y2)
  ffi_line_to(ctx, bx + px, by + py)
  ffi_line_to(ctx, bx - px, by - py)
  ffi_close_path(ctx)
  ffi_fill(ctx)
}

///|
pub fn draw_edges(ctx : Ctx, v : @k.View, scene : @k.Scene) -> Unit {
  ffi_set_dash(ctx, false)
  for e in scene.edges {
    match (@k.find_shape(scene, e.from), @k.find_shape(scene, e.to)) {
      (Some(sa), Some(sb)) => {
        let pts = @k.route(sa, sb)
        ffi_set_stroke(ctx, "#a3a3a3")
        ffi_set_line_width(ctx, 1.6)
        ffi_begin_path(ctx)
        let mut first = true
        for p in pts {
          let x = @k.sx(v, p.0)
          let y = @k.sy(v, p.1)
          if first {
            ffi_move_to(ctx, x, y)
            first = false
          } else {
            ffi_line_to(ctx, x, y)
          }
        }
        ffi_stroke(ctx)
        let last = pts[pts.length() - 1]
        let prev = pts[pts.length() - 2]
        ffi_set_fill(ctx, "#a3a3a3")
        draw_arrow(
          ctx,
          @k.sx(v, prev.0),
          @k.sy(v, prev.1),
          @k.sx(v, last.0),
          @k.sy(v, last.1),
        )
        if e.label.length() > 0 {
          let mid = pts[1]
          let mid2 = pts[2]
          let lx = @k.sx(v, (mid.0 + mid2.0) * 0.5)
          let ly = @k.sy(v, (mid.1 + mid2.1) * 0.5)
          set_font(ctx, 12.0, "500")
          let tw = ffi_measure_text(ctx, e.label) + 14.0
          ffi_set_fill(ctx, "#ffffff")
          ffi_begin_path(ctx)
          ffi_round_rect(ctx, lx - tw * 0.5, ly - 10.0, tw, 20.0, 6.0)
          ffi_fill(ctx)
          ffi_set_fill(ctx, "#737373")
          ffi_set_text_align(ctx, "center")
          ffi_fill_text(ctx, e.label, lx, ly)
        }
      }
      _ => ()
    }
  }
}


///| Bar or line chart, drawn from the shape's `data` series.
fn draw_chart(ctx : Ctx, v : @k.View, s : @k.Shape) -> Unit {
  let x = @k.sx(v, s.x)
  let y = @k.sy(v, s.y)
  let w = s.w * v.zoom
  let h = s.h * v.zoom
  let n = s.data.length()
  if n == 0 {
    return
  }
  let maxv = @k.chart_max(s)
  let baseline = y + h
  // axes
  ffi_set_stroke(ctx, "#eaeaea")
  ffi_set_line_width(ctx, 1.0)
  ffi_begin_path(ctx)
  ffi_move_to(ctx, x, y)
  ffi_line_to(ctx, x, baseline)
  ffi_line_to(ctx, x + w, baseline)
  ffi_stroke(ctx)
  if @k.chart_type(s) == "line" {
    // polyline across the value points
    ffi_set_stroke(ctx, s.stroke)
    ffi_set_line_width(ctx, 2.0)
    ffi_begin_path(ctx)
    for i = 0; i < n; i = i + 1 {
      let px = if n == 1 {
        x
      } else {
        x + w * i.to_double() / (n - 1).to_double()
      }
      let py = baseline - s.data[i] / maxv * h * 0.92
      if i == 0 {
        ffi_move_to(ctx, px, py)
      } else {
        ffi_line_to(ctx, px, py)
      }
    }
    ffi_stroke(ctx)
  } else {
    // bars
    let slot = w / n.to_double()
    let bw = @k.maxd(slot * 0.62, 2.0)
    ffi_set_fill(ctx, s.fill)
    for i = 0; i < n; i = i + 1 {
      let bh = s.data[i] / maxv * h * 0.92
      let bx = x + slot * i.to_double() + (slot - bw) * 0.5
      ffi_fill_rect(ctx, bx, baseline - bh, bw, bh)
    }
  }
}

///| Freehand stroke: a polyline stored as [x0,y0,x1,y1,...].
fn draw_stroke(ctx : Ctx, v : @k.View, s : @k.Shape) -> Unit {
  let n = s.data.length()
  if n < 4 {
    return
  }
  ffi_set_stroke(ctx, s.stroke)
  ffi_set_line_width(ctx, 2.0 * v.zoom)
  ffi_begin_path(ctx)
  let mut i = 0
  while i + 1 < n {
    let px = @k.sx(v, s.data[i])
    let py = @k.sy(v, s.data[i + 1])
    if i == 0 {
      ffi_move_to(ctx, px, py)
    } else {
      ffi_line_to(ctx, px, py)
    }
    i = i + 2
  }
  ffi_stroke(ctx)
}

///|
pub fn draw_shape(ctx : Ctx, v : @k.View, s : @k.Shape) -> Unit {
  let x = @k.sx(v, s.x)
  let y = @k.sy(v, s.y)
  let w = s.w * v.zoom
  let h = s.h * v.zoom
  ffi_set_dash(ctx, false)
  ffi_set_line_width(ctx, 1.5)
  match s.kind {
    @k.Text => {
      ffi_set_fill(ctx, "#0070f3")
      set_font(ctx, 14.0 * v.zoom, "500")
      ffi_set_text_align(ctx, "center")
      ffi_fill_text(ctx, s.text, x + w * 0.5, y + h * 0.5)
      return
    }
    _ => ()
  }
  // Shapes that carry their own payload are drawn before the generic path.
  match s.kind {
    @k.Chart => {
      draw_chart(ctx, v, s)
      return
    }
    @k.Stroke => {
      draw_stroke(ctx, v, s)
      return
    }
    @k.GanttBar => {
      ffi_set_fill(ctx, s.fill)
      ffi_set_stroke(ctx, s.stroke)
      ffi_begin_path(ctx)
      ffi_round_rect(ctx, x, y, w, h, 4.0 * v.zoom)
      ffi_fill(ctx)
      ffi_stroke(ctx)
      return
    }
    _ => ()
  }
  ffi_set_fill(ctx, s.fill)
  ffi_set_stroke(ctx, s.stroke)
  match s.kind {
    @k.Round => {
      ffi_begin_path(ctx)
      ffi_round_rect(ctx, x, y, w, h, 9.0 * v.zoom)
      ffi_fill(ctx)
      ffi_stroke(ctx)
    }
    @k.Diamond => {
      ffi_begin_path(ctx)
      ffi_move_to(ctx, x + w * 0.5, y)
      ffi_line_to(ctx, x + w, y + h * 0.5)
      ffi_line_to(ctx, x + w * 0.5, y + h)
      ffi_line_to(ctx, x, y + h * 0.5)
      ffi_close_path(ctx)
      ffi_fill(ctx)
      ffi_stroke(ctx)
    }
    @k.Ellipse => {
      ffi_begin_path(ctx)
      ffi_ellipse(ctx, x + w * 0.5, y + h * 0.5, w * 0.5, h * 0.5)
      ffi_fill(ctx)
      ffi_stroke(ctx)
    }
    _ => {
      ffi_fill_rect(ctx, x, y, w, h)
      ffi_stroke_rect(ctx, x, y, w, h)
    }
  }
  if s.text.length() > 0 {
    ffi_set_fill(ctx, "#171717")
    set_font(ctx, 13.0 * v.zoom, "400")
    ffi_set_text_align(ctx, "center")
    ffi_fill_text(ctx, s.text, x + w * 0.5, y + h * 0.5)
  }
}

///|
pub fn draw_shapes(ctx : Ctx, v : @k.View, scene : @k.Scene) -> Unit {
  for s in scene.shapes {
    draw_shape(ctx, v, s)
  }
}

///| Draw the document itself: background, optional grid, edges, shapes.
pub fn draw_scene(
  ctx : Ctx,
  v : @k.View,
  scene : @k.Scene,
  w : Double,
  h : Double,
  grid : Bool,
) -> Unit {
  let bg = if grid { "#fafafa" } else { "#ffffff" }
  ffi_set_fill(ctx, bg)
  ffi_fill_rect(ctx, 0.0, 0.0, w, h)
  if grid {
    draw_grid(ctx, v, w, h)
  }
  draw_edges(ctx, v, scene)
  draw_shapes(ctx, v, scene)
}

///|
pub fn draw_overlay(ctx : Ctx, app : App) -> Unit {
  let v = app.view()
  // Highlight the selected connector.
  if app.sel_edge >= 0 {
    for e in app.scene.edges {
      if e.id == app.sel_edge {
        match (
            @k.find_shape(app.scene, e.from),
            @k.find_shape(app.scene, e.to),
          ) {
          (Some(a), Some(b)) => {
            let pts = @k.route(a, b)
            ffi_set_dash(ctx, false)
            ffi_set_stroke(ctx, "#0070f3")
            ffi_set_line_width(ctx, 3.0)
            ffi_begin_path(ctx)
            let mut first = true
            for p in pts {
              let x = @k.sx(v, p.0)
              let y = @k.sy(v, p.1)
              if first {
                ffi_move_to(ctx, x, y)
                first = false
              } else {
                ffi_line_to(ctx, x, y)
              }
            }
            ffi_stroke(ctx)
          }
          _ => ()
        }
      }
    }
  }
  // Alignment guides.
  if app.guides.length() > 0 {
    ffi_set_dash(ctx, true)
    ffi_set_stroke(ctx, "#ff0080")
    ffi_set_line_width(ctx, 1.0)
    for g in app.guides {
      ffi_begin_path(ctx)
      ffi_move_to(ctx, @k.sx(v, g.0), @k.sy(v, g.1))
      ffi_line_to(ctx, @k.sx(v, g.2), @k.sy(v, g.3))
      ffi_stroke(ctx)
    }
    ffi_set_dash(ctx, false)
  }
  // Selection outlines.
  ffi_set_dash(ctx, false)
  ffi_set_stroke(ctx, "#0070f3")
  ffi_set_line_width(ctx, 2.0)
  for id in app.sel {
    match @k.find_shape(app.scene, id) {
      Some(s) =>
        ffi_stroke_rect(
          ctx,
          @k.sx(v, s.x),
          @k.sy(v, s.y),
          s.w * v.zoom,
          s.h * v.zoom,
        )
      None => ()
    }
  }
  // Handles only make sense for a single selection.
  let primary = primary_id(app)
  if primary >= 0 {
    match @k.find_shape(app.scene, primary) {
      Some(s) => {
        ffi_set_fill(ctx, "#ffffff")
        for i = 0; i < 4; i = i + 1 {
          let p = @k.handle_pos(s, i)
          let hx = @k.sx(v, p.0)
          let hy = @k.sy(v, p.1)
          ffi_fill_rect(ctx, hx - 4.0, hy - 4.0, 8.0, 8.0)
          ffi_set_line_width(ctx, 1.5)
          ffi_stroke_rect(ctx, hx - 4.0, hy - 4.0, 8.0, 8.0)
        }
      }
      None => ()
    }
  }
  // Group outlines: one dashed box per group that owns a selected member.
  let seen_groups : Array[Int] = []
  for id in app.sel {
    match @k.find_shape(app.scene, id) {
      Some(s) =>
        if s.group != 0 && !seen_groups.contains(s.group) {
          seen_groups.push(s.group)
          match group_bounds(app, s.group) {
            Some(b) => {
              ffi_set_dash(ctx, true)
              ffi_set_stroke(ctx, "#a3a3a3")
              ffi_set_line_width(ctx, 1.0)
              ffi_begin_path(ctx)
              ffi_round_rect(
                ctx,
                @k.sx(v, b.0) - 6.0,
                @k.sy(v, b.1) - 6.0,
                (b.2 - b.0) * v.zoom + 12.0,
                (b.3 - b.1) * v.zoom + 12.0,
                4.0,
              )
              ffi_stroke(ctx)
              ffi_set_dash(ctx, false)
            }
            None => ()
          }
        }
      None => ()
    }
  }
  // Rubber band / connector preview.
  match app.drag {
    Band(ax, ay) => {
      let x1 = @k.sx(v, ax)
      let y1 = @k.sy(v, ay)
      let x2 = app.mx
      let y2 = app.my
      let bw = @k.absd(x2 - x1)
      let bh = @k.absd(y2 - y1)
      ffi_set_fill(ctx, "rgba(0,112,243,0.07)")
      ffi_fill_rect(ctx, @k.mind(x1, x2), @k.mind(y1, y2), bw, bh)
      ffi_set_stroke(ctx, "#0070f3")
      ffi_set_line_width(ctx, 1.0)
      ffi_stroke_rect(ctx, @k.mind(x1, x2), @k.mind(y1, y2), bw, bh)
    }
    Connect(id) =>
      match @k.find_shape(app.scene, id) {
        Some(s) => {
          ffi_set_dash(ctx, true)
          ffi_set_stroke(ctx, "#0070f3")
          ffi_set_line_width(ctx, 1.6)
          ffi_begin_path(ctx)
          ffi_move_to(ctx, @k.sx(v, @k.center_x(s)), @k.sy(v, @k.center_y(s)))
          ffi_line_to(ctx, app.mx, app.my)
          ffi_stroke(ctx)
          ffi_set_dash(ctx, false)
        }
        None => ()
      }
    _ => ()
  }
}

///|
pub fn render_all() -> Unit {
  let app = app_state
  let c = ffi_dom_canvas("board")
  let ctx = ffi_ctx(c)
  let w = ffi_client_width(c)
  let h = ffi_client_height(c)
  let dpr = ffi_dpr()
  ffi_ensure_size(c, w, h)
  ffi_reset_transform(ctx)
  ffi_scale(ctx, dpr, dpr)
  let v = app.view()
  draw_scene(ctx, v, app.scene, w, h, true)
  draw_overlay(ctx, app)
  let hint = if sel_count(app) > 0 {
    "已选中 " + app.sel.length().to_string() + " 个 · Delete 删除"
  } else {
    "拖拽移动 · 滚轮缩放 · 双击改文字"
  }
  ffi_hud(hint, (app.zoom * 100.0).to_int().to_string() + "%", app.scene.shapes.length() == 0)
  ffi_panel(selection_panel_json())
}

///| What part of the document an export covers.
pub enum ExportRange {
  All
  Selection
  Viewport
}

///|
pub fn range_from_name(name : String) -> ExportRange {
  if name == "selection" {
    Selection
  } else if name == "viewport" {
    Viewport
  } else {
    All
  }
}

///|
pub fn range_name(r : ExportRange) -> String {
  match r {
    All => "整图"
    Selection => "选区"
    Viewport => "视口"
  }
}

///| World-space rectangle an export covers, plus whether it is meaningful.
pub fn export_bounds(r : ExportRange) -> (Double, Double, Double, Double) {
  match r {
    Viewport => {
      let c = ffi_dom_canvas("board")
      let w = ffi_client_width(c)
      let h = ffi_client_height(c)
      let v = app_state.view()
      (@k.wx_of(v, 0.0), @k.wy_of(v, 0.0), @k.wx_of(v, w), @k.wy_of(v, h))
    }
    Selection => {
      let b = selection_bounds(app_state)
      if app_state.sel.length() == 0 {
        @k.scene_bounds(app_state.scene)
      } else {
        b
      }
    }
    All => @k.scene_bounds(app_state.scene)
  }
}

///| Render the requested part of the document into an offscreen canvas.
pub fn export_png_range(r : ExportRange, scale : Double) -> Unit {
  let scene = app_state.scene
  let c = ffi_dom_canvas("board")
  let cw = ffi_client_width(c)
  let ch = ffi_client_height(c)
  let is_vp = match r {
    Viewport => true
    _ => false
  }
  let pw = if is_vp { @k.maxd(cw * scale, 1.0) } else { 0.0 }
  let ph = if is_vp { @k.maxd(ch * scale, 1.0) } else { 0.0 }
  let b = export_bounds(r)
  let pad = match r {
    Viewport => 0.0
    _ => 48.0
  }
  let ww = @k.maxd(b.2 - b.0, 1.0) + pad * 2.0
  let wh = @k.maxd(b.3 - b.1, 1.0) + pad * 2.0
  let mut s = scale
  let limit = 8192.0
  if ww * s > limit || wh * s > limit {
    let fit = @k.mind(limit / ww, limit / wh)
    if fit < s {
      s = fit
    }
  }
  let out_w = if is_vp { pw } else { @k.maxd(ww * s, 1.0) }
  let out_h = if is_vp { ph } else { @k.maxd(wh * s, 1.0) }
  let canvas = ffi_new_canvas(out_w, out_h)
  let ctx = ffi_ctx(canvas)
  ffi_set_canvas_size(canvas, out_w, out_h, 1.0)
  ffi_reset_transform(ctx)
  let v = match r {
    // Viewport: what is on screen, just denser — same camera, scaled.
    Viewport => {
      let base = app_state.view()
      @k.View::{
        cam_x: base.cam_x * scale,
        cam_y: base.cam_y * scale,
        zoom: base.zoom * scale,
      }
    }
    _ =>
      @k.View::{
        cam_x: -b.0 * s + pad * s,
        cam_y: -b.1 * s + pad * s,
        zoom: s,
      }
  }
  draw_scene(ctx, v, scene, out_w, out_h, false)
  ffi_download_png(canvas, "moondraw-" + range_slug(r) + ".png")
  let msg = StringBuilder(size_hint=64)
  msg.write_string("已导出")
  msg.write_string(range_name(r))
  msg.write_string(" PNG · ")
  msg.write_string(out_w.to_int().to_string())
  msg.write_string("×")
  msg.write_string(out_h.to_int().to_string())
  ffi_status(msg.to_string())
}

///|
fn range_slug(r : ExportRange) -> String {
  match r {
    All => "all"
    Selection => "selection"
    Viewport => "viewport"
  }
}

///| Backwards-compatible whole-diagram export.
pub fn export_png(scale : Double) -> Unit {
  export_png_range(All, scale)
}
