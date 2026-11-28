// Builders for the three non-diagram content types.
//
// Each takes plain text (the same currency as the Mermaid and outline inputs)
// and produces ordinary Scene content, so editing, export and layout are
// shared with everything else.

// ---------------------------------------------------------------------------
// Chart: "bar" or "line" over a CSV-ish series
// ---------------------------------------------------------------------------

///|
pub struct Series {
  labels : Array[String]
  values : Array[Double]
}

///| Parse `label,value` lines (also accepts `label: value`).
pub fn parse_series(src : String) -> Series {
  let labels : Array[String] = []
  let values : Array[Double] = []
  for part in src.split("\n") {
    let line = part.to_owned().trim().to_owned()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let mut sep = -1
    let cs = line.to_array()
    for i = 0; i < cs.length(); i = i + 1 {
      if cs[i] == ',' || cs[i] == ':' {
        sep = i
        break
      }
    }
    if sep <= 0 {
      continue
    }
    let label = substr_range(line, 0, sep).trim().to_owned()
    let raw = substr_range(line, sep + 1, cs.length()).trim().to_owned()
    let v = parse_number(raw)
    if v is Some(n) {
      labels.push(label)
      values.push(n)
    }
  }
  Series::{ labels: labels, values: values }
}

///|
fn substr_range(s : String, start : Int, end_ : Int) -> String {
  let cs = s.to_array()
  let b = StringBuilder(size_hint=32)
  let mut i = start
  while i < end_ && i < cs.length() {
    b.write_char(cs[i])
    i = i + 1
  }
  b.to_string()
}

///| Minimal float parser: optional sign, digits, one dot.
pub fn parse_number(s : String) -> Double? {
  let cs = s.to_array()
  if cs.length() == 0 {
    return None
  }
  let mut i = 0
  let mut sign = 1.0
  if cs[0] == '-' {
    sign = -1.0
    i = 1
  } else if cs[0] == '+' {
    i = 1
  }
  let mut int_part = 0.0
  let mut any = false
  while i < cs.length() && cs[i].to_int() >= '0'.to_int() && cs[i].to_int() <= '9'.to_int() {
    int_part = int_part * 10.0 + (cs[i].to_int() - '0'.to_int()).to_double()
    i = i + 1
    any = true
  }
  let mut frac = 0.0
  let mut scale = 1.0
  if i < cs.length() && cs[i] == '.' {
    i = i + 1
    while i < cs.length() && cs[i].to_int() >= '0'.to_int() && cs[i].to_int() <= '9'.to_int() {
      frac = frac * 10.0 + (cs[i].to_int() - '0'.to_int()).to_double()
      scale = scale * 10.0
      i = i + 1
      any = true
    }
  }
  if !any || i != cs.length() {
    return None
  }
  Some(sign * (int_part + frac / scale))
}

