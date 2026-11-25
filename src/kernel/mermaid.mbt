// Mermaid flowchart import.
//
// Only the subset that maps onto editable nodes is handled: node shapes, node
// text, and directed/undirected links with optional labels. Styling, subgraphs,
// click handlers and class definitions are skipped — an editor wants a graph,
// not a painted picture.

///|
pub(all) enum Direction {
  TopDown
  LeftRight
}

///| Stable name, used by tests and debugging output.
pub fn dir_name(d : Direction) -> String {
  match d {
    TopDown => "TD"
    LeftRight => "LR"
  }
}

///|
pub struct ParsedNode {
  key : String
  mut text : String
  kind : ShapeKind
}

///|
pub struct ParsedEdge {
  from : String
  to : String
  label : String
}

///|
pub struct MermaidDoc {
  direction : Direction
  nodes : Array[ParsedNode]
  edges : Array[ParsedEdge]
  warnings : Array[String]
}

///|
fn chars_of(s : String) -> Array[Char] {
  s.to_array()
}

///|
fn slice_str(cs : Array[Char], start : Int, stop : Int) -> String {
  let b = StringBuilder(size_hint=32)
  let mut i = start
  while i < stop && i < cs.length() {
    b.write_char(cs[i])
    i = i + 1
  }
  b.to_string()
}

///| Strip a `|label|` that follows a link operator.
priv enum SegKind {
  SegNode
  SegOp
  SegLabel
}

priv struct Seg {
  kind : SegKind
  text : String
}

priv struct LinkSplit {
  tokens : Array[String]
  labels : Array[String]
}

///|
fn is_bracket_open(c : Char) -> Bool {
  c == '[' || c == '(' || c == '{'
}

///|
fn is_bracket_close(c : Char) -> Bool {
  c == ']' || c == ')' || c == '}'
}

///| Characters that can appear inside a link operator (`-->`, `-.->`, `===`).
fn is_op_char(c : Char) -> Bool {
  c == '-' || c == '=' || c == '.' || c == '>'
}

///| Split a line into node / operator / label segments.
fn tokenize_line(line : String) -> Array[Seg] {
  let cs = chars_of(line)
  let n = cs.length()
  let segs : Array[Seg] = []
  let mut cur : Array[Char] = []
  let mut depth = 0
  let mut i = 0
  while i < n {
    let ch = cs[i]
    if depth > 0 {
      if is_bracket_open(ch) {
        depth = depth + 1
      } else if is_bracket_close(ch) {
        depth = depth - 1
      }
      cur.push(ch)
      i = i + 1
      continue
    }
    if is_bracket_open(ch) {
      depth = depth + 1
      cur.push(ch)
      i = i + 1
      continue
    }
    if is_op_char(ch) {
      let start = i
      while i < n && is_op_char(cs[i]) {
        i = i + 1
      }
      if cur.length() > 0 {
        segs.push(Seg::{ kind: SegNode, text: chars_to_string(cur).trim().to_owned() })
        cur = []
      }
      segs.push(Seg::{ kind: SegOp, text: slice_str(cs, start, i) })
      // Optional |label| straight after the operator.
      let mut k = i
      while k < n && cs[k] == ' ' {
        k = k + 1
      }
      if k < n && cs[k] == '|' {
        let mut e = k + 1
        while e < n && cs[e] != '|' {
          e = e + 1
        }
        segs.push(Seg::{ kind: SegLabel, text: slice_str(cs, k + 1, e).trim().to_owned() })
        i = if e < n { e + 1 } else { e }
      }
      continue
    }
    cur.push(ch)
    i = i + 1
  }
  if cur.length() > 0 {
    segs.push(Seg::{ kind: SegNode, text: chars_to_string(cur).trim().to_owned() })
  }
  segs
}

///| Split `A[x] -->|yes| B(y)` and `A -- text --> B` into node tokens plus
///| the label belonging to each consecutive pair.
fn split_links(line : String) -> LinkSplit {
  let segs = tokenize_line(line)
  let tokens : Array[String] = []
  let labels : Array[String] = []
  let mut pending = ""
  for idx = 0; idx < segs.length(); idx = idx + 1 {
    let seg = segs[idx]
    match seg.kind {
      SegOp => ()
      SegLabel => {
        pending = seg.text
      }
      SegNode => {
        // `A -- text --> B`: a node sandwiched between two operators is a label,
        // but only when the leading operator carries no arrow head (otherwise
        // `A --> B --> C` would lose B).
        let mut between_ops = false
        if idx > 0 && idx + 1 < segs.length() {
          match (segs[idx - 1].kind, segs[idx + 1].kind) {
            (SegOp, SegOp) =>
              if !segs[idx - 1].text.contains(">") {
                between_ops = true
              }
            _ => ()
          }
        }
        if between_ops {
          pending = seg.text
        } else if tokens.length() == 0 {
          tokens.push(seg.text)
        } else {
          labels.push(pending)
          pending = ""
          tokens.push(seg.text)
        }
      }
    }
  }
  LinkSplit::{ tokens: tokens, labels: labels }
}

