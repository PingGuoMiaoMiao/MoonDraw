// Arrange operations on the current selection: distribute horizontally or
// vertically with equal edge-to-edge gaps. The two extreme shapes stay put.

///|
fn collect_selected(app : App) -> Array[@k.Shape] {
  let out : Array[@k.Shape] = []
  for id in app.sel {
    match @k.find_shape(app.scene, id) {
      Some(s) => out.push(s)
      None => ()
    }
  }
  out
}

///| Stable insertion sort of shapes by a key.
fn sort_by(shapes : Array[@k.Shape], horiz : Bool) -> Array[@k.Shape] {
  let out : Array[@k.Shape] = []
  for s in shapes {
    let key = if horiz { @k.center_x(s) } else { @k.center_y(s) }
    let mut pos = out.length()
    while pos > 0 {
      let prev = out[pos - 1]
      let prev_key = if horiz { @k.center_x(prev) } else { @k.center_y(prev) }
      if prev_key <= key {
        break
      }
      pos = pos - 1
    }
    out.insert(pos, s)
  }
  out
}

///|
fn distribute_axis(app : App, horiz : Bool) -> Bool {
  let picked = collect_selected(app)
  if picked.length() < 3 {
    return false
  }
  let sorted = sort_by(picked, horiz)
  let n = sorted.length()
  let first = sorted[0]
  let last = sorted[n - 1]
  let start = if horiz { first.x } else { first.y }
  let end = if horiz { last.x + last.w } else { last.y + last.h }
  let mut total = 0.0
  for s in sorted {
    total = total + (if horiz { s.w } else { s.h })
  }
  let mut gap = (end - start - total) / (n - 1).to_double()
  if gap < 0.0 {
    gap = 0.0
  }
  let mut cursor = start
  for s in sorted {
    if horiz {
      s.x = cursor
      cursor = cursor + s.w + gap
    } else {
      s.y = cursor
      cursor = cursor + s.h + gap
    }
  }
  true
}

///| Equal horizontal gaps between the selected shapes (needs 3+).
pub fn distribute_h(app : App) -> Bool {
  distribute_axis(app, true)
}

///| Equal vertical gaps between the selected shapes (needs 3+).
pub fn distribute_v(app : App) -> Bool {
  distribute_axis(app, false)
}

///| Gaps between consecutive shapes, used by tests and status messages.
pub fn gaps_h(app : App) -> Array[Double] {
  let sorted = sort_by(collect_selected(app), true)
  let out : Array[Double] = []
  for i = 0; i + 1 < sorted.length(); i = i + 1 {
    let a = sorted[i]
    let b = sorted[i + 1]
    out.push(b.x - (a.x + a.w))
  }
  out
}

///|
pub fn gaps_v(app : App) -> Array[Double] {
  let sorted = sort_by(collect_selected(app), false)
  let out : Array[Double] = []
  for i = 0; i + 1 < sorted.length(); i = i + 1 {
    let a = sorted[i]
    let b = sorted[i + 1]
    out.push(b.y - (a.y + a.h))
  }
  out
}

// ---------------------------------------------------------------------------
// Alignment and stacking order (selection based)
// ---------------------------------------------------------------------------

///| Align every selected shape to the selection box edge or centre.
///| mode: left | hcenter | right | top | vcenter | bottom
pub fn align_selection(app : App, mode : String) -> Bool {
  let picked = collect_selected(app)
  if picked.length() < 2 {
    return false
  }
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  for s in picked {
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
  let cx = (min_x + max_x) * 0.5
  let cy = (min_y + max_y) * 0.5
  for s in picked {
    match mode {
      "left" => s.x = min_x
      "hcenter" => s.x = cx - s.w * 0.5
      "right" => s.x = max_x - s.w
      "top" => s.y = min_y
      "vcenter" => s.y = cy - s.h * 0.5
      "bottom" => s.y = max_y - s.h
      _ => ()
    }
  }
  true
}

///| Reorder the selection in the stacking order.
///| op: front | back | forward | backward
pub fn layer_op(app : App, op : String) -> Bool {
  if app.sel.length() == 0 {
    return false
  }
  let shapes = app.scene.shapes
  let n = shapes.length()
  if n < 2 {
    return false
  }
  match op {
    "front" => {
      let rest : Array[@k.Shape] = []
      let picked : Array[@k.Shape] = []
      for s in shapes {
        if is_selected(app, s.id) {
          picked.push(s)
        } else {
          rest.push(s)
        }
      }
      for s in picked {
        rest.push(s)
      }
      app.scene.shapes = rest
    }
    "back" => {
      let rest : Array[@k.Shape] = []
      let picked : Array[@k.Shape] = []
      for s in shapes {
        if is_selected(app, s.id) {
          picked.push(s)
        } else {
          rest.push(s)
        }
      }
      let out : Array[@k.Shape] = []
      for s in picked {
        out.push(s)
      }
      for s in rest {
        out.push(s)
      }
      app.scene.shapes = out
    }
    "forward" => {
      // move one step up, from the top down
      let mut i = n - 2
      while i >= 0 {
        let cur = app.scene.shapes[i]
        if is_selected(app, cur.id) && !is_selected(app, app.scene.shapes[i + 1].id) {
          let top = app.scene.shapes[i + 1]
          app.scene.shapes[i + 1] = cur
          app.scene.shapes[i] = top
        }
        i = i - 1
      }
    }
    "backward" => {
      let mut i = 1
      while i < n {
        let cur = app.scene.shapes[i]
        if is_selected(app, cur.id) && !is_selected(app, app.scene.shapes[i - 1].id) {
          let below = app.scene.shapes[i - 1]
          app.scene.shapes[i - 1] = cur
          app.scene.shapes[i] = below
        }
        i = i + 1
      }
    }
    _ => return false
  }
  true
}
