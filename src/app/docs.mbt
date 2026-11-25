// Documents (tabs): each tab keeps its own scene snapshot, viewport and name.
// The active tab always lives in `app_state.scene`; switching serializes the
// outgoing one and parses the incoming one.

///|
pub fn doc_count() -> Int {
  app_state.docs.length()
}

///| The active tab. Callers must make sure at least one tab exists.
pub fn active_doc() -> Doc {
  app_state.docs[app_state.active]
}

///| Copy the live editor state into the active tab record.
pub fn stash_active() -> Unit {
  if app_state.docs.length() == 0 {
    return
  }
  let d = app_state.docs[app_state.active]
  d.json = @k.scene_to_json(app_state.scene)
  d.cam_x = app_state.cam_x
  d.cam_y = app_state.cam_y
  d.zoom = app_state.zoom
}

///|
fn make_doc(name : String, scene_json : String) -> Doc {
  Doc::{ name: name, json: scene_json, cam_x: 90.0, cam_y: 70.0, zoom: 1.0 }
}

///|
pub fn default_name(index : Int) -> String {
  "文档 " + (index + 1).to_string()
}

///| Replace the live scene/viewport with a stored tab.
fn load_doc(d : Doc) -> Unit {
  let js = ffi_parse_json(d.json)
  if ffi_is_null(js) {
    app_state.scene = @k.new_scene()
  } else {
    app_state.scene = scene_from_json(js)
  }
  app_state.cam_x = d.cam_x
  app_state.cam_y = d.cam_y
  app_state.zoom = d.zoom
  sel_clear(app_state)
  app_state.drag = Idle
  app_state.drag_from = []
  app_state.guides = []
  // Undo history belongs to the tab, so it resets on switch. Documented.
  app_state.undo_len = 0
  app_state.redo_len = 0
}

///| State-only switch, no rendering. Used by tests.
pub fn switch_doc_state(i : Int) -> Bool {
  if i < 0 || i >= app_state.docs.length() || i == app_state.active {
    return false
  }
  stash_active()
  app_state.active = i
  load_doc(app_state.docs[i])
  persist()
  true
}

///| Switch to tab `i` (no-op when out of range or already active).
pub fn switch_doc(i : Int) -> Unit {
  if switch_doc_state(i) {
    ffi_status("切换到 " + app_state.docs[i].name)
    render_all()
  }
}

///| Create an empty tab and activate it. State only, no rendering.
pub fn new_doc_state() -> Unit {
  stash_active()
  let name = default_name(app_state.docs.length())
  app_state.docs.push(make_doc(name, @k.scene_to_json(@k.new_scene())))
  app_state.active = app_state.docs.length() - 1
  app_state.scene = @k.new_scene()
  app_state.cam_x = 90.0
  app_state.cam_y = 70.0
  app_state.zoom = 1.0
  sel_clear(app_state)
  app_state.drag = Idle
  app_state.undo_len = 0
  app_state.redo_len = 0
  persist()
}

///| Create an empty tab and activate it.
pub fn new_doc() -> Unit {
  new_doc_state()
  ffi_status("已新建 " + app_state.docs[app_state.active].name)
  render_all()
}

///| Close tab `i`. The last tab is never removed, it is emptied instead.
///| State only, no rendering.
pub fn close_doc_state(i : Int) -> Unit {
  if i < 0 || i >= app_state.docs.length() {
    return
  }
  if app_state.docs.length() == 1 {
    app_state.scene = @k.new_scene()
    app_state.docs[0] = make_doc(default_name(0), @k.scene_to_json(@k.new_scene()))
    app_state.active = 0
    sel_clear(app_state)
    app_state.undo_len = 0
    app_state.redo_len = 0
    persist()
    return
  }
  let kept : Array[Doc] = []
  for idx = 0; idx < app_state.docs.length(); idx = idx + 1 {
    if idx != i {
      kept.push(app_state.docs[idx])
    }
  }
  let was_active = app_state.active
  app_state.docs = kept
  if was_active == i {
    let target = if i >= kept.length() { kept.length() - 1 } else { i }
    app_state.active = target
    load_doc(app_state.docs[target])
  } else if was_active > i {
    app_state.active = was_active - 1
  }
  persist()
}

