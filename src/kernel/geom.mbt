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
