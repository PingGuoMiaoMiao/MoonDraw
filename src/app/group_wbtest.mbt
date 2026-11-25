// Grouping tests: grouping is pure model state, so it can be checked without
// any rendering.

///|
fn pair_app() -> App {
  let app = mk_app(1.0)
  let a = @k.add_shape(app.scene, @k.Rect, 0.0, 0.0, 100.0, 60.0, "a")
  let b = @k.add_shape(app.scene, @k.Rect, 200.0, 0.0, 100.0, 60.0, "b")
  let c = @k.add_shape(app.scene, @k.Rect, 400.0, 0.0, 100.0, 60.0, "c")
  sel_add(app, a.id)
  sel_add(app, b.id)
  app.sel = [a.id, b.id]
  ignore(c)
  app
}

///|
test "grouping needs two shapes" {
  let app = mk_app(1.0)
  let a = @k.add_shape(app.scene, @k.Rect, 0.0, 0.0, 10.0, 10.0, "")
  app.sel = [a.id]
  assert_false(group_selection(app))
  app.sel = []
  assert_false(group_selection(app))
}

///|
test "grouping assigns one id to the whole selection" {
  let app = pair_app()
  assert_true(group_selection(app))
  let gid = app.scene.shapes[0].group
  assert_true(gid > 0)
  assert_eq(app.scene.shapes[1].group, gid)
  assert_eq(app.scene.shapes[2].group, 0)
}

///|
test "a second group gets a different id" {
  let app = pair_app()
  assert_true(group_selection(app))
  let first = app.scene.shapes[0].group
  app.sel = [app.scene.shapes[2].id]
  let d = @k.add_shape(app.scene, @k.Rect, 600.0, 0.0, 80.0, 40.0, "d")
  app.sel = [app.scene.shapes[2].id, d.id]
  assert_true(group_selection(app))
  assert_true(app.scene.shapes[2].group != first)
}

///|
test "selecting one member expands to the group" {
  let app = pair_app()
  assert_true(group_selection(app))
  app.sel = [app.scene.shapes[0].id]
  expand_to_group(app, app.scene.shapes[0].id)
  assert_eq(sel_count(app), 2)
  assert_true(is_selected(app, app.scene.shapes[1].id))
}

///|
test "grouped shapes move together through the selection" {
  let app = pair_app()
  assert_true(group_selection(app))
  app.sel = [app.scene.shapes[0].id]
  expand_to_group(app, app.scene.shapes[0].id)
  app.drag_from = [
    (app.scene.shapes[0].id, app.scene.shapes[0].x, app.scene.shapes[0].y),
    (app.scene.shapes[1].id, app.scene.shapes[1].x, app.scene.shapes[1].y),
  ]
  move_selection(app, 30.0, 10.0)
  assert_eq(app.scene.shapes[0].x, 30.0)
  assert_eq(app.scene.shapes[1].x, 230.0)
  assert_eq(app.scene.shapes[2].x, 400.0)
}

///|
test "ungroup clears only the selected members" {
  let app = pair_app()
  assert_true(group_selection(app))
  assert_true(ungroup_selection(app))
  assert_eq(app.scene.shapes[0].group, 0)
  assert_eq(app.scene.shapes[1].group, 0)
  // Nothing left to ungroup.
  assert_false(ungroup_selection(app))
}

///|
test "group bounds cover the members" {
  let app = pair_app()
  assert_true(group_selection(app))
  match group_bounds(app, app.scene.shapes[0].group) {
    Some(b) => {
      assert_eq(b.0, 0.0)
      assert_true(@k.absd(b.2 - 300.0) < 0.001)
    }
    None => fail("expected bounds")
  }
  assert_true(group_bounds(app, 9999) is None)
  assert_true(group_bounds(app, 0) is None)
}

///|
test "group survives a JSON round-trip" {
  let app = pair_app()
  assert_true(group_selection(app))
  let gid = app.scene.shapes[0].group
  let json = @k.scene_to_json(app.scene)
  assert_true(json.contains("\"group\":"))
  let back = scene_from_json(ffi_parse_json(json))
  assert_eq(back.shapes[0].group, gid)
  assert_eq(back.shapes[2].group, 0)
}
