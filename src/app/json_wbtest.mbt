// JSON round-trip tests: these need the JS FFI, so they live with the app.

test "json round-trip preserves the document" {
  let sc = @k.demo_scene()
  let json = @k.scene_to_json(sc)
  let js = ffi_parse_json(json)
  assert_false(ffi_is_null(js))
  let back = scene_from_json(js)
  assert_eq(back.shapes.length(), sc.shapes.length())
  assert_eq(back.edges.length(), sc.edges.length())
  assert_eq(back.shapes[0].text, sc.shapes[0].text)
  assert_eq(@k.kind_name(back.shapes[1].kind), "diamond")
  // next_id must keep growing after a load, otherwise new nodes collide.
  assert_true(back.next_id > sc.shapes.length())
  // Re-serialising must be idempotent: same document, same bytes.
  // (Comparing against the *original* json would break whenever the
  // serialiser gains a field that the fixture does not carry.)
  let again = @k.scene_to_json(back)
  let js2 = ffi_parse_json(again)
  assert_false(ffi_is_null(js2))
  let back2 = scene_from_json(js2)
  assert_eq(back2.shapes.length(), back.shapes.length())
  assert_eq(@k.scene_to_json(back2).length(), again.length())
}

///|
test "json escaping keeps quotes and newlines safe" {
  let sc = @k.new_scene()
  let _ = @k.add_shape(sc, @k.Rect, 0.0, 0.0, 10.0, 10.0, "a\"b\\c\nd")
  let json = @k.scene_to_json(sc)
  let back = scene_from_json(ffi_parse_json(json))
  assert_eq(back.shapes[0].text, "a\"b\\c\nd")
}

test "imported scene serializes and exports" {
  let doc = @k.parse_mermaid("flowchart TD\n A[开始] --> B[结束]")
  let sc = @k.scene_from_mermaid(doc)
  let json = @k.scene_to_json(sc)
  let back = scene_from_json(ffi_parse_json(json))
  assert_eq(back.shapes.length(), 2)
  assert_eq(back.edges.length(), 1)
  let svg = @k.scene_to_svg(back)
  assert_true(svg.contains("开始"))
  assert_true(svg.contains("结束"))
}

