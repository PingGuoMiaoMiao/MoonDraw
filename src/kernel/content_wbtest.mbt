// Tests for the three non-diagram content builders.

///|
test "parse a numeric series" {
  let s = parse_series("一月,12\n二月,30\n三月:18")
  assert_eq(s.labels.length(), 3)
  assert_eq(s.values.length(), 3)
  assert_eq(s.labels[0], "一月")
  assert_eq(s.values[1], 30.0)
  assert_eq(s.values[2], 18.0)
}

///|
test "series skips bad lines and comments" {
  let s = parse_series("# 注释\n\n坏行\n好,5\n")
  assert_eq(s.values.length(), 1)
  assert_eq(s.values[0], 5.0)
}

///|
test "number parser handles signs and decimals" {
  assert_eq(parse_number("42"), Some(42.0))
  assert_eq(parse_number("-3.5"), Some(-3.5))
  assert_eq(parse_number("+0.25"), Some(0.25))
  assert_eq(parse_number("abc"), None)
  assert_eq(parse_number("1.2.3"), None)
}

///|
test "chart shape carries the series" {
  let sc = new_scene()
  let s = parse_series("a,10\nb,20")
  let chart = add_chart(sc, s, "bar", 0.0, 0.0, 300.0, 180.0)
  assert_eq(chart.data.length(), 2)
  assert_eq(chart_max(chart), 20.0)
  let labels = chart_labels(chart)
  assert_eq(labels.length(), 2)
  assert_eq(labels[1], "b")
  assert_eq(kind_name(chart.kind), "chart")
}

///|
test "a stroke keeps its polyline and bounding box" {
  let sc = new_scene()
  let pts = [10.0, 10.0, 40.0, 60.0, 80.0, 20.0]
  let st = add_stroke(sc, pts, "#e2162a")
  assert_eq(st.data.length(), 6)
  assert_eq(st.x, 10.0)
  assert_eq(st.y, 10.0)
  assert_eq(st.w, 70.0)
  assert_eq(st.h, 50.0)
  assert_eq(kind_name(st.kind), "stroke")
  assert_eq(st.stroke, "#e2162a")
}

///|
test "gantt tasks parse and lay out as bars" {
  let tasks = parse_gantt("设计,0,3\n开发,3,5\n测试,8,2")
  assert_eq(tasks.length(), 3)
  assert_eq(tasks[0].name, "设计")
  assert_eq(tasks[1].start, 3.0)
  assert_eq(tasks[2].duration, 2.0)
  let sc = new_scene()
  add_gantt(sc, tasks, 0.0, 0.0, 400.0)
  // one label + one bar per task
  assert_eq(sc.shapes.length(), 6)
  let mut bars = 0
  for s in sc.shapes {
    match s.kind {
      GanttBar => bars = bars + 1
      _ => ()
    }
  }
  assert_eq(bars, 3)
}

///|
test "gantt bars are proportional to the timeline" {
  let tasks = parse_gantt("a,0,5\nb,5,5")
  let sc = new_scene()
  add_gantt(sc, tasks, 0.0, 0.0, 100.0)
  let widths : Array[Double] = []
  for s in sc.shapes {
    match s.kind {
      GanttBar => widths.push(s.w)
      _ => ()
    }
  }
  assert_eq(widths.length(), 2)
  assert_true(absd(widths[0] - widths[1]) < 0.001)
  assert_true(widths[0] > 40.0 && widths[0] < 60.0)
}

///|
test "artboard is the largest rectangle" {
  let sc = new_scene()
  let art = add_artboard(sc, "A4", 794.0, 1123.0)
  let _ = add_shape(sc, Rect, 40.0, 40.0, 100.0, 60.0, "small")
  match artboard_bounds(sc) {
    Some(b) => {
      assert_eq(b.0, art.x)
      assert_eq(b.2, art.x + 794.0)
    }
    None => fail("expected artboard")
  }
}

///|
test "no artboard yields none" {
  let sc = new_scene()
  assert_true(artboard_bounds(sc) is None)
}

///|
test "new kinds survive a JSON round-trip" {
  let sc = new_scene()
  let s = parse_series("a,1\nb,2")
  let _ = add_chart(sc, s, "line", 0.0, 0.0, 200.0, 120.0)
  let tasks = parse_gantt("x,0,2")
  add_gantt(sc, tasks, 0.0, 200.0, 300.0)
  let _ = add_artboard(sc, "frame", 400.0, 300.0)
  let json = scene_to_json(sc)
  // the kernel only serialises; parsing lives in the app package
  assert_true(json.contains("\"kind\":\"chart\""))
  assert_true(json.contains("\"kind\":\"gantt\""))
  assert_true(json.contains("\"kind\":\"rect\""))
}

///|
test "whiteboard strokes parse from text" {
  let src = "# 注释\n20,20 40,60 60,20\n\n10,10 50,50"
  let strokes = parse_strokes(src)
  assert_eq(strokes.length(), 2)
  assert_eq(strokes[0].length(), 6)
  assert_eq(strokes[1].length(), 4)
  assert_eq(strokes[0][2], 40.0)
}

///|
test "strokes shorter than two points are dropped" {
  let strokes = parse_strokes("10,10")
  assert_eq(strokes.length(), 0)
}

///|
test "scene from strokes keeps one shape per stroke" {
  let strokes = parse_strokes("10,10 50,50\n100,100 200,150")
  let sc = scene_from_strokes(strokes, "#e2162a")
  assert_eq(sc.shapes.length(), 2)
  for s in sc.shapes {
    assert_eq(kind_name(s.kind), "stroke")
    assert_eq(s.stroke, "#e2162a")
  }
}
