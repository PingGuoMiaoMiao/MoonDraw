///|
let storage_key : String = "moondraw_docs_v1"
let legacy_key : String = "moondraw_scene_v1"

///| Global editor state. One document, one viewport.
pub let app_state : App = App::{
  scene: @k.demo_scene(),
  cam_x: 90.0,
  cam_y: 70.0,
  zoom: 1.0,
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

///|
pub fn persist() -> Unit {
  ffi_local_set(storage_key, docs_to_json())
}

// ---------------------------------------------------------------------------
// Undo / redo: snapshots of the serialized scene.
// ---------------------------------------------------------------------------

///|
pub fn snapshot() -> Unit {
  if app_state.undo_len < app_state.undo.length() {
    app_state.undo[app_state.undo_len] = @k.scene_to_json(app_state.scene)
  } else {
    app_state.undo.push(@k.scene_to_json(app_state.scene))
  }
  app_state.undo_len = app_state.undo_len + 1
  app_state.redo_len = 0
}

///|
fn push_redo(json : String) -> Unit {
  if app_state.redo_len < app_state.redo.length() {
    app_state.redo[app_state.redo_len] = json
  } else {
    app_state.redo.push(json)
  }
  app_state.redo_len = app_state.redo_len + 1
}

///|
fn load_json(json : String) -> Unit {
  let js = ffi_parse_json(json)
  if !ffi_is_null(js) {
    app_state.scene = scene_from_json(js)
    sel_clear(app_state)
    app_state.drag = Idle
    app_state.drag_from = []
    app_state.guides = []
  }
}

///|
pub fn undo() -> Unit {
  if app_state.undo_len > 0 {
    push_redo(@k.scene_to_json(app_state.scene))
    app_state.undo_len = app_state.undo_len - 1
    load_json(app_state.undo[app_state.undo_len])
    persist()
    ffi_status("已撤销")
    render_all()
  } else {
    ffi_status("没有可撤销的操作")
  }
}

///|
pub fn redo() -> Unit {
  if app_state.redo_len > 0 {
    let json = @k.scene_to_json(app_state.scene)
    app_state.redo_len = app_state.redo_len - 1
    if app_state.undo_len < app_state.undo.length() {
      app_state.undo[app_state.undo_len] = json
    } else {
      app_state.undo.push(json)
    }
    app_state.undo_len = app_state.undo_len + 1
    load_json(app_state.redo[app_state.redo_len])
    persist()
    ffi_status("已重做")
    render_all()
  } else {
    ffi_status("没有可重做的操作")
  }
}

// ---------------------------------------------------------------------------
// Tools
// ---------------------------------------------------------------------------

///|
fn tool_kind(t : String) -> @k.ShapeKind {
  match t {
    "round" => @k.Round
    "diamond" => @k.Diamond
    "ellipse" => @k.Ellipse
    "text" => @k.Text
    "parallelogram" => @k.Parallelogram
    "hexagon" => @k.Hexagon
    "cylinder" => @k.Cylinder
    "document" => @k.Document
    "circle" => @k.Circle
    _ => @k.Rect
  }
}

///|
pub fn ui_set_tool(name : String) -> Unit {
  app_state.tool = name
  sel_clear(app_state)
  app_state.drag = Idle
  app_state.guides = []
  ffi_status("工具: " + name)
  render_all()
}

// ---------------------------------------------------------------------------
// Inline text editing (DOM textarea overlay => real IME support)
// ---------------------------------------------------------------------------

///|
fn editor_font() -> String {
  let px = (13.0 * app_state.zoom).to_int()
  let mut size = px
  if size < 11 {
    size = 11
  }
  "400 " + size.to_string() + "px 'Microsoft YaHei', 'PingFang SC', system-ui, sans-serif"
}

///|
fn open_editor_for(shape_id : Int) -> Unit {
  if ffi_editor_open() {
    return
  }
  match @k.find_shape(app_state.scene, shape_id) {
    Some(s) => {
      let c = ffi_dom_canvas("board")
      let left = ffi_origin_x(c) + @k.sx(app_state.view(), s.x)
      let top = ffi_origin_y(c) + @k.sy(app_state.view(), s.y)
      ffi_open_editor(
        left,
        top,
        s.w * app_state.zoom,
        s.h * app_state.zoom,
        s.text,
        editor_font(),
        fn(v) {
          snapshot()
          s.set_text(v)
          persist()
          render_all()
          ffi_status("文字已更新")
        },
      )
    }
    None => ()
  }
}

///|
fn open_editor_for_edge(edge_id : Int) -> Unit {
  if ffi_editor_open() {
    return
  }
  for e in app_state.scene.edges {
    if e.id == edge_id {
      match (
          @k.find_shape(app_state.scene, e.from),
          @k.find_shape(app_state.scene, e.to),
        ) {
        (Some(a), Some(b)) => {
          let pts = @k.route(a, b)
          let mid = pts[1]
          let mid2 = pts[2]
          let wx = (mid.0 + mid2.0) * 0.5
          let wy = (mid.1 + mid2.1) * 0.5
          let c = ffi_dom_canvas("board")
          let left = ffi_origin_x(c) + @k.sx(app_state.view(), wx) - 60.0
          let top = ffi_origin_y(c) + @k.sy(app_state.view(), wy) - 17.0
          ffi_open_editor(
            left,
            top,
            120.0,
            34.0,
            e.label,
            editor_font(),
            fn(v) {
              snapshot()
              e.set_label(v)
              persist()
              render_all()
              ffi_status("连线标签已更新")
            },
          )
        }
        _ => ()
      }
    }
  }
}

///|
fn open_editor_at(wx : Double, wy : Double) -> Unit {
  if ffi_editor_open() {
    return
  }
  let c = ffi_dom_canvas("board")
  let left = ffi_origin_x(c) + @k.sx(app_state.view(), wx)
  let top = ffi_origin_y(c) + @k.sy(app_state.view(), wy)
  ffi_open_editor(
    left,
    top,
    180.0,
    34.0,
    "",
    editor_font(),
    fn(v) {
      if v.length() > 0 {
        snapshot()
        let s = @k.add_shape(app_state.scene, @k.Text, wx, wy, 160.0, 36.0, v)
        sel_only(app_state, s.id)
        persist()
        render_all()
        ffi_status("已插入文字")
      }
    },
  )
}

// ---------------------------------------------------------------------------
// Pointer gestures
// ---------------------------------------------------------------------------

///| Resize handle under the pointer, for the single-selected shape.
fn handle_at(x : Double, y : Double) -> Int {
  let id = primary_id(app_state)
  if id < 0 {
    return -1
  }
  match @k.find_shape(app_state.scene, id) {
    Some(s) => {
      let mut hit = -1
      for i = 0; i < 4; i = i + 1 {
        let p = @k.handle_pos(s, i)
        let dx = @k.absd(@k.sx(app_state.view(), p.0) - x)
        let dy = @k.absd(@k.sy(app_state.view(), p.1) - y)
        if dx <= 9.0 && dy <= 9.0 {
          hit = i
        }
      }
      hit
    }
    None => -1
  }
}

///|
fn begin_move(grab_x : Double, grab_y : Double) -> Unit {
  let from : Array[(Int, Double, Double)] = []
  for id in app_state.sel {
    match @k.find_shape(app_state.scene, id) {
      Some(s) => from.push((id, s.x, s.y))
      None => ()
    }
  }
  app_state.drag_from = from
  app_state.drag = Move(grab_x, grab_y)
}

///|
fn on_down(x : Double, y : Double, button : Int, shift : Bool) -> Unit {
  app_state.mx = x
  app_state.my = y
  app_state.guides = []
  let wx = @k.wx_of(app_state.view(), x)
  let wy = @k.wy_of(app_state.view(), y)
  if button == 1 || (button == 0 && app_state.tool == "hand") {
    app_state.drag = Pan(x, y, app_state.cam_x, app_state.cam_y)
    return
  }
  match app_state.tool {
    "select" => {
      let h = handle_at(x, y)
      if h >= 0 {
        snapshot()
        app_state.drag = Resize(primary_id(app_state), h)
        render_all()
        return
      }
      match @k.shape_at(app_state.scene, wx, wy) {
        Some(s) => {
          if shift {
            sel_toggle(app_state, s.id)
          } else if !is_selected(app_state, s.id) {
            sel_only(app_state, s.id)
          }
          if is_selected(app_state, s.id) {
            snapshot()
            begin_move(wx, wy)
          }
          ffi_status("选中 " + sel_count(app_state).to_string() + " 个图形")
        }
        None =>
          match edge_at(app_state.scene, wx, wy) {
            Some(e) => {
              sel_clear(app_state)
              app_state.sel_edge = e.id
              ffi_status("已选中连线 · 双击改标签，Delete 删除")
            }
            None => {
              if !shift {
                sel_clear(app_state)
              }
              app_state.drag = Band(wx, wy)
            }
          }
      }
      render_all()
    }
    "edge" =>
      match @k.shape_at(app_state.scene, wx, wy) {
        Some(s) => {
          sel_only(app_state, s.id)
          app_state.drag = Connect(s.id)
          ffi_status("松开在另一个图形上，创建连线")
          render_all()
        }
        None => ffi_status("请从图形开始拖拽连线")
      }
    "text" => open_editor_at(wx, wy)
    "hand" => app_state.drag = Pan(x, y, app_state.cam_x, app_state.cam_y)
    _ => {
      snapshot()
      let p = snap_point(app_state, wx, wy)
      let s = @k.add_shape(
        app_state.scene,
        tool_kind(app_state.tool),
        p.0,
        p.1,
        0.0,
        0.0,
        "",
      )
      sel_only(app_state, s.id)
      app_state.drag = Create(s.id, p.0, p.1)
      render_all()
    }
  }
}

///|
fn apply_resize(s : @k.Shape, corner : Int, wx : Double, wy : Double) -> Unit {
  let snap = snap_point(app_state, wx, wy)
  let px = snap.0
  let py = snap.1
  let mut x1 = s.x
  let mut y1 = s.y
  let mut x2 = s.x + s.w
  let mut y2 = s.y + s.h
  if corner == 0 || corner == 2 {
    x1 = px
  } else {
    x2 = px
  }
  if corner == 0 || corner == 1 {
    y1 = py
  } else {
    y2 = py
  }
  if x2 - x1 < 24.0 {
    if corner == 0 || corner == 2 {
      x1 = x2 - 24.0
    } else {
      x2 = x1 + 24.0
    }
  }
  if y2 - y1 < 24.0 {
    if corner == 0 || corner == 1 {
      y1 = y2 - 24.0
    } else {
      y2 = y1 + 24.0
    }
  }
  s.x = x1
  s.y = y1
  s.w = x2 - x1
  s.h = y2 - y1
}

///|
fn on_move(x : Double, y : Double) -> Unit {
  app_state.mx = x
  app_state.my = y
  let wx = @k.wx_of(app_state.view(), x)
  let wy = @k.wy_of(app_state.view(), y)
  match app_state.drag {
    Move(gx, gy) => {
      let mut dx = wx - gx
      let mut dy = wy - gy
      // Grid snap on the selection's top-left, then alignment guides.
      if app_state.zoom >= 0.6 {
        let b = selection_bounds(app_state)
        let target = snap_point(app_state, b.0 + dx, b.1 + dy)
        dx = target.0 - b.0
        dy = target.1 - b.1
      }
      let b2 = selection_bounds(app_state)
      let moved = (
        b2.0 + dx,
        b2.1 + dy,
        b2.2 + dx,
        b2.3 + dy,
      )
      let tol = 6.0 / app_state.zoom
      let (adx, ady, guides) = align_box(app_state, moved, tol)
      app_state.guides = guides
      move_selection(app_state, dx + adx, dy + ady)
      render_all()
    }
    Band(ax, ay) => {
      let picked = shapes_in_rect(app_state.scene, ax, ay, wx, wy)
      app_state.sel = picked
      app_state.sel_edge = -1
      render_all()
    }
    Create(id, ox, oy) =>
      match @k.find_shape(app_state.scene, id) {
        Some(s) => {
          let p = snap_point(app_state, wx, wy)
          s.x = @k.mind(ox, p.0)
          s.y = @k.mind(oy, p.1)
          s.w = @k.absd(p.0 - ox)
          s.h = @k.absd(p.1 - oy)
          render_all()
        }
        None => ()
      }
    Resize(id, corner) =>
      match @k.find_shape(app_state.scene, id) {
        Some(s) => {
          apply_resize(s, corner, wx, wy)
          render_all()
        }
        None => ()
      }
    Pan(ox, oy, cx, cy) => {
      app_state.cam_x = cx + (x - ox)
      app_state.cam_y = cy + (y - oy)
      render_all()
    }
    Connect(_) => render_all()
    Idle => ()
  }
}

///|
fn on_up(x : Double, y : Double) -> Unit {
  let wx = @k.wx_of(app_state.view(), x)
  let wy = @k.wy_of(app_state.view(), y)
  match app_state.drag {
    Create(id, _, _) =>
      match @k.find_shape(app_state.scene, id) {
        Some(s) => {
          if s.w < 12.0 || s.h < 12.0 {
            s.x = s.x - 70.0
            s.y = s.y - 32.0
            s.resize_to(140.0, 64.0)
          }
          ffi_status("已创建 · 双击可输入文字")
        }
        None => ()
      }
    Connect(from) =>
      match @k.shape_at(app_state.scene, wx, wy) {
        Some(t) =>
          if t.id != from {
            snapshot()
            let _ = @k.add_edge(app_state.scene, from, t.id, "")
            sel_only(app_state, t.id)
            ffi_status("已创建连线")
          }
        None => ()
      }
    Band(_, _) =>
      ffi_status("已框选 " + sel_count(app_state).to_string() + " 个图形")
    Move(_, _) => ffi_status("位置已更新 · " + sel_count(app_state).to_string() + " 个图形")
    Resize(_, _) => ffi_status("尺寸已更新")
    _ => ()
  }
  app_state.drag = Idle
  app_state.drag_from = []
  app_state.guides = []
  persist()
  render_all()
}

///|
fn on_dbl(x : Double, y : Double) -> Unit {
  let wx = @k.wx_of(app_state.view(), x)
  let wy = @k.wy_of(app_state.view(), y)
  match @k.shape_at(app_state.scene, wx, wy) {
    Some(s) => open_editor_for(s.id)
    None =>
      match edge_at(app_state.scene, wx, wy) {
        Some(e) => open_editor_for_edge(e.id)
        None => open_editor_at(wx, wy)
      }
  }
}

///|
fn on_wheel(x : Double, y : Double, dy : Double) -> Unit {
  let old = app_state.zoom
  let mut next = old
  if dy < 0.0 {
    next = old * 1.1
  } else {
    next = old / 1.1
  }
  if next < 0.25 {
    next = 0.25
  }
  if next > 3.0 {
    next = 3.0
  }
  let wx = @k.wx_of(app_state.view(), x)
  let wy = @k.wy_of(app_state.view(), y)
  app_state.zoom = next
  app_state.cam_x = x - wx * next
  app_state.cam_y = y - wy * next
  render_all()
}

///|
fn on_resize() -> Unit {
  render_all()
}

// ---------------------------------------------------------------------------
// Keyboard
// ---------------------------------------------------------------------------

///|
fn delete_selected() -> Unit {
  if app_state.sel.length() == 0 && app_state.sel_edge < 0 {
    return
  }
  snapshot()
  if delete_selection(app_state) {
    persist()
    ffi_status("已删除选中内容")
    render_all()
  }
}

///|
fn select_all() -> Unit {
  let all : Array[Int] = []
  for s in app_state.scene.shapes {
    all.push(s.id)
  }
  app_state.sel = all
  app_state.sel_edge = -1
  ffi_status("已全选 " + all.length().to_string() + " 个图形")
  render_all()
}

///|
fn on_key(key : String, ctrl : Bool, shift : Bool) -> Unit {
  if ctrl {
    match key {
      "z" | "Z" =>
        if shift {
          redo()
        } else {
          undo()
        }
      "y" | "Y" => redo()
      "s" | "S" => ui_save()
      "a" | "A" => select_all()
      _ => ()
    }
    return
  }
  match key {
    "Delete" | "Backspace" => delete_selected()
    "Escape" => ui_set_tool("select")
    "v" | "V" => ui_set_tool("select")
    "r" | "R" => ui_set_tool("rect")
    "u" | "U" => ui_set_tool("round")
    "o" | "O" => ui_set_tool("ellipse")
    "d" | "D" => ui_set_tool("diamond")
    "t" | "T" => ui_set_tool("text")
    "l" | "L" => ui_set_tool("edge")
    "h" | "H" => ui_set_tool("hand")
    "f" | "F" => ui_fit()
    _ => ()
  }
}

// ---------------------------------------------------------------------------
// Public API used by the HTML shell
// ---------------------------------------------------------------------------

///|
pub fn boot() -> Unit {
  let saved = ffi_local_get(storage_key)
  let restored = if saved.length() > 0 {
    docs_from_json(saved)
  } else {
    false
  }
  if !restored {
    // Migrate a pre-tabs build (or start fresh) into a single tab.
    let legacy = ffi_local_get(legacy_key)
    if legacy.length() > 0 {
      let js = ffi_parse_json(legacy)
      if !ffi_is_null(js) {
        app_state.scene = scene_from_json(js)
      }
    }
    app_state.docs = [
      Doc::{
        name: default_name(0),
        json: @k.scene_to_json(app_state.scene),
        cam_x: app_state.cam_x,
        cam_y: app_state.cam_y,
        zoom: app_state.zoom,
      },
    ]
    app_state.active = 0
  }
  let c = ffi_dom_canvas("board")
  ffi_attach(c, on_down, on_move, on_up, on_dbl, on_wheel, on_key, on_resize)
  // Write the starting document so a reload restores exactly what is on screen.
  persist()
  ffi_status("就绪 · 拖拽移动，滚轮缩放，双击改文字")
  render_all()
}

// ---------------------------------------------------------------------------
// Tabs
// ---------------------------------------------------------------------------

///|
pub fn ui_new_doc() -> Unit {
  new_doc()
}

///|
pub fn ui_switch_doc(i : Int) -> Unit {
  switch_doc(i)
}

///|
pub fn ui_close_doc(i : Int) -> Unit {
  close_doc(i)
}

///|
pub fn ui_rename_doc(name : String) -> Unit {
  rename_doc(app_state.active, name)
}

///|
pub fn ui_docs_json() -> String {
  docs_summary_json()
}

///|
pub fn ui_undo() -> Unit {
  undo()
}

///|
pub fn ui_redo() -> Unit {
  redo()
}

///|
pub fn ui_save() -> Unit {
  persist()
  ffi_status("已保存到浏览器本地存储")
}

///| Export SVG for the requested range ("all" / "selection" / "viewport").
pub fn ui_export_svg(mode : String) -> Unit {
  let r = range_from_name(mode)
  let pad = match r {
    Viewport => 0.0
    _ => 48.0
  }
  let svg = @k.scene_to_svg_in(app_state.scene, export_bounds(r), pad)
  ffi_download_text(
    "moondraw-" + mode + ".svg",
    svg,
    "image/svg+xml",
  )
  ffi_status("已导出" + range_name(r) + " SVG")
}

///| Export PNG at 2x for the requested range.
pub fn ui_export_png(mode : String) -> Unit {
  export_png_range(range_from_name(mode), 2.0)
}

///|
pub fn ui_clear() -> Unit {
  snapshot()
  @k.clear_scene(app_state.scene)
  sel_clear(app_state)
  persist()
  ffi_status("画布已清空")
  render_all()
}

///|
pub fn ui_demo() -> Unit {
  snapshot()
  app_state.scene = @k.demo_scene()
  app_state.cam_x = 90.0
  app_state.cam_y = 70.0
  app_state.zoom = 1.0
  sel_clear(app_state)
  persist()
  ffi_status("已载入示例")
  render_all()
}

///|
pub fn ui_delete() -> Unit {
  delete_selected()
}

///| Snapshot *before* mutating, so undo restores the pre-arrange layout.
fn begin_arrange() -> Bool {
  if sel_count(app_state) < 3 {
    ffi_status("请先选中至少 3 个图形")
    return false
  }
  snapshot()
  true
}

///| Equal horizontal spacing across the selection.
pub fn ui_distribute_h() -> Unit {
  if !begin_arrange() {
    return
  }
  let _ = distribute_h(app_state)
  persist()
  ffi_status("已按横向等间距分布")
  render_all()
}

///| Equal vertical spacing across the selection.
pub fn ui_distribute_v() -> Unit {
  if !begin_arrange() {
    return
  }
  let _ = distribute_v(app_state)
  persist()
  ffi_status("已按纵向等间距分布")
  render_all()
}

///| Fit all shapes into the viewport.
pub fn ui_fit() -> Unit {
  let c = ffi_dom_canvas("board")
  let w = ffi_client_width(c)
  let h = ffi_client_height(c)
  let b = @k.scene_bounds(app_state.scene)
  if b.2 - b.0 > 1.0 && b.3 - b.1 > 1.0 {
    let zx = (w - 120.0) / (b.2 - b.0)
    let zy = (h - 120.0) / (b.3 - b.1)
    let mut z = if zx < zy { zx } else { zy }
    if z > 1.6 {
      z = 1.6
    }
    if z < 0.25 {
      z = 0.25
    }
    app_state.zoom = z
    app_state.cam_x = w * 0.5 - (b.0 + b.2) * 0.5 * z
    app_state.cam_y = h * 0.5 - (b.1 + b.3) * 0.5 * z
    render_all()
    ffi_status("已适配视图")
  }
}

fn replace_scene(sc : @k.Scene, fit : Bool) -> Unit {
  snapshot()
  app_state.scene = sc
  sel_clear(app_state)
  app_state.drag = Idle
  persist()
  if fit {
    ui_fit()
  }
  render_all()
}

///|
fn import_text(text : String, name : String) -> Unit {
  let lower = name.to_lower()
  let head = text.trim().to_lower()
  let mut looks_mermaid = lower.contains(".mmd")
  if lower.contains(".mermaid") || head.has_prefix("flowchart") || head.has_prefix("graph") {
    looks_mermaid = true
  }
  if looks_mermaid {
    let doc = @k.parse_mermaid(text)
    if doc.nodes.length() == 0 {
      ffi_status("Mermaid 解析失败：没有识别到节点")
      return
    }
    let sc = @k.scene_from_mermaid(doc)
    replace_scene(sc, true)
    rename_doc(app_state.active, name)
    let msg = StringBuilder(size_hint=64)
    msg.write_string("已导入 Mermaid · 节点 ")
    msg.write_string(doc.nodes.length().to_string())
    msg.write_string(" · 连线 ")
    msg.write_string(doc.edges.length().to_string())
    if doc.warnings.length() > 0 {
      msg.write_string(" · 跳过 ")
      msg.write_string(doc.warnings.length().to_string())
      msg.write_string(" 行")
    }
    ffi_status(msg.to_string())
    return
  }
  let js = ffi_parse_json(text)
  if ffi_is_null(js) {
    ffi_status("打开失败：不是有效的 .moondraw / JSON / Mermaid 文件")
    return
  }
  app_state.scene = scene_from_json(js)
  rename_doc(app_state.active, name)
  sel_clear(app_state)
  app_state.drag = Idle
  persist()
  ui_fit()
  render_all()
  ffi_status("已打开 " + name)
}

///| Open a `.moondraw` (JSON) or `.mmd` / Mermaid file from disk.
pub fn ui_open_file() -> Unit {
  ffi_open_file(".moondraw,.json,.mmd,.mermaid,.txt,.md", import_text)
}

///| Save the document as a `.moondraw` file (JSON on disk).
pub fn ui_save_file() -> Unit {
  ffi_download_text(
    "moondraw.moondraw",
    @k.scene_to_json(app_state.scene),
    "application/json",
  )
  ffi_status("已保存 moondraw.moondraw")
}

///| Import Mermaid source supplied by the page (used by the test harness).
pub fn ui_import_mermaid(text : String) -> Unit {
  import_text(text, "inline.mmd")
}
