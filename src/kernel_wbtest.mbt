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
test "json round-trip preserves the document" {
  let sc = demo_scene()
  let json = scene_to_json(sc)
  let js = ffi_parse_json(json)
  assert_false(ffi_is_null(js))
  let back = scene_from_json(js)
  assert_eq(back.shapes.length(), sc.shapes.length())
  assert_eq(back.edges.length(), sc.edges.length())
  assert_eq(back.shapes[0].text, sc.shapes[0].text)
  assert_eq(kind_name(back.shapes[1].kind), "diamond")
  // next_id must keep growing after a load, otherwise new nodes collide.
  assert_true(back.next_id > sc.shapes.length())
  assert_eq(scene_to_json(back).length(), json.length())
}

///|
test "json escaping keeps quotes and newlines safe" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 0.0, 0.0, 10.0, 10.0, "a\"b\\c\nd")
  let json = scene_to_json(sc)
  let back = scene_from_json(ffi_parse_json(json))
  assert_eq(back.shapes[0].text, "a\"b\\c\nd")
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

///|
test "scene bounds" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 10.0, 20.0, 30.0, 40.0, "")
  let _ = add_shape(sc, Rect, -5.0, 5.0, 10.0, 10.0, "")
  let b = scene_bounds(sc)
  assert_eq(b.0, -5.0)
  assert_eq(b.1, 5.0)
  assert_eq(b.2, 40.0)
  assert_eq(b.3, 60.0)
}

///| A blank editor state for tests that need one.
fn mk_app(zoom : Double) -> App {
  App::{
    scene: new_scene(),
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
  assert_eq(wx_of(app.view(), sx(app.view(), wx)), wx)
  assert_eq(wy_of(app.view(), sy(app.view(), wy)), wy)
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
test "rubber band only takes fully contained shapes" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 10.0, 10.0, 50.0, 50.0, "inside")
  let _ = add_shape(sc, Rect, 40.0, 40.0, 80.0, 80.0, "partial")
  let _ = add_shape(sc, Rect, 300.0, 300.0, 50.0, 50.0, "outside")
  let picked = shapes_in_rect(sc, 0.0, 0.0, 100.0, 100.0)
  assert_eq(picked.length(), 1)
  assert_eq(picked[0], 1)
  // Reversed drag direction must behave the same.
  let reversed = shapes_in_rect(sc, 100.0, 100.0, 0.0, 0.0)
  assert_eq(reversed.length(), 1)
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
  let _ = add_shape(app.scene, Rect, 100.0, 0.0, 100.0, 60.0, "")
  sel_add(app, 99)
  // Moving box whose left edge is 3px away from the neighbour's left edge.
  let (dx, _, guides) = align_box(app, (103.0, 200.0, 203.0, 260.0), 6.0)
  assert_eq(dx, -3.0)
  assert_true(guides.length() >= 1)
}

///|
test "alignment keeps the box alone when nothing is near" {
  let app = mk_app(1.0)
  let _ = add_shape(app.scene, Rect, 100.0, 0.0, 100.0, 60.0, "")
  let (dx, dy, guides) = align_box(app, (900.0, 900.0, 1000.0, 960.0), 6.0)
  assert_eq(dx, 0.0)
  assert_eq(dy, 0.0)
  assert_eq(guides.length(), 0)
}

///|
test "connector hit testing" {
  let sc = new_scene()
  let _ = add_shape(sc, Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = add_shape(sc, Rect, 400.0, 0.0, 100.0, 60.0, "")
  let _ = add_edge(sc, 1, 2, "")
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
test "moving a selection uses drag-start offsets" {
  let app = mk_app(1.0)
  let a = add_shape(app.scene, Rect, 100.0, 100.0, 50.0, 50.0, "")
  let b = add_shape(app.scene, Rect, 300.0, 100.0, 50.0, 50.0, "")
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
  let _ = add_shape(app.scene, Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = add_shape(app.scene, Rect, 300.0, 0.0, 100.0, 60.0, "")
  let _ = add_edge(app.scene, 1, 2, "x")
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
  let _ = add_shape(app.scene, Rect, 0.0, 0.0, 100.0, 60.0, "")
  let _ = add_shape(app.scene, Rect, 300.0, 0.0, 100.0, 60.0, "")
  let _ = add_edge(app.scene, 1, 2, "x")
  app.sel_edge = app.scene.edges[0].id
  assert_true(delete_selection(app))
  assert_eq(app.scene.shapes.length(), 2)
  assert_eq(app.scene.edges.length(), 0)
}

///|
test "kernel benchmark: 1000 nodes" {
  kernel_bench(1000)
}
