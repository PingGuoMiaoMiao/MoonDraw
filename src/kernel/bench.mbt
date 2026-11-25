// Kernel benchmark: builds a 1000-node document and serialises it.
// Uses a monotonic clock when the backend has one, otherwise reports 0.

///| Serialize a 1000-node document end to end (kernel cost only, no canvas).
pub fn kernel_bench(count : Int, now : () -> Double) -> Unit {
  let sc = new_scene()
  let cols = 40
  for i = 0; i < count; i = i + 1 {
    let col = i % cols
    let row = i / cols
    let _ = add_shape(
      sc,
      Rect,
      col.to_double() * 200.0,
      row.to_double() * 120.0,
      150.0,
      64.0,
      "节点 " + i.to_string(),
    )
    if i > 0 {
      let _ = add_edge(sc, i, i + 1, "")
    }
  }
  let t0 = now()
  let json = scene_to_json(sc)
  let t1 = now()
  let svg = scene_to_svg(sc)
  let t2 = now()
  let b = StringBuilder(size_hint=96)
  b.write_string(count.to_string())
  b.write_string(" 节点 · JSON ")
  b.write_string((t1 - t0).to_string())
  b.write_string(" ms / ")
  b.write_string(json.length().to_string())
  b.write_string(" B · SVG ")
  b.write_string((t2 - t1).to_string())
  b.write_string(" ms / ")
  b.write_string(svg.length().to_string())
  b.write_string(" B")
  println("KERNEL " + b.to_string())
}

// ---------------------------------------------------------------------------
// Files (M3)
// ---------------------------------------------------------------------------

///|
