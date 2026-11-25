// Distribute (equal spacing) tests.

///| Build a selection of rects and return the app.
fn arrange_app(widths : Array[Double], xs : Array[Double]) -> App {
  let app = mk_app(1.0)
  for i = 0; i < widths.length(); i = i + 1 {
    let s = @k.add_shape(app.scene, @k.Rect, xs[i], 0.0, widths[i], 50.0, "")
    sel_add(app, s.id)
  }
  app
}

///|
test "horizontal distribution keeps the ends and equalises gaps" {
  let app = arrange_app([100.0, 60.0, 80.0], [0.0, 200.0, 400.0])
  assert_true(distribute_h(app))
  let gaps = gaps_h(app)
  assert_eq(gaps.length(), 2)
  assert_true(@k.absd(gaps[0] - gaps[1]) < 0.001)
  // Left edge of the first and right edge of the last are unchanged.
  assert_eq(app.scene.shapes[0].x, 0.0)
  let last = app.scene.shapes[2]
  assert_true(@k.absd(last.x + last.w - 480.0) < 0.001)
}

///|
test "distribution reorders by position, not selection order" {
  let app = arrange_app([50.0, 50.0, 50.0], [0.0, 300.0, 600.0])
  // Select in a scrambled order and expect the same result.
  app.sel = [3, 1, 2]
  assert_true(distribute_h(app))
  let gaps = gaps_h(app)
  assert_true(@k.absd(gaps[0] - gaps[1]) < 0.001)
}

///|
test "vertical distribution equalises vertical gaps" {
  let app = mk_app(1.0)
  for i = 0; i < 3; i = i + 1 {
    let s = @k.add_shape(app.scene, @k.Rect, 0.0, i.to_double() * 200.0, 80.0, [40.0, 60.0, 30.0][i], "")
    sel_add(app, s.id)
  }
  assert_true(distribute_v(app))
  let gaps = gaps_v(app)
  assert_eq(gaps.length(), 2)
  assert_true(@k.absd(gaps[0] - gaps[1]) < 0.001)
}

///|
test "distribution needs three shapes" {
  let app = arrange_app([50.0], [0.0])
  assert_false(distribute_h(app))
  assert_false(distribute_v(app))
  let two = arrange_app([50.0, 50.0], [0.0, 300.0])
  assert_false(distribute_h(two))
}

///|
test "overlapping shapes collapse to zero gap instead of negative" {
  let app = arrange_app([100.0, 100.0, 100.0], [0.0, 10.0, 20.0])
  assert_true(distribute_h(app))
  let gaps = gaps_h(app)
  assert_eq(gaps[0], 0.0)
  assert_eq(gaps[1], 0.0)
}

///|
test "distribution ignores shapes that are no longer in the scene" {
  let app = arrange_app([100.0, 60.0, 80.0], [0.0, 200.0, 400.0])
  let gone = app.scene.shapes[0].id
  @k.remove_shape(app.scene, gone)
  // Two valid shapes left -> below the threshold.
  assert_false(distribute_h(app))
}
