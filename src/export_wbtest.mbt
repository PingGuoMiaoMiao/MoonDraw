// Export-range tests: range parsing and SVG cropping are pure logic.

///|
test "export range names map both ways" {
  assert_eq(range_name(range_from_name("all")), "整图")
  assert_eq(range_name(range_from_name("selection")), "选区")
  assert_eq(range_name(range_from_name("viewport")), "视口")
  // Unknown input falls back to the whole diagram.
  assert_eq(range_name(range_from_name("wat")), "整图")
  assert_eq(range_name(range_from_name("")), "整图")
}

///|
test "svg crop honours the requested box plus padding" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 1000.0, 1000.0, 200.0, 100.0, "远端")
  // Export only a 0..100 box; the shape outside must not change the viewport.
  let svg = scene_to_svg_in(sc, (0.0, 0.0, 100.0, 50.0), 10.0)
  assert_true(svg.contains("width=\"120\""))
  assert_true(svg.contains("height=\"70\""))
  assert_true(svg.contains("viewBox=\"-10 -10 120 70\""))
  // Content is still emitted; cropping is the consumer's job.
  assert_true(svg.contains("远端"))
}

///|
test "svg crop rejects degenerate boxes" {
  let sc = new_scene()
  let svg = scene_to_svg_in(sc, (5.0, 5.0, 5.0, 5.0), 0.0)
  assert_true(svg.contains("width=\"1\""))
  assert_true(svg.contains("height=\"1\""))
}
