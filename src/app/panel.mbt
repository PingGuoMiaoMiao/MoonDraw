// Properties panel bridge: the shell renders inputs from this JSON and writes
// edits back through the ui_set_* functions below.

///| Compact description of the current selection for the panel.
pub fn selection_panel_json() -> String {
  let b = StringBuilder(size_hint=192)
  let ids = app_state.sel
  if ids.length() == 0 || app_state.sel_edge >= 0 {
    // No shape (or a connector) selected.
    if app_state.sel_edge >= 0 {
      for e in app_state.scene.edges {
        if e.id == app_state.sel_edge {
          b.write_string("{\"kind\":\"edge\",\"label\":\"")
          b.write_string(@k.json_escape(e.label))
          b.write_string("\",\"count\":1}")
          return b.to_string()
        }
      }
    }
    b.write_string("null")
    return b.to_string()
  }
  if ids.length() > 1 {
    b.write_string("{\"kind\":\"multi\",\"count\":")
    b.write_string(ids.length().to_string())
    b.write_string("}")
    return b.to_string()
  }
  match @k.find_shape(app_state.scene, ids[0]) {
    Some(s) => {
      b.write_string("{\"kind\":\"")
      b.write_string(@k.kind_name(s.kind))
      b.write_string("\",\"count\":1,\"x\":")
      b.write_string(s.x.to_int().to_string())
      b.write_string(",\"y\":")
      b.write_string(s.y.to_int().to_string())
      b.write_string(",\"w\":")
      b.write_string(s.w.to_int().to_string())
      b.write_string(",\"h\":")
      b.write_string(s.h.to_int().to_string())
      b.write_string(",\"fill\":\"")
      b.write_string(s.fill)
      b.write_string("\",\"stroke\":\"")
      b.write_string(s.stroke)
      b.write_string("\",\"text\":\"")
      b.write_string(@k.json_escape(s.text))
      b.write_string("\"}")
    }
    None => b.write_string("null")
  }
  b.to_string()
}

///| Shell-facing accessor used for the initial panel sync.
pub fn ui_selection_panel() -> String {
  selection_panel_json()
}

///|
fn selected_one() -> @k.Shape? {
  if app_state.sel.length() != 1 {
    return None
  }
  @k.find_shape(app_state.scene, app_state.sel[0])
}

///| Edit one geometry field of the single selected shape.
pub fn ui_set_geom(field : String, value : Double) -> Unit {
  match selected_one() {
    Some(s) => {
      snapshot()
      match field {
        "x" => s.x = value
        "y" => s.y = value
        "w" => s.resize_to(@k.maxd(value, 8.0), s.h)
        "h" => s.resize_to(s.w, @k.maxd(value, 8.0))
        _ => ()
      }
      persist()
      render_all()
    }
    None => ()
  }
}

///| Edit the fill or stroke colour of the single selected shape.
pub fn ui_set_paint(field : String, hex : String) -> Unit {
  if hex.length() == 0 {
    return
  }
  match selected_one() {
    Some(s) => {
      snapshot()
      if field == "fill" {
        s.fill = hex
      } else {
        s.stroke = hex
      }
      persist()
      render_all()
    }
    None => ()
  }
}

///| Replace the text of the single selected shape.
pub fn ui_set_shape_text(text : String) -> Unit {
  match selected_one() {
    Some(s) => {
      snapshot()
      s.set_text(text)
      persist()
      render_all()
    }
    None => ()
  }
}

///| Rename the label of the selected connector.
pub fn ui_set_edge_label(label : String) -> Unit {
  for e in app_state.scene.edges {
    if e.id == app_state.sel_edge {
      snapshot()
      e.set_label(label)
      persist()
      render_all()
      return
    }
  }
}

///| Zoom by a factor, anchored at the canvas centre.
pub fn ui_zoom(factor : Double) -> Unit {
  if factor <= 0.0 {
    return
  }
  let c = ffi_dom_canvas("board")
  let w = ffi_client_width(c)
  let h = ffi_client_height(c)
  let cx = w * 0.5
  let cy = h * 0.5
  let v = app_state.view()
  let wx = @k.wx_of(v, cx)
  let wy = @k.wy_of(v, cy)
  let mut next = app_state.zoom * factor
  if next < 0.25 {
    next = 0.25
  }
  if next > 3.0 {
    next = 3.0
  }
  app_state.zoom = next
  app_state.cam_x = cx - wx * next
  app_state.cam_y = cy - wy * next
  render_all()
}

///| Jump back to 100% zoom around the view centre.
pub fn ui_zoom_reset() -> Unit {
  let c = ffi_dom_canvas("board")
  let w = ffi_client_width(c)
  let h = ffi_client_height(c)
  let v = app_state.view()
  let wx = @k.wx_of(v, w * 0.5)
  let wy = @k.wy_of(v, h * 0.5)
  app_state.zoom = 1.0
  app_state.cam_x = w * 0.5 - wx
  app_state.cam_y = h * 0.5 - wy
  render_all()
}

///| Align the selection (left | hcenter | right | top | vcenter | bottom).
pub fn ui_align(mode : String) -> Unit {
  if app_state.sel.length() < 2 {
    ffi_status("对齐需要选中至少 2 个图形")
    return
  }
  snapshot()
  let _ = align_selection(app_state, mode)
  persist()
  ffi_status("已对齐")
  render_all()
}

