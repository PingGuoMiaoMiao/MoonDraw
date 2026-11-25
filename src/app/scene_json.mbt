// JSON -> Scene. Lives in the app package because it needs JSON.parse
// through the JS FFI; the kernel only serializes.

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
