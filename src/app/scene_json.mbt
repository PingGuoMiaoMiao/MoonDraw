// JSON -> Scene. Lives in the app package because it needs JSON.parse
// through the JS FFI; the kernel only serializes.

///| NaN and infinities are rejected by the serialiser.
fn is_finite(v : Double) -> Bool {
  v == v && v != 1.0 / 0.0 && v != -1.0 / 0.0
}

///|
pub fn scene_from_json(root : JsValue) -> @k.Scene {
  let sc = @k.new_scene()
  let shapes = ffi_get(root, "shapes")
  let n = ffi_len(shapes)
  let mut max_id = 0
  for i = 0; i < n; i = i + 1 {
    let o = ffi_index(shapes, i)
    let kind = @k.kind_from_name(ffi_str(ffi_get(o, "kind")))
    let s = @k.add_shape(
      sc,
      kind,
      ffi_num(ffi_get(o, "x")),
      ffi_num(ffi_get(o, "y")),
      ffi_num(ffi_get(o, "w")),
      ffi_num(ffi_get(o, "h")),
      ffi_str(ffi_get(o, "text")),
    )
    let id = ffi_num(ffi_get(o, "id")).to_int()
    s.reassign_id(id)
    s.restyle(ffi_str(ffi_get(o, "fill")), ffi_str(ffi_get(o, "stroke")))
    let g = ffi_num(ffi_get(o, "group"))
    if g > 0.0 {
      s.set_group(g.to_int())
    }
    let arr = ffi_get(o, "data")
    let n = ffi_len(arr)
    if n > 0 {
      let pts : Array[Double] = []
      for k = 0; k < n; k = k + 1 {
        pts.push(ffi_num(ffi_index(arr, k)))
      }
      s.set_data(pts)
    }
    let st = ffi_num(ffi_get(o, "start"))
    let en = ffi_num(ffi_get(o, "end"))
    // Missing fields arrive as NaN from Number(undefined); only accept finite
    // spans so ordinary shapes stay at 0/0.
    if is_finite(st) && is_finite(en) && (st != 0.0 || en != 0.0) {
      let lane = ffi_num(ffi_get(o, "lane"))
      s.set_span(st, en, if is_finite(lane) { lane.to_int() } else { 0 })
    }
    if id > max_id {
      max_id = id
    }
  }
  let edges = ffi_get(root, "edges")
  let m = ffi_len(edges)
  for i = 0; i < m; i = i + 1 {
    let o = ffi_index(edges, i)
    let e = @k.add_edge(
      sc,
      ffi_num(ffi_get(o, "from")).to_int(),
      ffi_num(ffi_get(o, "to")).to_int(),
      ffi_str(ffi_get(o, "label")),
    )
    let id = ffi_num(ffi_get(o, "id")).to_int()
    e.reassign_id(id)
    if id > max_id {
      max_id = id
    }
  }
  sc.next_id = max_id + 1
  sc
}