///| Bar or line chart as one Chart shape sized `w` x `h` at (x, y).
pub fn add_chart(
  scene : Scene,
  s : Series,
  kind : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Shape {
  let shape = add_shape(scene, Chart, x, y, w, h, kind)
  for v in s.values {
    shape.data.push(v)
  }
  // text = "<type>|label|label|..." so the scene JSON stays flat while
  // carrying both the chart type and the category labels.
  let b = StringBuilder(size_hint=64)
  b.write_string(kind)
  for label in s.labels {
    b.write_string("|")
    b.write_string(label)
  }
  shape.set_text(b.to_string())
  shape
}

///|
pub fn chart_labels(s : Shape) -> Array[String] {
  let out : Array[String] = []
  let mut first = true
  for part in s.text.split("|") {
    if first {
      first = false
      continue
    }
    out.push(part.to_owned())
  }
  out
}

///| The chart type stored in the first text segment ("bar" or "line").
pub fn chart_type(s : Shape) -> String {
  for part in s.text.split("|") {
    return part.to_owned()
  }
  "bar"
}

///|
pub fn chart_max(s : Shape) -> Double {
  let mut m = 1.0
  for v in s.data {
    if v > m {
      m = v
    }
  }
  m
}

// ---------------------------------------------------------------------------
// Whiteboard: freehand strokes
// ---------------------------------------------------------------------------

///| A stroke is a flat [x0, y0, x1, y1, ...] polyline stored in `data`.
pub fn add_stroke(scene : Scene, points : Array[Double], stroke : String) -> Shape {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  let mut i = 0
  while i + 1 < points.length() {
    let px = points[i]
    let py = points[i + 1]
    if first {
      min_x = px
      min_y = py
      max_x = px
      max_y = py
      first = false
    } else {
      min_x = mind(min_x, px)
      min_y = mind(min_y, py)
      max_x = maxd(max_x, px)
      max_y = maxd(max_y, py)
    }
    i = i + 2
  }
  let shape = add_shape(
    scene,
    Stroke,
    min_x,
    min_y,
    maxd(max_x - min_x, 1.0),
    maxd(max_y - min_y, 1.0),
    "",
  )
  shape.restyle("#ffffff", stroke)
  for v in points {
    shape.data.push(v)
  }
  shape
}

// ---------------------------------------------------------------------------
// Gantt: bars on a shared timeline
// ---------------------------------------------------------------------------

///| A gantt task: text, start, duration (in abstract units).
pub struct GanttTask {
  name : String
  start : Double
  duration : Double
}

///| Parse `task,start,duration` lines.
pub fn parse_gantt(src : String) -> Array[GanttTask] {
  let out : Array[GanttTask] = []
  for part in src.split("\n") {
    let line = part.to_owned().trim().to_owned()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let cs = line.to_array()
    let cuts : Array[Int] = []
    for i = 0; i < cs.length(); i = i + 1 {
      if cs[i] == ',' {
        cuts.push(i)
      }
    }
    if cuts.length() < 2 {
      continue
    }
    let name = substr_range(line, 0, cuts[0]).trim().to_owned()
    let st = parse_number(substr_range(line, cuts[0] + 1, cuts[1]))
    let du = if cuts.length() >= 3 {
      parse_number(substr_range(line, cuts[1] + 1, cuts[2]))
    } else {
      parse_number(substr_range(line, cuts[1] + 1, cs.length()))
    }
    match (st, du) {
      (Some(s), Some(d)) =>
        if name.length() > 0 && d > 0.0 {
          out.push(GanttTask::{ name: name, start: s, duration: d })
        }
      _ => ()
    }
  }
  out
}

///| Lay the tasks out as rows; one bar per task, plus a label shape.
pub fn add_gantt(
  scene : Scene,
  tasks : Array[GanttTask],
  x : Double,
  y : Double,
  width : Double,
) -> Unit {
  let row_h = 38.0
  let bar_h = 22.0
  let label_w = 96.0
  let mut total = 0.0
  for t in tasks {
    let e = t.start + t.duration
    if e > total {
      total = e
    }
  }
  if total <= 0.0 {
    total = 1.0
  }
  for i = 0; i < tasks.length(); i = i + 1 {
    let t = tasks[i]
    let ty = y + i.to_double() * row_h
    // task name on the left
    let _ = add_shape(scene, Text, x, ty, label_w, bar_h, t.name)
    // the bar itself
    let bx = x + label_w + t.start / total * width
    let bw = maxd(t.duration / total * width, 4.0)
    let bar = add_shape(scene, GanttBar, bx, ty, bw, bar_h, "")
    bar.start = t.start
    bar.end = t.start + t.duration
    bar.lane = i
    bar.restyle("#ebf5ff", "#0070f3")
  }
}

// ---------------------------------------------------------------------------
// Poster: a fixed-size artboard with defined export bounds
// ---------------------------------------------------------------------------

///| Create an artboard frame of the given print size (in points) at 1 units/px.
///| The frame is stored as a plain rectangle so it can be moved like anything.
pub fn add_artboard(
  scene : Scene,
  label : String,
  width : Double,
  height : Double,
) -> Shape {
  let frame = add_shape(scene, Rect, 0.0, 0.0, width, height, label)
  frame.restyle("#ffffff", "#d4d4d4")
  frame
}

///| Bounding box of the artboard frame: the largest plain rectangle.
pub fn artboard_bounds(scene : Scene) -> (Double, Double, Double, Double)? {
  let mut best : Shape? = None
  for s in scene.shapes {
    match s.kind {
      Rect =>
        match best {
          None => best = Some(s)
          Some(b) =>
            if s.w * s.h > b.w * b.h {
              best = Some(s)
            }
        }
      _ => ()
    }
  }
  match best {
    Some(b) => Some((b.x, b.y, b.x + b.w, b.y + b.h))
    None => None
  }
}

///| Parse a whiteboard file: one stroke per line, x,y x,y x,y.
///| Lines starting with # are comments.
pub fn parse_strokes(src : String) -> Array[Array[Double]] {
  let out : Array[Array[Double]] = []
  for part in src.split("\n") {
    let line = part.to_owned().trim().to_owned()
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let pts : Array[Double] = []
    for pair in line.split(" ") {
      let tok = pair.to_owned().trim().to_owned()
      if tok.length() == 0 {
        continue
      }
      let cs = tok.to_array()
      let mut comma = -1
      for i = 0; i < cs.length(); i = i + 1 {
        if cs[i] == ',' {
          comma = i
          break
        }
      }
      if comma <= 0 {
        continue
      }
      let xs = substr_range(tok, 0, comma)
      let ys = substr_range(tok, comma + 1, cs.length())
      match (parse_number(xs), parse_number(ys)) {
        (Some(x), Some(y)) => {
          pts.push(x)
          pts.push(y)
        }
        _ => ()
      }
    }
    if pts.length() >= 4 {
      out.push(pts)
    }
  }
  out
}

///| Build a whiteboard scene from parsed strokes.
pub fn scene_from_strokes(strokes : Array[Array[Double]], color : String) -> Scene {
  let sc = new_scene()
  for s in strokes {
    let _ = add_stroke(sc, s, color)
  }
  sc
}
