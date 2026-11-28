// Mind-map import: an indented outline becomes a tree of nodes.
//
// This is the second input dialect the engine accepts, next to Mermaid
// flowcharts. It reuses the same Shape/Edge model, so layout, editing and
// export all work unchanged.

///|
priv struct OutlineNode {
  text : String
  depth : Int
  parent : Int
  index : Int
}

///| Count leading spaces; a tab counts as four.
fn indent_width(line : String) -> Int {
  let mut w = 0
  for c in line {
    if c == ' ' {
      w = w + 1
    } else if c == '\t' {
      w = w + 4
    } else {
      break
    }
  }
  w
}

///| Strip list markers (`-`, `*`, `+`, `1.`) and surrounding blank space.
fn outline_text(line : String) -> String {
  let cs = line.to_array()
  let n = cs.length()
  let mut i = 0
  // leading whitespace
  while i < n && (cs[i] == ' ' || cs[i] == '\t') {
    i = i + 1
  }
  // list marker
  if i < n && (cs[i] == '-' || cs[i] == '*' || cs[i] == '+') {
    i = i + 1
  } else {
    // ordered marker: digits followed by `.` or `)`
    let mut j = i
    while j < n && cs[j].to_int() >= '0'.to_int() && cs[j].to_int() <= '9'.to_int() {
      j = j + 1
    }
    if j > i && j < n && (cs[j] == '.' || cs[j] == ')') {
      i = j + 1
    }
  }
  // skip following blanks
  while i < n && (cs[i] == ' ' || cs[i] == '\t') {
    i = i + 1
  }
  let b = StringBuilder(size_hint=32)
  let mut k = i
  while k < n {
    b.write_char(cs[k])
    k = k + 1
  }
  b.to_string().trim().to_owned()
}

///|
pub struct MindMap {
  /// Node texts, in document order.
  texts : Array[String]
  /// Parent index for each node (-1 for roots).
  parents : Array[Int]
  /// Indent depth of each node (0 for roots).
  depths : Array[Int]
}

///| Parse an indented outline. Blank lines and `#` headings are skipped.
pub fn parse_outline(src : String) -> MindMap {
  let texts : Array[String] = []
  let parents : Array[Int] = []
  let depths : Array[Int] = []
  // (depth, index) of the most recent node at each level
  let stack_depth : Array[Int] = []
  let stack_index : Array[Int] = []
  for part in src.split("\n") {
    let raw = part.to_owned()
    let line = raw.trim().to_owned()
    if line.length() == 0 {
      continue
    }
    if line.has_prefix("#") {
      continue
    }
    let indent = indent_width(raw)
    let text = outline_text(raw)
    if text.length() == 0 {
      continue
    }
    // pop levels that are not deeper than this one
    while stack_depth.length() > 0 && stack_depth[stack_depth.length() - 1] >= indent {
      let _ = stack_depth.pop()
      let _ = stack_index.pop()
    }
    let parent = if stack_index.length() > 0 {
      stack_index[stack_index.length() - 1]
    } else {
      -1
    }
    let idx = texts.length()
    texts.push(text)
    parents.push(parent)
    depths.push(if parent < 0 { 0 } else { depths[parent] + 1 })
    stack_depth.push(indent)
    stack_index.push(idx)
  }
  MindMap::{ texts: texts, parents: parents, depths: depths }
}

///| Build an editable scene: one node per outline line, one edge per parent.
pub fn scene_from_outline(mm : MindMap) -> Scene {
  let sc = new_scene()
  let ids : Array[Int] = []
  let max_depth = {
    let mut m = 0
    for d in mm.depths {
      if d > m {
        m = d
      }
    }
    m
  }
  for i = 0; i < mm.texts.length(); i = i + 1 {
    let text = mm.texts[i]
    let w = {
      let base = text_width_approx(text, 13.0) + 28.0
      if base < 92.0 {
        92.0
      } else if base > 240.0 {
        240.0
      } else {
        base
      }
    }
    // Root on the left, children indented to the right; the layout engine
    // repositions everything afterwards.
    let x = mm.depths[i].to_double() * 240.0
    let kind = if mm.depths[i] == 0 {
      Round
    } else if i == mm.texts.length() - 1 && max_depth > 0 {
      Rect
    } else {
      Rect
    }
    let s = add_shape(sc, kind, x, 0.0, w, 44.0, text)
    ids.push(s.id)
  }
  for i = 0; i < mm.parents.length(); i = i + 1 {
    let p = mm.parents[i]
    if p >= 0 {
      let _ = add_edge(sc, ids[p], ids[i], "")
    }
  }
  sc
}
