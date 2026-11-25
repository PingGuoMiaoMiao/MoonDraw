// Alignment and stacking-order tests.

///|
fn three_boxes() -> App {
  let app = mk_app(1.0)
  let a = @k.add_shape(app.scene, @k.Rect, 0.0, 0.0, 100.0, 60.0, "a")
  let b = @k.add_shape(app.scene, @k.Rect, 200.0, 40.0, 60.0, 40.0, "b")
  let c = @k.add_shape(app.scene, @k.Rect, 400.0, 120.0, 80.0, 30.0, "c")
  sel_add(app, a.id)
  sel_add(app, b.id)
  sel_add(app, c.id)
  app
}

///|
test "align left" {
  let app = three_boxes()
  assert_true(align_selection(app, "left"))
  for s in app.scene.shapes {
    assert_eq(s.x, 0.0)
  }
}

///|
test "align right" {
  let app = three_boxes()
  let b = selection_bounds(app)
  assert_true(align_selection(app, "right"))
  for s in app.scene.shapes {
    assert_true(@k.absd(s.x + s.w - b.2) < 0.001)
  }
}

///|
test "align hcenter" {
  let app = three_boxes()
  assert_true(align_selection(app, "hcenter"))
  let cx = @k.center_x(app.scene.shapes[0])
  for s in app.scene.shapes {
    assert_true(@k.absd(@k.center_x(s) - cx) < 0.001)
  }
}

///|
test "align top" {
  let app = three_boxes()
  assert_true(align_selection(app, "top"))
  for s in app.scene.shapes {
    assert_eq(s.y, 0.0)
  }
}

///|
test "align bottom" {
  let app = three_boxes()
  let b = selection_bounds(app)
  assert_true(align_selection(app, "bottom"))
  for s in app.scene.shapes {
    assert_true(@k.absd(s.y + s.h - b.3) < 0.001)
  }
}

///|
test "align vcenter" {
  let app = three_boxes()
  assert_true(align_selection(app, "vcenter"))
  let cy = @k.center_y(app.scene.shapes[0])
  for s in app.scene.shapes {
    assert_true(@k.absd(@k.center_y(s) - cy) < 0.001)
  }
}

///|
test "align needs two shapes" {
  let app = mk_app(1.0)
  let a = @k.add_shape(app.scene, @k.Rect, 50.0, 50.0, 40.0, 40.0, "")
  sel_add(app, a.id)
  assert_false(align_selection(app, "left"))
}

///|
test "layer front and back" {
  let app = three_boxes()
  app.sel = [app.scene.shapes[0].id]
  assert_true(layer_op(app, "front"))
  let n = app.scene.shapes.length()
  assert_eq(app.scene.shapes[n - 1].text, "a")
  assert_true(layer_op(app, "back"))
  assert_eq(app.scene.shapes[0].text, "a")
}

///|
test "layer forward and backward move one step" {
  let app = three_boxes()
  app.sel = [app.scene.shapes[0].id]
  assert_true(layer_op(app, "forward"))
  assert_eq(app.scene.shapes[0].text, "b")
  assert_eq(app.scene.shapes[1].text, "a")
  assert_true(layer_op(app, "backward"))
  assert_eq(app.scene.shapes[0].text, "a")
}

///|
test "layer operations need a selection" {
  let app = three_boxes()
  app.sel = []
  assert_false(layer_op(app, "front"))
  assert_false(layer_op(app, "backward"))
}
