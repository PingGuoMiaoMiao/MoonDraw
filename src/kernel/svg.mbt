///|
pub fn xml_escape(s : String) -> String {
  s.replace_all(old="&", new="&amp;")
    .replace_all(old="<", new="&lt;")
    .replace_all(old=">", new="&gt;")
    .replace_all(old="\"", new="&quot;")
}

///|
pub fn fmt(d : Double) -> String {
  d.to_string()
}

///|
pub fn text_width_approx(s : String, size : Double) -> Double {
  size * 0.58 * s.length().to_double()
}

///| Render the document as SVG, cropped to `box` (world coordinates) with the
///| given padding.
pub fn scene_to_svg_in(
  scene : Scene,
  box : (Double, Double, Double, Double),
  pad : Double,
) -> String {
  let min_x = box.0 - pad
  let min_y = box.1 - pad
  let max_x = box.2 + pad
  let max_y = box.3 + pad
  let vw = maxd(max_x - min_x, 1.0)
  let vh = maxd(max_y - min_y, 1.0)
  let b = StringBuilder(size_hint=4096)
  b.write_string("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"")
  b.write_string(vw.to_int().to_string())
  b.write_string("\" height=\"")
  b.write_string(vh.to_int().to_string())
  b.write_string("\" viewBox=\"")
  b.write_string(fmt(min_x))
  b.write_string(" ")
  b.write_string(fmt(min_y))
  b.write_string(" ")
  b.write_string(fmt(vw))
  b.write_string(" ")
  b.write_string(fmt(vh))
  b.write_string("\">")
  b.write_string("<rect x=\"")
  b.write_string(fmt(min_x))
  b.write_string("\" y=\"")
  b.write_string(fmt(min_y))
  b.write_string("\" width=\"")
  b.write_string(fmt(vw))
  b.write_string("\" height=\"")
  b.write_string(fmt(vh))
  b.write_string("\" fill=\"#ffffff\"/>")
  for e in scene.edges {
    let a = find_shape(scene, e.from)
    let bnode = find_shape(scene, e.to)
    match (a, bnode) {
      (Some(sa), Some(sb)) => {
        let pts = route(sa, sb)
        b.write_string("<polyline fill=\"none\" stroke=\"#a3a3a3\" stroke-width=\"1.6\" points=\"")
        for p in pts {
          b.write_string(fmt(p.0))
          b.write_string(",")
          b.write_string(fmt(p.1))
          b.write_string(" ")
        }
        b.write_string("\"/>")
        let last = pts[pts.length() - 1]
        let prev = pts[pts.length() - 2]
        let dx = last.0 - prev.0
        let dy = last.1 - prev.1
        let len = sqrt_d(dx * dx + dy * dy)
        if len > 0.01 {
          let ux = dx / len
          let uy = dy / len
          let size = 9.0
          let bx = last.0 - ux * size
          let by = last.1 - uy * size
          let px = -uy * size * 0.45
          let py = ux * size * 0.45
          b.write_string("<polygon fill=\"#a3a3a3\" points=\"")
          b.write_string(fmt(last.0))
          b.write_string(",")
          b.write_string(fmt(last.1))
          b.write_string(" ")
          b.write_string(fmt(bx + px))
          b.write_string(",")
          b.write_string(fmt(by + py))
          b.write_string(" ")
          b.write_string(fmt(bx - px))
          b.write_string(",")
          b.write_string(fmt(by - py))
          b.write_string("\"/>")
        }
        if e.label.length() > 0 {
          let mid = pts[1]
          let mid2 = pts[2]
          let lx = (mid.0 + mid2.0) * 0.5
          let ly = (mid.1 + mid2.1) * 0.5
          let tw = text_width_approx(e.label, 12.0) + 14.0
          b.write_string("<rect x=\"")
          b.write_string(fmt(lx - tw * 0.5))
          b.write_string("\" y=\"")
          b.write_string(fmt(ly - 10.0))
          b.write_string("\" width=\"")
          b.write_string(fmt(tw))
          b.write_string("\" height=\"20\" rx=\"6\" fill=\"#ffffff\"/>")
          b.write_string("<text x=\"")
          b.write_string(fmt(lx))
          b.write_string("\" y=\"")
          b.write_string(fmt(ly))
          b.write_string("\" text-anchor=\"middle\" dominant-baseline=\"central\" font-family=\"sans-serif\" font-size=\"12\" fill=\"#475569\">")
          b.write_string(xml_escape(e.label))
          b.write_string("</text>")
        }
      }
      _ => ()
    }
  }
  for s in scene.shapes {
    match s.kind {
      Round => {
        b.write_string("<rect x=\"")
        b.write_string(fmt(s.x))
        b.write_string("\" y=\"")
        b.write_string(fmt(s.y))
        b.write_string("\" width=\"")
        b.write_string(fmt(s.w))
        b.write_string("\" height=\"")
        b.write_string(fmt(s.h))
        b.write_string("\" rx=\"9\" fill=\"")
        b.write_string(s.fill)
        b.write_string("\" stroke=\"")
        b.write_string(s.stroke)
        b.write_string("\" stroke-width=\"1.5\"/>")
      }
      Diamond => {
        let cx = center_x(s)
        let cy = center_y(s)
        b.write_string("<polygon points=\"")
        b.write_string(fmt(cx))
        b.write_string(",")
        b.write_string(fmt(s.y))
        b.write_string(" ")
        b.write_string(fmt(s.x + s.w))
        b.write_string(",")
        b.write_string(fmt(cy))
        b.write_string(" ")
        b.write_string(fmt(cx))
        b.write_string(",")
        b.write_string(fmt(s.y + s.h))
        b.write_string(" ")
        b.write_string(fmt(s.x))
        b.write_string(",")
        b.write_string(fmt(cy))
        b.write_string("\" fill=\"")
        b.write_string(s.fill)
        b.write_string("\" stroke=\"")
        b.write_string(s.stroke)
        b.write_string("\" stroke-width=\"1.5\"/>")
      }
      Ellipse => {
        b.write_string("<ellipse cx=\"")
        b.write_string(fmt(center_x(s)))
        b.write_string("\" cy=\"")
        b.write_string(fmt(center_y(s)))
        b.write_string("\" rx=\"")
        b.write_string(fmt(s.w * 0.5))
        b.write_string("\" ry=\"")
        b.write_string(fmt(s.h * 0.5))
        b.write_string("\" fill=\"")
        b.write_string(s.fill)
        b.write_string("\" stroke=\"")
        b.write_string(s.stroke)
        b.write_string("\" stroke-width=\"1.5\"/>")
      }
      Text => ()
      _ => {
        b.write_string("<rect x=\"")
        b.write_string(fmt(s.x))
        b.write_string("\" y=\"")
        b.write_string(fmt(s.y))
        b.write_string("\" width=\"")
        b.write_string(fmt(s.w))
        b.write_string("\" height=\"")
        b.write_string(fmt(s.h))
        b.write_string("\" fill=\"")
        b.write_string(s.fill)
        b.write_string("\" stroke=\"")
        b.write_string(s.stroke)
        b.write_string("\" stroke-width=\"1.5\"/>")
      }
    }
    if s.text.length() > 0 {
      b.write_string("<text x=\"")
      b.write_string(fmt(center_x(s)))
      b.write_string("\" y=\"")
      b.write_string(fmt(center_y(s)))
      b.write_string("\" text-anchor=\"middle\" dominant-baseline=\"central\" font-family=\"'Microsoft YaHei', 'PingFang SC', sans-serif\" font-size=\"13\" fill=\"")
      match s.kind {
        Text => b.write_string("#0070f3")
        _ => b.write_string("#171717")
      }
      b.write_string("\">")
      b.write_string(xml_escape(s.text))
      b.write_string("</text>")
    }
  }
  b.write_string("</svg>")
  b.to_string()
}

///| Whole-document export (kept for compatibility with the unit tests).
pub fn scene_to_svg(scene : Scene) -> String {
  let b = scene_bounds(scene)
  let box = if b.2 - b.0 < 1.0 || b.3 - b.1 < 1.0 {
    (0.0, 0.0, 800.0, 600.0)
  } else {
    b
  }
  scene_to_svg_in(scene, box, 48.0)
}