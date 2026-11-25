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
