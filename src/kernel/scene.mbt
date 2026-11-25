///|
pub fn new_scene() -> Scene {
  Scene::{ shapes: [], edges: [], next_id: 1 }
}

///|
pub fn fill_for(kind : ShapeKind) -> String {
  match kind {
    Diamond | Ellipse | Parallelogram | Hexagon | Cylinder | Document | Circle =>
      "#fafafa"
    _ => "#ffffff"
  }
}

///|
pub fn stroke_for(kind : ShapeKind) -> String {
  match kind {
    Text => "#0070f3"
    _ => "#d4d4d4"
  }
}

///|
pub fn add_shape(
  scene : Scene,
  kind : ShapeKind,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  text : String,
) -> Shape {
  let s = Shape::{
    id: scene.next_id,
    kind: kind,
    x: x,
    y: y,
    w: w,
    h: h,
    text: text,
    fill: fill_for(kind),
    stroke: stroke_for(kind),
  }
  scene.next_id = scene.next_id + 1
  scene.shapes.push(s)
  s
}

///|
pub fn add_edge(scene : Scene, from : Int, to : Int, label : String) -> Edge {
  let e = Edge::{ id: scene.next_id, from: from, to: to, label: label }
  scene.next_id = scene.next_id + 1
  scene.edges.push(e)
  e
}

///|
pub fn find_shape(scene : Scene, id : Int) -> Shape? {
  for s in scene.shapes {
    if s.id == id {
      return Some(s)
    }
  }
  None
}

///|
pub fn remove_shape(scene : Scene, id : Int) -> Unit {
  let shapes : Array[Shape] = []
  for s in scene.shapes {
    if s.id != id {
      shapes.push(s)
    }
  }
  scene.shapes = shapes
  let edges : Array[Edge] = []
  for e in scene.edges {
    if e.from != id && e.to != id {
      edges.push(e)
    }
  }
  scene.edges = edges
}

///|
pub fn clear_scene(scene : Scene) -> Unit {
  scene.shapes = []
  scene.edges = []
  scene.next_id = 1
}

///|
pub fn demo_scene() -> Scene {
  let sc = new_scene()
  let _ = add_shape(sc, Round, 120.0, 140.0, 150.0, 64.0, "开始")
  let _ = add_shape(sc, Diamond, 350.0, 118.0, 200.0, 110.0, "数据有效?")
  let _ = add_shape(sc, Rect, 640.0, 140.0, 160.0, 64.0, "处理数据")
  let _ = add_shape(sc, Ellipse, 380.0, 350.0, 150.0, 64.0, "结束")
  let _ = add_edge(sc, 1, 2, "")
  let _ = add_edge(sc, 2, 3, "是")
  let _ = add_edge(sc, 2, 4, "否")
  sc
}

///| Bounding box of all shapes as (min_x, min_y, max_x, max_y).
pub fn scene_bounds(scene : Scene) -> (Double, Double, Double, Double) {
  if scene.shapes.length() == 0 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let first = scene.shapes[0]
  let mut min_x = first.x
  let mut min_y = first.y
  let mut max_x = first.x + first.w
  let mut max_y = first.y + first.h
  for s in scene.shapes {
    min_x = mind(min_x, s.x)
    min_y = mind(min_y, s.y)
    max_x = maxd(max_x, s.x + s.w)
    max_y = maxd(max_y, s.y + s.h)
  }
  (min_x, min_y, max_x, max_y)
}

///|
pub fn json_escape(s : String) -> String {
  s.replace_all(old="\\", new="\\\\")
    .replace_all(old="\"", new="\\\"")
    .replace_all(old="\n", new="\\n")
}

///|
pub fn kind_name(k : ShapeKind) -> String {
  match k {
    Rect => "rect"
    Round => "round"
    Diamond => "diamond"
    Ellipse => "ellipse"
    Text => "text"
    Parallelogram => "parallelogram"
    Hexagon => "hexagon"
    Cylinder => "cylinder"
    Document => "document"
    Circle => "circle"
  }
}

///|
pub fn kind_from_name(name : String) -> ShapeKind {
  if name == "round" {
    Round
  } else if name == "diamond" {
    Diamond
  } else if name == "ellipse" {
    Ellipse
  } else if name == "text" {
    Text
  } else if name == "parallelogram" {
    Parallelogram
  } else if name == "hexagon" {
    Hexagon
  } else if name == "cylinder" {
    Cylinder
  } else if name == "document" {
    Document
  } else if name == "circle" {
    Circle
  } else {
    Rect
  }
}

///|
pub fn scene_to_json(scene : Scene) -> String {
  let b = StringBuilder(size_hint=2048)
  b.write_string("{\"shapes\":[")
  let mut first = true
  for s in scene.shapes {
    if !first {
      b.write_string(",")
    }
    first = false
    b.write_string("{\"id\":")
    b.write_string(s.id.to_string())
    b.write_string(",\"kind\":\"")
    b.write_string(kind_name(s.kind))
    b.write_string("\",\"x\":")
    b.write_string(s.x.to_string())
    b.write_string(",\"y\":")
    b.write_string(s.y.to_string())
    b.write_string(",\"w\":")
    b.write_string(s.w.to_string())
    b.write_string(",\"h\":")
    b.write_string(s.h.to_string())
    b.write_string(",\"text\":\"")
    b.write_string(json_escape(s.text))
    b.write_string("\",\"fill\":\"")
    b.write_string(s.fill)
    b.write_string("\",\"stroke\":\"")
    b.write_string(s.stroke)
    b.write_string("\"}")
  }
  b.write_string("],\"edges\":[")
  first = true
  for e in scene.edges {
    if !first {
      b.write_string(",")
    }
    first = false
    b.write_string("{\"id\":")
    b.write_string(e.id.to_string())
    b.write_string(",\"from\":")
    b.write_string(e.from.to_string())
    b.write_string(",\"to\":")
    b.write_string(e.to.to_string())
    b.write_string(",\"label\":\"")
    b.write_string(json_escape(e.label))
    b.write_string("\"}")
  }
  b.write_string("],\"next_id\":")
  b.write_string(scene.next_id.to_string())
  b.write_string("}")
  b.to_string()
}
