///|
pub fn absd(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
pub fn mind(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn maxd(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///| Newton iteration, keeps the core free of math imports.
pub fn sqrt_d(x : Double) -> Double {
  if x <= 0.0 {
    return 0.0
  }
  let mut r = if x < 1.0 { 1.0 } else { x }
  for i = 0; i < 28; i = i + 1 {
    r = (r + x / r) * 0.5
  }
  r
}

///|
pub fn center_x(s : Shape) -> Double {
  s.x + s.w * 0.5
}

///|
pub fn center_y(s : Shape) -> Double {
  s.y + s.h * 0.5
}

///| Point-in-shape test in world coordinates.
pub fn hit_shape(s : Shape, x : Double, y : Double) -> Bool {
  let cx = center_x(s)
  let cy = center_y(s)
  let hw = maxd(s.w * 0.5, 1.0)
  let hh = maxd(s.h * 0.5, 1.0)
  match s.kind {
    Diamond => {
      let dx = absd(x - cx) / hw
      let dy = absd(y - cy) / hh
      dx + dy <= 1.12
    }
    Ellipse => {
      let dx = (x - cx) / hw
      let dy = (y - cy) / hh
      dx * dx + dy * dy <= 1.12
    }
    _ => x >= s.x && x <= s.x + s.w && y >= s.y && y <= s.y + s.h
  }
}

///| Corner handle position (0 TL, 1 TR, 2 BL, 3 BR) in world coordinates.
pub fn handle_pos(s : Shape, i : Int) -> (Double, Double) {
  let left = s.x
  let right = s.x + s.w
  let top = s.y
  let bottom = s.y + s.h
  match i {
    0 => (left, top)
    1 => (right, top)
    2 => (left, bottom)
    _ => (right, bottom)
  }
}

///| Orthogonal connector route between two shapes, in world coordinates.
pub fn route(a : Shape, b : Shape) -> Array[(Double, Double)] {
  let acx = center_x(a)
  let acy = center_y(a)
  let bcx = center_x(b)
  let bcy = center_y(b)
  let dx = bcx - acx
  let dy = bcy - acy
  if absd(dx) >= absd(dy) {
    if dx >= 0.0 {
      let sx = a.x + a.w
      let ex = b.x
      let mx = (sx + ex) * 0.5
      [(sx, acy), (mx, acy), (mx, bcy), (ex, bcy)]
    } else {
      let sx = a.x
      let ex = b.x + b.w
      let mx = (sx + ex) * 0.5
      [(sx, acy), (mx, acy), (mx, bcy), (ex, bcy)]
    }
  } else {
    if dy >= 0.0 {
      let sy = a.y + a.h
      let ey = b.y
      let my = (sy + ey) * 0.5
      [(acx, sy), (acx, my), (bcx, my), (bcx, ey)]
    } else {
      let sy = a.y
      let ey = b.y + b.h
      let my = (sy + ey) * 0.5
      [(acx, sy), (acx, my), (bcx, my), (bcx, ey)]
    }
  }
}


// ---------------------------------------------------------------------------
// Obstacle-aware routing
//
// The plain `route` above connects two shapes with a 3-segment orthogonal path.
// It ignores everything in between, so a cross-layer edge can cut straight
// through an unrelated node. draw.io solves this with libavoid; this is a
// deliberately small substitute: detect the first obstacle on the straight
// segment and detour around it with one extra jog.
// ---------------------------------------------------------------------------

///| Does an axis-aligned box strictly overlap the open segment a->b?
///| Rectangles that merely touch the endpoints are ignored.
fn segment_hits_box(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  box : Shape,
) -> Bool {
  let pad = 6.0
  let lx = box.x - pad
  let ty = box.y - pad
  let rx = box.x + box.w + pad
  let by2 = box.y + box.h + pad
  let min_x = mind(ax, bx)
  let max_x = maxd(ax, bx)
  let min_y = mind(ay, by)
  let max_y = maxd(ay, by)
  // No overlap of the bounding boxes means no intersection.
  if max_x < lx || min_x > rx || max_y < ty || min_y > by2 {
    return false
  }
  // The segment must actually pass *through* the box interior, not merely
  // share a bounding-box corner (degenerate zero-length segments included).
  let seg_is_horizontal = absd(ay - by) < 0.001
  let seg_is_vertical = absd(ax - bx) < 0.001
  if seg_is_horizontal {
    return ay > ty && ay < by2 && max_x > lx && min_x < rx
  }
  if seg_is_vertical {
    return ax > lx && ax < rx && max_y > ty && min_y < by2
  }
  // Diagonal (shouldn't happen for orthogonal routes, but stay correct).
  let cx = clampd((min_x + max_x) * 0.5, lx + 0.5, rx - 0.5)
  let cy = clampd((min_y + max_y) * 0.5, ty + 0.5, by2 - 0.5)
  cx > lx && cx < rx && cy > ty && cy < by2
}

///|
fn point_in(x : Double, y : Double, s : Shape) -> Bool {
  x >= s.x && x <= s.x + s.w && y >= s.y && y <= s.y + s.h
}

///| True when any interior point of the polyline falls inside `box`.
fn polyline_hits(pts : Array[(Double, Double)], box : Shape) -> Bool {
  for i = 0; i + 1 < pts.length(); i = i + 1 {
    let a = pts[i]
    let b = pts[i + 1]
    if segment_hits_box(a.0, a.1, b.0, b.1, box) {
      return true
    }
  }
  false
}

///| Route a -> b while avoiding unrelated shapes.
///
/// Strategy, cheapest first:
/// 1. the plain orthogonal route, if it is clear;
/// 2. a detour that shifts the middle leg to the left or right of everything
///    in between;
/// 3. the plain route (accept the crossing rather than lose the edge).
pub fn route_avoiding(
  scene : Scene,
  a : Shape,
  b : Shape,
) -> Array[(Double, Double)] {
  let base = route(a, b)
  // Collect obstacles that actually block the base path.
  let blockers : Array[Shape] = []
  for s in scene.shapes {
    if s.id == a.id || s.id == b.id {
      continue
    }
    if polyline_hits(base, s) {
      blockers.push(s)
    }
  }
  if blockers.length() == 0 {
    return base
  }
  // Compute a detour corridor that clears every blocker on the side we pick.
  let acx = center_x(a)
  let bcx = center_x(b)
  let horizontal = absd(bcx - acx) >= absd(center_y(b) - center_y(a))
  if horizontal {
    // Shift the vertical middle leg above or below all blockers.
    let mut top = a.y
    let mut bottom = a.y + a.h
    for s in blockers {
      top = mind(top, s.y)
      bottom = maxd(bottom, s.y + s.h)
    }
    let above = top - 24.0
    let below = bottom + 24.0
    // Try the side that is closer to the straight line between centres.
    let mid_y = (center_y(a) + center_y(b)) * 0.5
    let use_above = absd(above - mid_y) <= absd(below - mid_y)
    let lane = if use_above { above } else { below }
    let sx = acx
    let ex = bcx
    let sy = if use_above { a.y } else { a.y + a.h }
    let ey = if use_above { b.y } else { b.y + b.h }
    return [(sx, sy), (sx, lane), (ex, lane), (ex, ey)]
  }
  let mut left = a.x
  let mut right = a.x + a.w
  for s in blockers {
    left = mind(left, s.x)
    right = maxd(right, s.x + s.w)
  }
  let far_left = left - 24.0
  let far_right = right + 24.0
  let mid_x = (center_x(a) + center_x(b)) * 0.5
  let use_left = absd(far_left - mid_x) <= absd(far_right - mid_x)
  let lane = if use_left { far_left } else { far_right }
  let sy = center_y(a)
  let ey = center_y(b)
  let sx = if use_left { a.x } else { a.x + a.w }
  let ex = if use_left { b.x } else { b.x + b.w }
  [(sx, sy), (lane, sy), (lane, ey), (ex, ey)]
}

///| Squared distance from a point to a segment.
pub fn seg_dist2(
  px : Double,
  py : Double,
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
) -> Double {
  let vx = bx - ax
  let vy = by - ay
  let wx = px - ax
  let wy = py - ay
  let len2 = vx * vx + vy * vy
  if len2 <= 0.0001 {
    return wx * wx + wy * wy
  }
  let mut t = (wx * vx + wy * vy) / len2
  if t < 0.0 {
    t = 0.0
  }
  if t > 1.0 {
    t = 1.0
  }
  let qx = ax + vx * t
  let qy = ay + vy * t
  let dx = px - qx
  let dy = py - qy
  dx * dx + dy * dy
}

///| Returns the topmost shape under a world point, or None.
pub fn shape_at(scene : Scene, x : Double, y : Double) -> Shape? {
  let mut i = scene.shapes.length() - 1
  while i >= 0 {
    let s = scene.shapes[i]
    if hit_shape(s, x, y) {
      return Some(s)
    }
    i = i - 1
  }
  None
}

///| Whether a world point is close enough to an edge polyline.
pub fn hit_polyline(pts : Array[(Double, Double)], x : Double, y : Double) -> Bool {
  let tol2 = 64.0
  let n = pts.length()
  for i = 0; i < n - 1; i = i + 1 {
    let a = pts[i]
    let b = pts[i + 1]
    if seg_dist2(x, y, a.0, a.1, b.0, b.1) <= tol2 {
      return true
    }
  }
  false
}
