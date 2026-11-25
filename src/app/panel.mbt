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
