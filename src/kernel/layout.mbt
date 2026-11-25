// Layered auto-layout for imported graphs: rank by BFS depth, then place
// nodes on a grid of rows/columns. Deliberately simple and deterministic —
// the user can drag anything afterwards.

///|
fn node_size(kind : ShapeKind, text : String) -> (Double, Double) {
  let w = clampd(text_width_approx(text, 13.0) + 48.0, 120.0, 260.0)
  match kind {
    Diamond => (maxd(w, 160.0), 96.0)
    Ellipse => (maxd(w, 130.0), 64.0)
    Text => (maxd(w, 100.0), 36.0)
    _ => (w, 64.0)
  }
}

///|
pub fn clampd(v : Double, lo : Double, hi : Double) -> Double {
  let mut r = v
  if r < lo {
    r = lo
  }
  if r > hi {
    r = hi
  }
  r
}

///| Shortest-path depth from the roots of a directed graph.
fn compute_depths(
  keys : Array[String],
  edges : Array[(Int, Int)],
) -> Array[Int] {
  let n = keys.length()
  let depths : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    depths.push(-1)
  }
  let has_in : Array[Bool] = []
  for i = 0; i < n; i = i + 1 {
    has_in.push(false)
  }
  for e in edges {
    has_in[e.1] = true
  }
  // BFS from every node that has no incoming edge (or node 0 if cyclic).
  let queue : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    if !has_in[i] {
      depths[i] = 0
      queue.push(i)
    }
  }
  if queue.length() == 0 && n > 0 {
    depths[0] = 0
    queue.push(0)
  }
  let mut head = 0
  while head < queue.length() {
    let cur = queue[head]
    head = head + 1
    for e in edges {
      if e.0 == cur {
        let next = e.1
        let d = depths[cur] + 1
        if depths[next] < 0 || depths[next] > d {
          depths[next] = d
          queue.push(next)
        }
      }
    }
  }
  for i = 0; i < n; i = i + 1 {
    if depths[i] < 0 {
      depths[i] = 0
    }
  }
  depths
}

///| Build an editable Scene from a parsed Mermaid document.
pub fn scene_from_mermaid(doc : MermaidDoc) -> Scene {
  let sc = new_scene()
  let n = doc.nodes.length()
  if n == 0 {
    return sc
  }
  // Map keys to indices.
  let keys : Array[String] = []
  for i = 0; i < n; i = i + 1 {
    keys.push(doc.nodes[i].key)
  }
  let edges : Array[(Int, Int)] = []
  for e in doc.edges {
    let mut a = -1
    let mut b = -1
    for i = 0; i < n; i = i + 1 {
      if keys[i] == e.from {
        a = i
      }
      if keys[i] == e.to {
        b = i
      }
    }
    if a >= 0 && b >= 0 {
      edges.push((a, b))
    }
  }
  let depths = compute_depths(keys, edges)
  // Bucket indices per depth, preserving declaration order.
  let mut max_depth = 0
  for d in depths {
    if d > max_depth {
      max_depth = d
    }
  }
  let buckets : Array[Array[Int]] = []
  for d = 0; d <= max_depth; d = d + 1 {
    buckets.push([])
  }
  for i = 0; i < n; i = i + 1 {
    buckets[depths[i]].push(i)
  }
  let gap_x = 90.0
  let gap_y = 110.0
  let mut row_height = 70.0
  let shape_id : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    shape_id.push(-1)
  }
  for d = 0; d <= max_depth; d = d + 1 {
    let bucket = buckets[d]
    if bucket.length() == 0 {
      continue
    }
    let mut row_w = 0.0
    for idx in bucket {
      let (w, _) = node_size(doc.nodes[idx].kind, doc.nodes[idx].text)
      row_w = row_w + w + gap_x
    }
    row_w = row_w - gap_x
    let mut x = -row_w * 0.5
    for idx in bucket {
      let nd = doc.nodes[idx]
      let (w, h) = node_size(nd.kind, nd.text)
      match doc.direction {
        TopDown => {
          let y = d.to_double() * (row_height + gap_y)
          let s = add_shape(sc, nd.kind, x, y, w, h, nd.text)
          shape_id[idx] = s.id
          if h > row_height {
            row_height = h
          }
        }
        LeftRight => {
          let x2 = d.to_double() * (row_height + gap_y)
          let s = add_shape(sc, nd.kind, x2, x, w, h, nd.text)
          shape_id[idx] = s.id
        }
      }
      x = x + w + gap_x
    }
  }
  for e in doc.edges {
    let mut a = -1
    let mut b = -1
    for i = 0; i < n; i = i + 1 {
      if keys[i] == e.from {
        a = i
      }
      if keys[i] == e.to {
        b = i
      }
    }
    if a >= 0 && b >= 0 && shape_id[a] >= 0 && shape_id[b] >= 0 {
      let _ = add_edge(sc, shape_id[a], shape_id[b], e.label)
    }
  }
  sc
}
