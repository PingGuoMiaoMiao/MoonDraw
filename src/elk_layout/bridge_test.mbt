// Bridge tests: JSON shape, and a real ELK run that must move nodes.

///|
test "elk json carries algorithm, children and edges" {
  let sc = @k.new_scene()
  let a = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 120.0, 60.0, "a")
  let b = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 120.0, 60.0, "b")
  let _ = @k.add_edge(sc, a.id, b.id, "")
  let json = scene_to_elk_json(sc, "layered", "DOWN")
  assert_true(json.contains("\"elk.algorithm\":\"layered\""))
  assert_true(json.contains("\"elk.direction\":\"DOWN\""))
  assert_true(json.contains("\"id\":\"n1\""))
  assert_true(json.contains("\"width\":120"))
  assert_true(json.contains("\"sources\":[\"n1\"]"))
  assert_true(json.contains("\"targets\":[\"n2\"]"))
}

///|
test "elk json skips zero-sized placeholder shapes" {
  let sc = @k.new_scene()
  let _ = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 0.0, 0.0, "empty")
  let json = scene_to_elk_json(sc, "layered", "DOWN")
  assert_false(json.contains("\"id\":\"n1\""))
}

///|
test "layered layout puts the target below the source" {
  let sc = @k.new_scene()
  let a = @k.add_shape(sc, @k.Rect, 300.0, 300.0, 120.0, 60.0, "a")
  let b = @k.add_shape(sc, @k.Rect, 20.0, 20.0, 120.0, 60.0, "b")
  let _ = @k.add_edge(sc, a.id, b.id, "")
  let err = layout_with_elk(sc, "layered", "DOWN")
  assert_eq(err, "")
  // a -> b with DOWN direction: b strictly below a, and both moved off the
  // hand-placed coordinates.
  assert_true(b.y > a.y)
  assert_true(a.y < 300.0)
}

///|
test "right direction swaps the axis" {
  let sc = @k.new_scene()
  let a = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 120.0, 60.0, "a")
  let b = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 120.0, 60.0, "b")
  let _ = @k.add_edge(sc, a.id, b.id, "")
  assert_eq(layout_with_elk(sc, "layered", "RIGHT"), "")
  assert_true(b.x > a.x)
}

///|
test "empty scene is reported, not silently ignored" {
  let sc = @k.new_scene()
  let err = layout_with_elk(sc, "layered", "DOWN")
  assert_true(err.length() > 0)
}

///|
test "unknown algorithm surfaces an error" {
  let sc = @k.new_scene()
  let a = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 120.0, 60.0, "a")
  let _ = a
  let err = layout_with_elk(sc, "definitely-not-an-algorithm", "DOWN")
  assert_true(err.length() > 0)
}

///|
test "engine reports known algorithms" {
  let known = known_algorithms()
  assert_true(known.length() >= 5)
  let mut has_layered = false
  for k in known {
    if k.contains("layered") {
      has_layered = true
    }
  }
  assert_true(has_layered)
}
