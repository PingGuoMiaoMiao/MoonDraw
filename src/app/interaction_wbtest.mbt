// Tests for the interaction layer: selection, snapping, arrange.

test "scene bounds" {
  let sc = @k.new_scene()
  let _ = @k.add_shape(sc, @k.Rect, 10.0, 20.0, 30.0, 40.0, "")
  let _ = @k.add_shape(sc, @k.Rect, -5.0, 5.0, 10.0, 10.0, "")
  let b = @k.scene_bounds(sc)
  assert_eq(b.0, -5.0)
  assert_eq(b.1, 5.0)
  assert_eq(b.2, 40.0)
  assert_eq(b.3, 60.0)
}

///| A blank editor state for tests that need one.
fn mk_app(zoom : Double) -> App {
  App::{
    scene: @k.new_scene(),
    cam_x: 0.0,
    cam_y: 0.0,
    zoom: zoom,
    tool: "select",
    sel: [],
    sel_edge: -1,
    drag: Idle,
    mx: 0.0,
    my: 0.0,
    drag_from: [],
    guides: [],
    docs: [],
    active: 0,
    undo: [],
    undo_len: 0,
    redo: [],
    redo_len: 0,
  }
}

///|
test "camera transforms are inverse" {
  let app = mk_app(1.75)
  let wx = 120.0
  let wy = -40.0
  assert_eq(@k.wx_of(app.view(), @k.sx(app.view(), wx)), wx)
  assert_eq(@k.wy_of(app.view(), @k.sy(app.view(), wy)), wy)
}

///|
test "selection set add / toggle / clear" {
  let app = mk_app(1.0)
  sel_add(app, 3)
  sel_add(app, 5)
  sel_add(app, 3)
  assert_eq(sel_count(app), 2)
  assert_true(is_selected(app, 3))
  assert_true(is_selected(app, 5))
  sel_toggle(app, 3)
  assert_eq(sel_count(app), 1)
  assert_true(is_selected(app, 5))
  sel_only(app, 9)
  assert_eq(sel_count(app), 1)
  assert_true(is_selected(app, 9))
  sel_clear(app)
  assert_eq(sel_count(app), 0)
  assert_eq(primary_id(app), -1)
}

///|
test "primary id only exists for a single selection" {
  let app = mk_app(1.0)
  sel_add(app, 1)
  assert_eq(primary_id(app), 1)
  sel_add(app, 2)
  assert_eq(primary_id(app), -1)
}

///|
test "grid snapping" {
  assert_eq(snap_to(10.0, 8.0), 8.0)
  assert_eq(snap_to(13.0, 8.0), 16.0)
  assert_eq(snap_to(13.0, 0.0), 13.0)
  let app = mk_app(1.0)
  let p = snap_point(app, 12.6, -3.0)
  assert_eq(p.0, 16.0)
  assert_eq(p.1, 0.0)
  // No snapping when zoomed far out.
  let far = mk_app(0.3)
  let q = snap_point(far, 12.6, -3.0)
  assert_eq(q.0, 12.6)
}

///|
test "alignment guides snap a box edge to a neighbour" {
  let app = mk_app(1.0)
  let _ = @k.add_shape(app.scene, @k.Rect, 100.0, 0.0, 100.0, 60.0, "")
  sel_add(app, 99)
  // Moving box whose left edge is 3px away from the neighbour's left edge.
  let (dx, _, guides) = align_box(app, (103.0, 200.0, 203.0, 260.0), 6.0)
  assert_eq(dx, -3.0)
  assert_true(guides.length() >= 1)
}

///|
test "alignment keeps the box alone when nothing is near" {
  let app = mk_app(1.0)
  let _ = @k.add_shape(app.scene, @k.Rect, 100.0, 0.0, 100.0, 60.0, "")
  let (dx, dy, guides) = align_box(app, (900.0, 900.0, 1000.0, 960.0), 6.0)
  assert_eq(dx, 0.0)
  assert_eq(dy, 0.0)
  assert_eq(guides.length(), 0)
}

///|
test "moving a selection uses drag-start offsets" {
  let app = mk_app(1.0)
  let a = @k.add_shape(app.scene, @k.Rect, 100.0, 100.0, 50.0, 50.0, "")
  let b = @k.add_shape(app.scene, @k.Rect, 300.0, 100.0, 50.0, 50.0, "")
  app.drag_from = [(a.id, a.x, a.y), (b.id, b.x, b.y)]
  move_selection(app, 20.0, -10.0)
  assert_eq(a.x, 120.0)
  assert_eq(a.y, 90.0)
  assert_eq(b.x, 320.0)
  // Moving again re-applies from the original origin, not cumulatively.
  move_selection(app, 5.0, 5.0)
  assert_eq(a.x, 105.0)
}

///|
test "deleting a selection also drops its connectors" {
  let app = mk_app(1.0)
  let _ = @k.add_shape(app.scene, @k.Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = @k.add_shape(app.scene, @k.Rect, 300.0, 0.0, 100.0, 60.0, "")
  let _ = @k.add_edge(app.scene, 1, 2, "x")
  sel_add(app, 1)
  assert_true(delete_selection(app))
  assert_eq(app.scene.shapes.length(), 1)
  assert_eq(app.scene.edges.length(), 0)
  assert_eq(sel_count(app), 0)
  // Nothing selected => nothing to delete.
  assert_false(delete_selection(app))
}

///|
test "deleting a connector only removes the edge" {
  let app = mk_app(1.0)
  let _ = @k.add_shape(app.scene, @k.Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = @k.add_shape(app.scene, @k.Rect, 300.0, 0.0, 100.0, 60.0, "")
  let _ = @k.add_edge(app.scene, 1, 2, "x")
  app.sel_edge = app.scene.edges[0].id
  assert_true(delete_selection(app))
  assert_eq(app.scene.shapes.length(), 2)
  assert_eq(app.scene.edges.length(), 0)
}

test "rubber band only takes fully contained shapes" {
  let sc = @k.new_scene()
  let _ = @k.add_shape(sc, @k.Rect, 10.0, 10.0, 50.0, 50.0, "inside")
  let _ = @k.add_shape(sc, @k.Rect, 40.0, 40.0, 80.0, 80.0, "partial")
  let _ = @k.add_shape(sc, @k.Rect, 300.0, 300.0, 50.0, 50.0, "outside")
  let picked = shapes_in_rect(sc, 0.0, 0.0, 100.0, 100.0)
  assert_eq(picked.length(), 1)
  assert_eq(picked[0], 1)
  // Reversed drag direction must behave the same.
  let reversed = shapes_in_rect(sc, 100.0, 100.0, 0.0, 0.0)
  assert_eq(reversed.length(), 1)
}


///|
test "connector hit testing" {
  let sc = @k.new_scene()
  let _ = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = @k.add_shape(sc, @k.Rect, 400.0, 0.0, 100.0, 60.0, "")
  let _ = @k.add_edge(sc, 1, 2, "")
  match edge_at(sc, 250.0, 30.0) {
    Some(_) => ()
    None => fail("expected to hit the connector")
  }
  match edge_at(sc, 250.0, 300.0) {
    Some(_) => fail("expected to miss the connector")
    None => ()
  }
}

///|
test "kernel benchmark: 1000 nodes" {
  @k.kernel_bench(1000, ffi_now)
}