///|
fn chars_to_string(cs : Array[Char]) -> String {
  slice_str(cs, 0, cs.length())
}
///| Parse `A`, `A[Text]`, `B(Round)`, `B((Ellipse))`, `C{Diamond}`.
fn parse_node_token(tok : String) -> (String, String, ShapeKind) {
  let cs = chars_of(tok)
  let n = cs.length()
  if n == 0 {
    return ("", "", Rect)
  }
  let mut open = -1
  for i = 0; i < n; i = i + 1 {
    if is_bracket_open(cs[i]) {
      open = i
      break
    }
  }
  if open <= 0 {
    // Bare reference (`B` inside `B --> C`): it carries no label, and must not
    // overwrite one that an earlier line already defined.
    return (tok, "", Rect)
  }
  let key = slice_str(cs, 0, open)
  let first = cs[open]
  let kind = match first {
    '{' => Diamond
    '(' => if open + 1 < n && cs[open + 1] == '(' { Ellipse } else { Round }
    _ => Rect
  }
  let mut start = open + 1
  match kind {
    Ellipse => if start < n && cs[start] == '(' {
      start = start + 1
    }
    _ => ()
  }
  let mut stop = n
  while stop > start && is_bracket_close(cs[stop - 1]) {
    stop = stop - 1
  }
  let text = if start < stop {
    slice_str(cs, start, stop).trim().to_owned()
  } else {
    ""
  }
  (key, unquote(text), kind)
}

///|
fn unquote(s : String) -> String {
  let cs = chars_of(s)
  let n = cs.length()
  if n >= 2 && cs[0] == '"' && cs[n - 1] == '"' {
    slice_str(cs, 1, n - 1)
  } else {
    s
  }
}

///|
fn contains_node(nodes : Array[ParsedNode], key : String) -> Bool {
  for n in nodes {
    if n.key == key {
      return true
    }
  }
  false
}

///| Lines that carry presentation or grouping only.
fn should_skip(lower : String) -> Bool {
  if lower == "end" || lower.has_prefix("subgraph") {
    return true
  }
  if lower.has_prefix("style") || lower.has_prefix("classdef") {
    return true
  }
  if lower.has_prefix("class ") || lower.has_prefix("click") {
    return true
  }
  if lower.has_prefix("linkstyle") || lower.has_prefix("direction") {
    return true
  }
  false
}

///|
pub fn parse_mermaid(src : String) -> MermaidDoc {
  let nodes : Array[ParsedNode] = []
  let edges : Array[ParsedEdge] = []
  let warnings : Array[String] = []
  let mut direction = TopDown
  let mut seen_header = false
  for raw in src.split("\n") {
    let mut line = raw.trim().to_owned()
    if line.length() == 0 || line.contains("%%") {
      continue
    }
    while line.length() > 0 {
      let last = line.to_array()[line.length() - 1]
      if last == ';' || last == '\r' {
        line = line[:line.length() - 1].to_owned()
      } else {
        break
      }
    }
    let lower = line.to_lower()
    if lower.has_prefix("flowchart") || lower.has_prefix("graph") {
      seen_header = true
      if line.contains("LR") || line.contains("RL") {
        direction = LeftRight
      }
      continue
    }
    if !seen_header {
      seen_header = true
    }
    if should_skip(lower) {
      continue
    }
    let parts = split_links(line)
    if parts.tokens.length() == 0 {
      warnings.push("无法解析: " + line)
      continue
    }
    let mut prev_key = ""
    for i = 0; i < parts.tokens.length(); i = i + 1 {
      let tok = parts.tokens[i].trim().to_owned()
      if tok.length() == 0 {
        continue
      }
      let (key0, text, kind) = parse_node_token(tok)
      let key = if key0.length() > 0 { key0 } else { "n" + nodes.length().to_string() }
      if !contains_node(nodes, key) {
        nodes.push(ParsedNode::{
          key: key,
          text: if text.length() > 0 { text } else { key },
          kind: kind,
        })
      } else if text.length() > 0 {
        for n in nodes {
          if n.key == key {
            n.text = text
          }
        }
      }
      if i > 0 && prev_key.length() > 0 {
        let label = if i - 1 < parts.labels.length() {
          parts.labels[i - 1].trim().to_owned()
        } else {
          ""
        }
        edges.push(ParsedEdge::{ from: prev_key, to: key, label: unquote(label) })
      }
      prev_key = key
    }
  }
  MermaidDoc::{ direction: direction, nodes: nodes, edges: edges, warnings: warnings }
}
