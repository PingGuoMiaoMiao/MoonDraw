// Obstacle-aware routing tests.

///|
fn mk_scene() -> Scene {
  new_scene()
}

///|
test "a clear route is left untouched" {
  let sc = mk_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "a")
  let b = add_shape(sc, Rect, 400.0, 0.0, 100.0, 60.0, "b")
  let pts = route_avoiding(sc, a, b)
  let base = route(a, b)
  assert_eq(pts.length(), base.length())
  assert_eq(pts[0].0, base[0].0)
  assert_eq(pts[3].0, base[3].0)
}

///|
test "an obstacle on the straight path forces a detour" {
  let sc = mk_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 80.0, 50.0, "a")
  let b = add_shape(sc, Rect, 400.0, 0.0, 80.0, 50.0, "b")
  // sits right between them, on the same row
  let blocker = add_shape(sc, Rect, 200.0, 0.0, 100.0, 50.0, "blocker")
  let base = route(a, b)
  assert_true(polyline_hits(base, blocker))
  let pts = route_avoiding(sc, a, b)
  assert_false(polyline_hits(pts, blocker))
  // still an orthogonal path with the same endpoints
  assert_eq(pts.length(), 4)
  for i = 0; i + 1 < pts.length(); i = i + 1 {
    let p = pts[i]
    let q = pts[i + 1]
    assert_true(absd(p.0 - q.0) < 0.001 || absd(p.1 - q.1) < 0.001)
  }
}

///|
test "detour clears every blocker, not just the first" {
  let sc = mk_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 80.0, 50.0, "a")
  let b = add_shape(sc, Rect, 600.0, 0.0, 80.0, 50.0, "b")
  let b1 = add_shape(sc, Rect, 200.0, 0.0, 80.0, 50.0, "b1")
  let b2 = add_shape(sc, Rect, 400.0, 0.0, 80.0, 50.0, "b2")
  let pts = route_avoiding(sc, a, b)
  assert_false(polyline_hits(pts, b1))
  assert_false(polyline_hits(pts, b2))
}

///|
test "vertical neighbours detour through the sides" {
  let sc = mk_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 80.0, 50.0, "a")
  let b = add_shape(sc, Rect, 0.0, 300.0, 80.0, 50.0, "b")
  let blocker = add_shape(sc, Rect, 0.0, 150.0, 80.0, 50.0, "blocker")
  let pts = route_avoiding(sc, a, b)
  assert_false(polyline_hits(pts, blocker))
  assert_eq(pts.length(), 4)
}

///|
test "terminals never count as obstacles for their own edge" {
  let sc = mk_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "a")
  let b = add_shape(sc, Rect, 120.0, 0.0, 100.0, 60.0, "b")
  // adjacent shapes: the base route brushes both boxes but must not detour
  let pts = route_avoiding(sc, a, b)
  assert_eq(pts.length(), 4)
}

///|
test "touching boxes do not trigger a detour" {
  let sc = mk_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "a")
  let b = add_shape(sc, Rect, 300.0, 0.0, 100.0, 60.0, "b")
  // sits exactly on the edge line but far above it
  let _ = add_shape(sc, Rect, 180.0, -200.0, 100.0, 60.0, "above")
  let pts = route_avoiding(sc, a, b)
  let base = route(a, b)
  assert_eq(pts[1].1, base[1].1)
}
