// Pure-logic tests for the editor core. These run on the JS backend
// (`moon test`) and touch no DOM.

///|
test "hit testing: rectangle" {
  let sc = new_scene()
  let s = add_shape(sc, Rect, 100.0, 100.0, 120.0, 60.0, "")
  assert_true(hit_shape(s, 100.0, 100.0))
  assert_true(hit_shape(s, 160.0, 130.0))
  assert_true(hit_shape(s, 220.0, 160.0))
  assert_false(hit_shape(s, 99.0, 130.0))
  assert_false(hit_shape(s, 221.0, 130.0))
}

///|
test "hit testing: diamond and ellipse exclude corners" {
  let sc = new_scene()
  let d = add_shape(sc, Diamond, 0.0, 0.0, 100.0, 100.0, "")
  assert_true(hit_shape(d, 50.0, 50.0))
  assert_false(hit_shape(d, 2.0, 2.0))
  let e = add_shape(sc, Ellipse, 0.0, 0.0, 100.0, 100.0, "")
  assert_true(hit_shape(e, 50.0, 50.0))
  assert_false(hit_shape(e, 2.0, 2.0))
}

///|
test "topmost shape wins" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 0.0, 0.0, 100.0, 100.0, "bottom")
  let _ = add_shape(sc, Rect, 50.0, 50.0, 100.0, 100.0, "top")
  match shape_at(sc, 60.0, 60.0) {
    Some(s) => assert_eq(s.text, "top")
    None => fail("expected a shape")
  }
  match shape_at(sc, 900.0, 900.0) {
    Some(_) => fail("expected nothing")
    None => ()
  }
}

///|
test "orthogonal routing stays on shape borders" {
  let sc = new_scene()
  let a = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "")
  let b = add_shape(sc, Rect, 400.0, 200.0, 100.0, 60.0, "")
  let pts = route(a, b)
  assert_eq(pts.length(), 4)
  let start = pts[0]
  let stop = pts[3]
  // Leaves a from its right edge, enters b on its left edge.
  assert_true(absd(start.0 - 100.0) < 0.001)
  assert_true(absd(start.1 - 30.0) < 0.001)
  assert_true(absd(stop.0 - 400.0) < 0.001)
  assert_true(absd(stop.1 - 230.0) < 0.001)
  // All segments are axis-aligned.
  for i = 0; i < 3; i = i + 1 {
    let p = pts[i]
    let q = pts[i + 1]
    assert_true(absd(p.0 - q.0) < 0.001 || absd(p.1 - q.1) < 0.001)
  }
}

///|
test "routing flips for a shape on the left" {
  let sc = new_scene()
  let a = add_shape(sc, Rect, 400.0, 0.0, 100.0, 60.0, "")
  let b = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "")
  let pts = route(a, b)
  assert_true(absd(pts[0].0 - 400.0) < 0.001)
  assert_true(absd(pts[3].0 - 100.0) < 0.001)
}

///|
test "segment distance" {
  assert_true(seg_dist2(5.0, 5.0, 0.0, 0.0, 10.0, 0.0) > 24.0)
  assert_true(seg_dist2(5.0, 1.0, 0.0, 0.0, 10.0, 0.0) < 1.1)
  assert_true(seg_dist2(-3.0, 0.0, 0.0, 0.0, 10.0, 0.0) > 8.0)
}

///|
test "delete removes attached edges" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = add_shape(sc, Rect, 300.0, 0.0, 100.0, 60.0, "")
  let _ = add_edge(sc, 1, 2, "x")
  assert_eq(sc.edges.length(), 1)
  remove_shape(sc, 1)
  assert_eq(sc.shapes.length(), 1)
  assert_eq(sc.edges.length(), 0)
}

///|
test "shape kind name round-trip" {
  for k in [Rect, Round, Diamond, Ellipse, Text] {
    assert_eq(kind_name(kind_from_name(kind_name(k))), kind_name(k))
  }
}

///|
test "svg export contains every shape and escaped text" {
  let sc = new_scene()
  let _ = add_shape(sc, Round, 0.0, 0.0, 100.0, 40.0, "开始")
  let _ = add_shape(sc, Diamond, 200.0, 0.0, 100.0, 60.0, "a<b")
  let _ = add_edge(sc, 1, 2, "yes")
  let svg = scene_to_svg(sc)
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("开始"))
  assert_true(svg.contains("a&lt;b"))
  assert_true(svg.contains("<polyline"))
  assert_true(svg.contains("<polygon"))
  assert_true(svg.contains("</svg>"))
}