///| Close tab `i`. The last tab is never removed, it is emptied instead.
pub fn close_doc(i : Int) -> Unit {
  close_doc_state(i)
  ffi_status("已关闭文档")
  render_all()
}

///| Rename a tab. State only, no rendering.
pub fn rename_doc_state(i : Int, name : String) -> Bool {
  if i >= 0 && i < app_state.docs.length() && name.length() > 0 {
    app_state.docs[i].name = name
    persist()
    return true
  }
  false
}

///|
pub fn rename_doc(i : Int, name : String) -> Unit {
  if rename_doc_state(i, name) {
    render_all()
  }
}

///| Serialize every tab (scene embedded as an object, not a string).
pub fn docs_to_json() -> String {
  stash_active()
  let b = StringBuilder(size_hint=4096)
  b.write_string("{\"active\":")
  b.write_string(app_state.active.to_string())
  b.write_string(",\"docs\":[")
  for i = 0; i < app_state.docs.length(); i = i + 1 {
    let d = app_state.docs[i]
    if i > 0 {
      b.write_string(",")
    }
    b.write_string("{\"name\":\"")
    b.write_string(@k.json_escape(d.name))
    b.write_string("\",\"cam_x\":")
    b.write_string(d.cam_x.to_string())
    b.write_string(",\"cam_y\":")
    b.write_string(d.cam_y.to_string())
    b.write_string(",\"zoom\":")
    b.write_string(d.zoom.to_string())
    b.write_string(",\"scene\":")
    b.write_string(d.json)
    b.write_string("}")
  }
  b.write_string("]}")
  b.to_string()
}

///| Restore all tabs from disk. Returns false when the payload is unusable.
pub fn docs_from_json(text : String) -> Bool {
  let root = ffi_parse_json(text)
  if ffi_is_null(root) {
    return false
  }
  let arr = ffi_get(root, "docs")
  let n = ffi_len(arr)
  if n == 0 {
    return false
  }
  let docs : Array[Doc] = []
  for i = 0; i < n; i = i + 1 {
    let o = ffi_index(arr, i)
    let name = ffi_str(ffi_get(o, "name"))
    let js = ffi_get(o, "scene")
    let json = if ffi_is_null(js) { @k.scene_to_json(@k.new_scene()) } else { ffi_stringify(js) }
    docs.push(Doc::{
      name: if name.length() > 0 { name } else { default_name(i) },
      json: json,
      cam_x: ffi_num(ffi_get(o, "cam_x")),
      cam_y: ffi_num(ffi_get(o, "cam_y")),
      zoom: {
        let z = ffi_num(ffi_get(o, "zoom"))
        if z > 0.0 && z < 10.0 {
          z
        } else {
          1.0
        }
      },
    })
  }
  let act = ffi_num(ffi_get(root, "active")).to_int()
  app_state.docs = docs
  app_state.active = if act >= 0 && act < docs.length() { act } else { 0 }
  load_doc(app_state.docs[app_state.active])
  true
}

///| What the tab bar renders. Small JSON so the shell stays dumb.
pub fn docs_summary_json() -> String {
  stash_active()
  let b = StringBuilder(size_hint=256)
  b.write_string("{\"active\":")
  b.write_string(app_state.active.to_string())
  b.write_string(",\"docs\":[")
  for i = 0; i < app_state.docs.length(); i = i + 1 {
    if i > 0 {
      b.write_string(",")
    }
    b.write_string("{\"name\":\"")
    b.write_string(@k.json_escape(app_state.docs[i].name))
    b.write_string("\"}")
  }
  b.write_string("]}")
  b.to_string()
}