///| Change stacking order (front | back | forward | backward).
pub fn ui_layer(op : String) -> Unit {
  if app_state.sel.length() == 0 {
    ffi_status("请先选中图形")
    return
  }
  snapshot()
  if layer_op(app_state, op) {
    persist()
    ffi_status("已调整层级")
  }
  render_all()
}

///| Re-run automatic layout with Eclipse Layout Kernel.
pub fn ui_elk_layout(algorithm : String) -> Unit {
  let dir = "DOWN"
  snapshot()
  let err = @elk_layout.layout_with_elk(app_state.scene, algorithm, dir)
  if err.length() > 0 {
    ffi_status(err)
    return
  }
  persist()
  ui_fit()
  ffi_status("ELK 自动布局完成 · " + algorithm)
}

///| Which algorithms the bundled ELK engine reports.
pub fn ui_elk_algorithms() -> String {
  let b = StringBuilder(size_hint=128)
  b.write_string("[")
  let known = @elk_layout.known_algorithms()
  for i = 0; i < known.length(); i = i + 1 {
    if i > 0 {
      b.write_string(",")
    }
    b.write_string("\"")
    b.write_string(known[i])
    b.write_string("\"")
  }
  b.write_string("]")
  b.to_string()
}

///| Group the current selection so it selects and moves as one.
pub fn ui_group() -> Unit {
  if app_state.sel.length() < 2 {
    ffi_status("组合需要选中至少 2 个图形")
    return
  }
  snapshot()
  if group_selection(app_state) {
    persist()
    ffi_status("已组合 · " + app_state.sel.length().to_string() + " 个图形")
    render_all()
  }
}

///| Break the selection out of its groups.
pub fn ui_ungroup() -> Unit {
  snapshot()
  if ungroup_selection(app_state) {
    persist()
    ffi_status("已解组")
    render_all()
  } else {
    ffi_status("选中的图形不在任何组里")
  }
}

// ---------------------------------------------------------------------------
// Insert the non-diagram content types into the current document, so the web
// editor exposes the same seven content families the CLI can produce.
// ---------------------------------------------------------------------------

///| Insert a bar or line chart from `label,value` text at the view centre.
pub fn ui_insert_chart(data : String, kind : String) -> Unit {
  let series = @k.parse_series(data)
  if series.values.length() == 0 {
    ffi_status("图表数据为空：请用「标签,数值」每行一条")
    return
  }
  snapshot()
  let c = ffi_dom_canvas("board")
  let w = ffi_client_width(c)
  let h = ffi_client_height(c)
  let v = app_state.view()
  let cx = @k.wx_of(v, w * 0.5) - 230.0
  let cy = @k.wy_of(v, h * 0.5) - 130.0
  let s = @k.add_chart(app_state.scene, series, kind, cx, cy, 460.0, 260.0)
  sel_only(app_state, s.id)
  persist()
  ffi_status("已插入" + kind + "图表 · " + series.values.length().to_string() + " 个数据点")
  render_all()
}

///| Insert a gantt block from `task,start,duration` text.
pub fn ui_insert_gantt(data : String) -> Unit {
  let tasks = @k.parse_gantt(data)
  if tasks.length() == 0 {
    ffi_status("甘特数据为空：请用「任务,开始,时长」每行一条")
    return
  }
  snapshot()
  let c = ffi_dom_canvas("board")
  let w = ffi_client_width(c)
  let h = ffi_client_height(c)
  let v = app_state.view()
  let cx = @k.wx_of(v, w * 0.5) - 260.0
  let cy = @k.wy_of(v, h * 0.5) - 100.0
  @k.add_gantt(app_state.scene, tasks, cx, cy, 420.0)
  sel_clear(app_state)
  persist()
  ffi_status("已插入甘特图 · " + tasks.length().to_string() + " 个任务")
  render_all()
}

///| Insert a whiteboard stroke run from `x,y x,y ...` text.
pub fn ui_insert_strokes(data : String) -> Unit {
  let strokes = @k.parse_strokes(data)
  if strokes.length() == 0 {
    ffi_status("笔迹数据为空：请用「x,y x,y ...」每行一条")
    return
  }
  snapshot()
  let sc = @k.scene_from_strokes(strokes, "#171717")
  for s in sc.shapes {
    app_state.scene.shapes.push(s)
  }
  persist()
  ffi_status("已插入 " + strokes.length().to_string() + " 条笔迹")
  render_all()
}

///| Replace the document with a poster artboard of the given size.
pub fn ui_new_poster(size : String) -> Unit {
  let dims = match size {
    "A3" => (1191.0, 1684.0)
    "16:9" => (1920.0, 1080.0)
    _ => (794.0, 1123.0)
  }
  snapshot()
  @k.clear_scene(app_state.scene)
  let _ = @k.add_artboard(app_state.scene, "画板", dims.0, dims.1)
  app_state.zoom = 0.5
  app_state.cam_x = 40.0
  app_state.cam_y = 40.0
  sel_clear(app_state)
  persist()
  ffi_status(
    "海报画板 " + dims.0.to_int().to_string() + "×" + dims.1.to_int().to_string(),
  )
  render_all()
}
