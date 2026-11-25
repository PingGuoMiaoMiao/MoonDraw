// Mermaid import + layered layout tests.

///|
test "parse a small flowchart" {
  let src = "flowchart TD\n  A[开始] --> B{判断}\n  B -->|是| C(处理)\n  B -->|否| D((结束))"
  let doc = parse_mermaid(src)
  assert_eq(doc.nodes.length(), 4)
  assert_eq(doc.edges.length(), 3)
  assert_eq(doc.nodes[0].key, "A")
  assert_eq(doc.nodes[0].text, "开始")
  assert_eq(kind_name(doc.nodes[0].kind), "rect")
  assert_eq(kind_name(doc.nodes[1].kind), "diamond")
  assert_eq(kind_name(doc.nodes[2].kind), "round")
  assert_eq(kind_name(doc.nodes[3].kind), "ellipse")
  assert_eq(doc.edges[1].from, "B")
  assert_eq(doc.edges[1].to, "C")
  assert_eq(doc.edges[1].label, "是")
  assert_eq(doc.edges[2].label, "否")
}

///|
test "bare references do not overwrite earlier labels" {
  let src = "flowchart TD\n  A[开始] --> B{判断}\n  B -->|是| C(处理)\n  B -->|否| D((结束))\n  C --> E\n  D --> E"
  let doc = parse_mermaid(src)
  assert_eq(doc.nodes[1].text, "判断")
  assert_eq(doc.nodes[2].text, "处理")
  assert_eq(doc.nodes[3].text, "结束")
  // E is only ever referenced bare, so its label falls back to the key.
  assert_eq(doc.nodes[4].text, "E")
}

///|
test "direction and header detection" {
  assert_eq(dir_name(parse_mermaid("graph LR\n A-->B").direction), "LR")
  // `graph` without LR defaults to top-down.
  assert_eq(dir_name(parse_mermaid("graph\n A-->B").direction), "TD")
}

///|
test "chained links produce one edge each" {
  let doc = parse_mermaid("flowchart TD\n A --> B --> C")
  assert_eq(doc.nodes.length(), 3)
  assert_eq(doc.edges.length(), 2)
  assert_eq(doc.edges[0].from, "A")
  assert_eq(doc.edges[0].to, "B")
  assert_eq(doc.edges[1].from, "B")
  assert_eq(doc.edges[1].to, "C")
}

///|
test "presentation lines are skipped" {
  let src = "flowchart TD\n subgraph one\n A-->B\n end\n style A fill:#f00\n classDef x fill:#0f0\n class A x\n linkStyle 0 stroke:#333"
  let doc = parse_mermaid(src)
  assert_eq(doc.nodes.length(), 2)
  assert_eq(doc.edges.length(), 1)
}

///|
test "mermaid labels with quotes are unquoted" {
  let doc = parse_mermaid("flowchart TD\n A[\"带引号\"] --> B")
  assert_eq(doc.nodes[0].text, "带引号")
}

///|
test "layout puts roots first and edges connect real shapes" {
  let doc = parse_mermaid("flowchart TD\n A[开始] --> B{判断}\n B --> C[处理]")
  let sc = scene_from_mermaid(doc)
  assert_eq(sc.shapes.length(), 3)
  assert_eq(sc.edges.length(), 2)
  // Depth 0 node is above depth 1.
  assert_true(sc.shapes[0].y < sc.shapes[1].y)
  // Every edge points at shapes that exist.
  for e in sc.edges {
    match (find_shape(sc, e.from), find_shape(sc, e.to)) {
      (Some(_), Some(_)) => ()
      _ => fail("edge references a missing shape")
    }
  }
}

///|
test "layout handles left-right direction" {
  let doc = parse_mermaid("flowchart LR\n A --> B")
  let sc = scene_from_mermaid(doc)
  assert_true(sc.shapes[0].x < sc.shapes[1].x)
  assert_eq(sc.shapes[0].y, sc.shapes[1].y)
}

///|
test "depth computation tolerates cycles" {
  let keys = ["a", "b", "c"]
  let edges = [(0, 1), (1, 2), (2, 0)]
  let d = compute_depths(keys, edges)
  assert_eq(d.length(), 3)
  // A cycle with no root still terminates and yields finite depths.
  assert_true(d[0] >= 0)
  assert_true(d[1] >= 0)
  assert_true(d[2] >= 0)
}
