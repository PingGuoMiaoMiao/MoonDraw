// Bridge between the editor document and Eclipse Layout Kernel.
//
// Layout goes through ELK's own JSON format: Scene -> ElkGraph JSON ->
// `new_elk_engine().layout(...)` -> coordinates written back onto the shapes.
// Keeping it JSON-shaped means the bridge never mirrors ELK's internal types.

///|
fn elk_id(shape_id : Int) -> String {
  "n" + shape_id.to_string()
}

///|
fn id_of_elk(elk : String) -> Int {
  let cs = elk.to_array()
  if cs.length() < 2 || cs[0] != 'n' {
    return -1
  }
  let mut v = 0
  for i = 1; i < cs.length(); i = i + 1 {
    let d = cs[i].to_int() - '0'.to_int()
    if d < 0 || d > 9 {
      return -1
    }
    v = v * 10 + d
  }
  v
}

///| Serialise the scene into the subset of ElkGraph JSON the engine reads.
pub fn scene_to_elk_json(scene : @k.Scene, algorithm : String, direction : String) -> String {
  let b = StringBuilder(size_hint=2048)
  b.write_string("{\"id\":\"root\",\"layoutOptions\":{\"elk.algorithm\":\"")
  b.write_string(algorithm)
  b.write_string("\",\"elk.direction\":\"")
  b.write_string(direction)
  b.write_string("\"},\"children\":[")
  let mut first = true
  for s in scene.shapes {
    if s.w < 1.0 || s.h < 1.0 {
      continue
    }
    if !first {
      b.write_string(",")
    }
    first = false
    b.write_string("{\"id\":\"")
    b.write_string(elk_id(s.id))
    b.write_string("\",\"width\":")
    b.write_string(s.w.to_string())
    b.write_string(",\"height\":")
    b.write_string(s.h.to_string())
    b.write_string("}")
  }
  b.write_string("],\"edges\":[")
  let mut first_edge = true
  for e in scene.edges {
    if !first_edge {
      b.write_string(",")
    }
    first_edge = false
    b.write_string("{\"id\":\"e")
    b.write_string(e.id.to_string())
    b.write_string("\",\"sources\":[\"")
    b.write_string(elk_id(e.from))
    b.write_string("\"],\"targets\":[\"")
    b.write_string(elk_id(e.to))
    b.write_string("\"]}")
  }
  b.write_string("]}")
  b.to_string()
}

///|
fn number_at(obj : @json.Json, key : String) -> Double? {
  match obj.value(key) {
    Some(v) =>
      match v.as_number() {
        Some(n) => Some(n)
        None => None
      }
    None => None
  }
}

///| Copy node positions from the layout result back onto the shapes.
fn apply_positions(scene : @k.Scene, out : @json.Json) -> Int {
  let children = match out.value("children") {
    Some(c) =>
      match c.as_array() {
        Some(a) => a
        None => return 0
      }
    None => return 0
  }
  let mut applied = 0
  for child in children {
    let id = match child.value("id") {
      Some(v) =>
        match v.as_string() {
          Some(s) => s
          None => ""
        }
      None => ""
    }
    if id.length() == 0 {
      continue
    }
    let shape_id = id_of_elk(id)
    if shape_id < 0 {
      continue
    }
    let x = number_at(child, "x")
    let y = number_at(child, "y")
    match (x, y) {
      (Some(px), Some(py)) =>
        match @k.find_shape(scene, shape_id) {
          Some(s) => {
            s.x = px
            s.y = py
            applied = applied + 1
          }
          None => ()
        }
      _ => ()
    }
  }
  applied
}

///| Run ELK over the scene. Returns an empty string on success, otherwise the
///| reason nothing moved.
pub fn layout_with_elk(
  scene : @k.Scene,
  algorithm : String,
  direction : String,
) -> String {
  if scene.shapes.length() == 0 {
    return "画布上没有图形"
  }
  let input = scene_to_elk_json(scene, algorithm, direction)
  let graph = @json.parse(input) catch {
    _ => return "生成的 ElK JSON 无法解析"
  }
  let engine = @elk.new_elk_engine()
  let out = engine.layout(graph~) catch {
    e => return "ELK 布局失败: " + e.to_string()
  }
  let applied = apply_positions(scene, out)
  if applied == 0 {
    return "ELK 没有返回坐标"
  }
  ""
}

///| Algorithms the bundled engine actually registers.
pub fn known_algorithms() -> Array[String] {
  @elk.new_elk_engine().known_layout_algorithms()
}
