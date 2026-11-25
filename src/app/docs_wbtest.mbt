// Multi-document (tabs) tests. These use the state-only variants so no DOM is
// touched while running under Node.

///|
fn empty_docs() -> Unit {
  app_state.scene = @k.new_scene()
  app_state.cam_x = 90.0
  app_state.cam_y = 70.0
  app_state.zoom = 1.0
  app_state.docs = [
    Doc::{
      name: default_name(0),
      json: @k.scene_to_json(app_state.scene),
      cam_x: 90.0,
      cam_y: 70.0,
      zoom: 1.0,
    },
  ]
  app_state.active = 0
  app_state.undo_len = 0
  app_state.redo_len = 0
}

///|
test "new doc creates a tab and leaves the old one intact" {
  empty_docs()
  let _ = @k.add_shape(app_state.scene, @k.Rect, 0.0, 0.0, 100.0, 60.0, "在文档一")
  new_doc_state()
  assert_eq(doc_count(), 2)
  assert_eq(app_state.active, 1)
  assert_eq(app_state.scene.shapes.length(), 0)
  // Switching back restores the content.
  assert_true(switch_doc_state(0))
  assert_eq(app_state.scene.shapes.length(), 1)
  assert_eq(app_state.scene.shapes[0].text, "在文档一")
}

///|
test "each tab keeps its own viewport" {
  empty_docs()
  app_state.zoom = 2.0
  app_state.cam_x = 11.0
  new_doc_state()
  app_state.zoom = 0.5
  app_state.cam_x = 99.0
  let _ = switch_doc_state(0)
  assert_eq(app_state.zoom, 2.0)
  assert_eq(app_state.cam_x, 11.0)
  let _ = switch_doc_state(1)
  assert_eq(app_state.zoom, 0.5)
  assert_eq(app_state.cam_x, 99.0)
}

///|
test "switching to the same tab is a no-op" {
  empty_docs()
  assert_false(switch_doc_state(0))
  assert_false(switch_doc_state(7))
  assert_false(switch_doc_state(-1))
}

///|
test "closing the active tab activates a neighbour" {
  empty_docs()
  let _ = @k.add_shape(app_state.scene, @k.Rect, 0.0, 0.0, 10.0, 10.0, "A")
  new_doc_state()
  let _ = @k.add_shape(app_state.scene, @k.Rect, 0.0, 0.0, 10.0, 10.0, "B")
  new_doc_state()
  let _ = @k.add_shape(app_state.scene, @k.Rect, 0.0, 0.0, 10.0, 10.0, "C")
  assert_eq(doc_count(), 3)
  // Close the middle tab while it is not active.
  close_doc_state(1)
  assert_eq(doc_count(), 2)
  assert_eq(app_state.active, 1)
  assert_eq(app_state.scene.shapes[0].text, "C")
  // Close the active tab; the previous one becomes active.
  close_doc_state(1)
  assert_eq(doc_count(), 1)
  assert_eq(app_state.active, 0)
  assert_eq(app_state.scene.shapes[0].text, "A")
}

///|
test "closing the last tab empties it instead of removing" {
  empty_docs()
  let _ = @k.add_shape(app_state.scene, @k.Rect, 0.0, 0.0, 10.0, 10.0, "only")
  close_doc_state(0)
  assert_eq(doc_count(), 1)
  assert_eq(app_state.scene.shapes.length(), 0)
  assert_eq(app_state.docs[0].name, default_name(0))
}

///|
test "documents round-trip through JSON" {
  empty_docs()
  let _ = rename_doc_state(0, "流程 A")
  let _ = @k.add_shape(app_state.scene, @k.Rect, 5.0, 6.0, 100.0, 60.0, "节点")
  new_doc_state()
  let _ = rename_doc_state(1, "流程 B")
  let _ = @k.add_shape(app_state.scene, @k.Diamond, 0.0, 0.0, 80.0, 80.0, "判断")

  let json = docs_to_json()
  assert_true(json.contains("流程 A"))
  assert_true(json.contains("流程 B"))

  // Wipe and restore.
  app_state.docs = []
  app_state.active = 0
  assert_true(docs_from_json(json))
  assert_eq(doc_count(), 2)
  assert_eq(app_state.active, 1)
  assert_eq(app_state.scene.shapes[0].text, "判断")
  let _ = switch_doc_state(0)
  assert_eq(app_state.scene.shapes[0].text, "节点")
  assert_eq(app_state.docs[0].name, "流程 A")
}

///|
test "restoring rejects unusable payloads" {
  empty_docs()
  assert_false(docs_from_json("not json"))
  assert_false(docs_from_json("{\"docs\":[]}"))
  assert_false(docs_from_json("null"))
  // The existing state must survive a failed restore.
  assert_eq(doc_count(), 1)
}

///|
test "tab summary lists names and the active index" {
  empty_docs()
  let _ = rename_doc_state(0, "甲")
  new_doc_state()
  let _ = rename_doc_state(1, "乙")
  let summary = docs_summary_json()
  assert_true(summary.contains("\"active\":1"))
  assert_true(summary.contains("甲"))
  assert_true(summary.contains("乙"))
}
