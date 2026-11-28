// Selection set, grid snapping and alignment guides.

// ---------------------------------------------------------------------------
// Selection
// ---------------------------------------------------------------------------

///|
pub fn sel_count(app : App) -> Int {
  app.sel.length()
}

///|
pub fn is_selected(app : App, id : Int) -> Bool {
  for v in app.sel {
    if v == id {
      return true
    }
  }
  false
}

///|
pub fn sel_clear(app : App) -> Unit {
  app.sel = []
  app.sel_edge = -1
}

///|
pub fn sel_only(app : App, id : Int) -> Unit {
  app.sel = [id]
  app.sel_edge = -1
}

///|
pub fn sel_add(app : App, id : Int) -> Unit {
  if !is_selected(app, id) {
    app.sel.push(id)
  }
  app.sel_edge = -1
}

///|
pub fn sel_toggle(app : App, id : Int) -> Unit {
  if is_selected(app, id) {
    let next : Array[Int] = []
    for v in app.sel {
      if v != id {
        next.push(v)
      }
    }
    app.sel = next
  } else {
    app.sel.push(id)
  }
  app.sel_edge = -1
}

///| The shape that owns the resize handles: only meaningful with one selection.
pub fn primary_id(app : App) -> Int {
  if app.sel.length() == 1 {
    app.sel[0]
  } else {
    -1
  }
}

///| Move every selected shape by (dx, dy) relative to its drag-start position.
pub fn move_selection(app : App, dx : Double, dy : Double) -> Unit {
  for item in app.drag_from {
    let (id, x0, y0) = item
    match @k.find_shape(app.scene, id) {
      Some(s) => {
        s.x = x0 + dx
        s.y = y0 + dy
      }
      None => ()
    }
  }
}

///| Bounding box of the selected shapes, or zeroes when nothing is selected.
pub fn selection_bounds(app : App) -> (Double, Double, Double, Double) {
  if app.sel.length() == 0 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  for id in app.sel {
    match @k.find_shape(app.scene, id) {
      Some(s) =>
        if first {
          min_x = s.x
          min_y = s.y
          max_x = s.x + s.w
          max_y = s.y + s.h
          first = false
        } else {
          min_x = @k.mind(min_x, s.x)
          min_y = @k.mind(min_y, s.y)
          max_x = @k.maxd(max_x, s.x + s.w)
          max_y = @k.maxd(max_y, s.y + s.h)
        }
      None => ()
    }
  }
  (min_x, min_y, max_x, max_y)
}

