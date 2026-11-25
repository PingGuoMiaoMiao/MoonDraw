///| Command-line demo: turn a Mermaid flowchart into SVG without a browser.
///| Proves the kernel (parse → layout → export) runs outside the DOM.
fn sample() -> String {
  "flowchart TD\n  A[收到工单] --> B{是否 P1}\n  B -->|是| C(立即响应)\n  B -->|否| D(排期处理)\n  C --> E((结单))\n  D --> E"
}

fn main {
  let doc = @k.parse_mermaid(sample())
  println("节点: " + doc.nodes.length().to_string() + "  连线: " + doc.edges.length().to_string())
  let sc = @k.scene_from_mermaid(doc)
  for s in sc.shapes {
    println("  " + s.text + "  @(" + s.x.to_int().to_string() + "," + s.y.to_int().to_string() + ")")
  }
  let svg = @k.scene_to_svg(sc)
  println("SVG: " + svg.length().to_string() + " 字节")
  println(svg)
}
