// Outline (mind map) parsing tests.

///|
test "indent width counts spaces and tabs" {
  assert_eq(indent_width("abc"), 0)
  assert_eq(indent_width("  abc"), 2)
  assert_eq(indent_width("\tabc"), 4)
  assert_eq(indent_width("    abc"), 4)
}

///|
test "list markers and bullets are stripped" {
  assert_eq(outline_text("- 根节点"), "根节点")
  assert_eq(outline_text("* 星号"), "星号")
  assert_eq(outline_text("+ 加号"), "加号")
  assert_eq(outline_text("1. 第一步"), "第一步")
  assert_eq(outline_text("2) 第二步"), "第二步")
  assert_eq(outline_text("  - 缩进项"), "缩进项")
}

///|
test "plain text without a marker is kept" {
  assert_eq(outline_text("普通文字"), "普通文字")
}

///|
test "a simple outline builds a tree" {
  let src = "- 根\n  - 子一\n  - 子二\n    - 孙\n- 根二"
  let mm = parse_outline(src)
  assert_eq(mm.texts.length(), 5)
  assert_eq(mm.texts[0], "根")
  assert_eq(mm.parents[0], -1)
  assert_eq(mm.texts[1], "子一")
  assert_eq(mm.parents[1], 0)
  assert_eq(mm.parents[3], 2)
  assert_eq(mm.depths[3], 2)
  assert_eq(mm.parents[4], -1)
}

///|
test "dedenting returns to the right parent" {
  let src = "- A\n  - B\n    - C\n  - D"
  let mm = parse_outline(src)
  assert_eq(mm.texts.length(), 4)
  // D is a sibling of B, not a child of C
  assert_eq(mm.parents[3], 0)
  assert_eq(mm.depths[3], 1)
}

///|
test "blank lines and headings are skipped" {
  let src = "# 标题\n\n- 甲\n\n\n- 乙\n"
  let mm = parse_outline(src)
  assert_eq(mm.texts.length(), 2)
  assert_eq(mm.texts[0], "甲")
  assert_eq(mm.texts[1], "乙")
}

///|
test "scene keeps one shape per line and one edge per parent" {
  let mm = parse_outline("- 根\n  - 子一\n  - 子二\n    - 孙")
  let sc = scene_from_outline(mm)
  assert_eq(sc.shapes.length(), 4)
  assert_eq(sc.edges.length(), 3)
  // roots use the rounded kind
  assert_eq(kind_name(sc.shapes[0].kind), "round")
  // children are indented to the right
  assert_true(sc.shapes[1].x > sc.shapes[0].x)
  assert_true(sc.shapes[3].x > sc.shapes[2].x)
  // every edge points at real shapes
  for e in sc.edges {
    match (find_shape(sc, e.from), find_shape(sc, e.to)) {
      (Some(_), Some(_)) => ()
      _ => fail("edge references a missing shape")
    }
  }
}

///|
test "empty outline yields an empty scene" {
  let mm = parse_outline("")
  assert_eq(mm.texts.length(), 0)
  let sc = scene_from_outline(mm)
  assert_eq(sc.shapes.length(), 0)
  assert_eq(sc.edges.length(), 0)
}

///|
test "deep nesting does not lose nodes" {
  let src = "- L0\n  - L1\n    - L2\n      - L3\n        - L4"
  let mm = parse_outline(src)
  assert_eq(mm.texts.length(), 5)
  assert_eq(mm.depths[4], 4)
  let sc = scene_from_outline(mm)
  assert_eq(sc.shapes.length(), 5)
  assert_eq(sc.edges.length(), 4)
}
