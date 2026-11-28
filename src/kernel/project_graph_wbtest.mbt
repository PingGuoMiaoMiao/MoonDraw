// Project graph (MoonBit package dependencies) tests.

///|
test "imports are extracted from a moon.pkg block" {
  let src = "import {\n  \"a/b/c\" @c,\n  \"x/y\" @y,\n}\n\nsupported_targets = \"+js\"\n"
  let got = parse_imports(src)
  assert_eq(got.length(), 2)
  assert_eq(got[0], "a/b/c")
  assert_eq(got[1], "x/y")
}

///|
test "lines outside the import block are ignored" {
  let src = "options(\n  link: {\n    \"js\": { \"export\": [\"x\", \"y\"] },\n  },\n)"
  let got = parse_imports(src)
  assert_eq(got.length(), 0)
}

///|
test "a moon.pkg without imports yields nothing" {
  assert_eq(parse_imports("").length(), 0)
  assert_eq(parse_imports("supported_targets = \"+js\"").length(), 0)
}

///|
test "package names shorten to the last segment" {
  assert_eq(short_pkg_name("PingGuoMiaoMiao/moondraw/kernel"), "kernel")
  assert_eq(short_pkg_name("moonbit-community/elk/engine/all"), "all")
  assert_eq(short_pkg_name("kernel"), "kernel")
}

///|
test "project graph keeps only internal edges and drops self loops" {
  let entries = [
    ("p/app", "import {\n  \"p/kernel\" @k,\n  \"p/elk\" @e,\n  \"ext/lib\" @x,\n}\n"),
    ("p/kernel", "import {\n  \"p/kernel\" @k,\n}\n"),
    ("p/elk", "import {\n  \"p/kernel\" @k,\n}\n"),
  ]
  let pg = build_project_graph(entries)
  assert_eq(pg.packages.length(), 3)
  // app->kernel, app->elk, elk->kernel ; ext dropped ; self loop dropped
  assert_eq(pg.deps.length(), 3)
  for d in pg.deps {
    assert_true(d.to != d.from)
    assert_true(d.from.has_prefix("p/"))
  }
}

///|
test "duplicate imports produce a single edge" {
  let entries = [
    ("a", "import {\n  \"b\" @b,\n  \"b\" @bb,\n}\n"),
    ("b", ""),
  ]
  let pg = build_project_graph(entries)
  assert_eq(pg.deps.length(), 1)
}

///|
test "degrees summarise the graph" {
  let entries = [
    ("a", "import {\n  \"b\" @b,\n  \"c\" @c,\n}\n"),
    ("b", "import {\n  \"c\" @c,\n}\n"),
    ("c", ""),
  ]
  let pg = build_project_graph(entries)
  let (edges, max_in, max_out) = graph_degrees(pg)
  assert_eq(edges, 3)
  assert_eq(max_in, 2)
  assert_eq(max_out, 2)
}

///|
test "scene has one node per package and one edge per dependency" {
  let entries = [
    ("a", "import {\n  \"b\" @b,\n}\n"),
    ("b", ""),
  ]
  let pg = build_project_graph(entries)
  let sc = scene_from_project(pg)
  assert_eq(sc.shapes.length(), 2)
  assert_eq(sc.edges.length(), 1)
  for e in sc.edges {
    match (find_shape(sc, e.from), find_shape(sc, e.to)) {
      (Some(_), Some(_)) => ()
      _ => fail("edge references a missing shape")
    }
  }
}

///|
test "empty project yields an empty scene" {
  let pg = build_project_graph([])
  let sc = scene_from_project(pg)
  assert_eq(sc.shapes.length(), 0)
  assert_eq(sc.edges.length(), 0)
}