///| Shapes fully inside a world-space rectangle (rubber band).
pub fn shapes_in_rect(
  scene : @k.Scene,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Array[Int] {
  let lx = @k.mind(x1, x2)
  let ly = @k.mind(y1, y2)
  let hx = @k.maxd(x1, x2)
  let hy = @k.maxd(y1, y2)
  let out : Array[Int] = []
  for s in scene.shapes {
    if s.x >= lx && s.y >= ly && s.x + s.w <= hx && s.y + s.h <= hy {
      out.push(s.id)
    }
  }
  out
}

///| Topmost connector under a world point.
pub fn edge_at(scene : @k.Scene, x : Double, y : Double) -> @k.Edge? {
  let mut i = scene.edges.length() - 1
  while i >= 0 {
    let e = scene.edges[i]
    match (@k.find_shape(scene, e.from), @k.find_shape(scene, e.to)) {
      (Some(a), Some(b)) =>
        if @k.hit_polyline(@k.route_avoiding(scene, a, b), x, y) {
          return Some(e)
        }
      _ => ()
    }
    i = i - 1
  }
  None
}

///| Remove a connector by id.
pub fn remove_edge(scene : @k.Scene, id : Int) -> Unit {
  let kept : Array[@k.Edge] = []
  for e in scene.edges {
    if e.id != id {
      kept.push(e)
    }
  }
  scene.edges = kept
}

///| Delete the current selection (shapes and/or connector).
pub fn delete_selection(app : App) -> Bool {
  if app.sel.length() == 0 && app.sel_edge < 0 {
    return false
  }
  let ids = app.sel
  for id in ids {
    @k.remove_shape(app.scene, id)
  }
  if app.sel_edge >= 0 {
    remove_edge(app.scene, app.sel_edge)
  }
  sel_clear(app)
  app.drag = Idle
  app.drag_from = []
  true
}

// ---------------------------------------------------------------------------
// Snapping and alignment guides
// ---------------------------------------------------------------------------

///|
pub fn snap_to(v : Double, step : Double) -> Double {
  if step <= 0.0 {
    return v
  }
  (v / step).round() * step
}

///| Snap a world point to the grid (grid step is 8 world units by default).
pub fn snap_point(app : App, x : Double, y : Double) -> (Double, Double) {
  let step = if app.zoom < 0.6 { 0.0 } else { 8.0 }
  (snap_to(x, step), snap_to(y, step))
}

///| Snap a moving box to nearby shape edges and centers, returning the
///| adjustment plus the guide lines to draw.
pub fn align_box(
  app : App,
  box : (Double, Double, Double, Double),
  tol : Double,
) -> (Double, Double, Array[(Double, Double, Double, Double)]) {
  let bl = box.0
  let bt = box.1
  let br = box.2
  let bb = box.3
  let bcx = (bl + br) * 0.5
  let bcy = (bt + bb) * 0.5
  let mut best_dx = tol + 1.0
  let mut best_dy = tol + 1.0
  let mut gx = 0.0
  let mut gy = 0.0
  let mut gx_from = 0.0
  let mut gx_to = 0.0
  let mut gy_from = 0.0
  let mut gy_to = 0.0
  let mut has_x = false
  let mut has_y = false
  for s in app.scene.shapes {
    if is_selected(app, s.id) {
      continue
    }
    let sl = s.x
    let sr = s.x + s.w
    let scx = sl + s.w * 0.5
    let st = s.y
    let sb = s.y + s.h
    let scy = st + s.h * 0.5
    // Vertical guides: match left / center / right.
    for pair in [(bl, sl), (bcx, scx), (br, sr)] {
      let delta = pair.1 - pair.0
      if @k.absd(delta) <= tol && @k.absd(delta) < @k.absd(best_dx) {
        best_dx = delta
        gx = pair.1
        gx_from = @k.mind(bt, st)
        gx_to = @k.maxd(bb, sb)
        has_x = true
      }
    }
    // Horizontal guides: match top / middle / bottom.
    for pair in [(bt, st), (bcy, scy), (bb, sb)] {
      let delta = pair.1 - pair.0
      if @k.absd(delta) <= tol && @k.absd(delta) < @k.absd(best_dy) {
        best_dy = delta
        gy = pair.1
        gy_from = @k.mind(bl, sl)
        gy_to = @k.maxd(br, sr)
        has_y = true
      }
    }
  }
  let guides : Array[(Double, Double, Double, Double)] = []
  if has_x {
    guides.push((gx, gx_from - 20.0, gx, gx_to + 20.0))
  }
  if has_y {
    guides.push((gy_from - 20.0, gy, gy_to + 20.0, gy))
  }
  let dx = if has_x { best_dx } else { 0.0 }
  let dy = if has_y { best_dy } else { 0.0 }
  (dx, dy, guides)
}

// ---------------------------------------------------------------------------
// Grouping: shapes sharing a non-zero group id select and move together.
// ---------------------------------------------------------------------------

///| Highest group id in the document (0 when nothing is grouped).
pub fn max_group(scene : @k.Scene) -> Int {
  let mut top = 0
  for s in scene.shapes {
    if s.group > top {
      top = s.group
    }
  }
  top
}

///| Select every shape that belongs to the same group as id.
pub fn expand_to_group(app : App, id : Int) -> Unit {
  match @k.find_shape(app.scene, id) {
    Some(s) =>
      if s.group != 0 {
        for other in app.scene.shapes {
          if other.group == s.group && !is_selected(app, other.id) {
            app.sel.push(other.id)
          }
        }
      }
    None => ()
  }
}

///| Put the current selection into a new group.
pub fn group_selection(app : App) -> Bool {
  if app.sel.length() < 2 {
    return false
  }
  let gid = max_group(app.scene) + 1
  for s in app.scene.shapes {
    if is_selected(app, s.id) {
      s.set_group(gid)
    }
  }
  true
}

///| Remove the selection from its groups.
pub fn ungroup_selection(app : App) -> Bool {
  let mut changed = false
  for s in app.scene.shapes {
    if is_selected(app, s.id) && s.group != 0 {
      s.set_group(0)
      changed = true
    }
  }
  changed
}

///| Bounding box of one group, or None when the id is unknown.
pub fn group_bounds(app : App, gid : Int) -> (Double, Double, Double, Double)? {
  if gid == 0 {
    return None
  }
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  for s in app.scene.shapes {
    if s.group == gid {
      if first {
        min_x = s.x
        min_y = s.y
        max_x = s.x + s.w
        max_y = s.y + s.h
        first = false
      } else {
        min_x = @k.mind(min_x, s.x)
        min_y = @k.mind(min_y, s.y)
        max_x = @k.maxd(max_x, s.x + s.w)
        max_y = @k.maxd(max_y, s.y + s.h)
      }
    }
  }
  if first {
    None
  } else {
    Some((min_x, min_y, max_x, max_y))
  }
}
