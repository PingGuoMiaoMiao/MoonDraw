// moondraw — render a Mermaid flowchart to SVG/PNG-ready geometry, headless.
//
// This is the engine's primary interface: no browser, no DOM, no canvas.
//     moondraw render <input.mmd> <output.svg> [--algorithm layered] [--direction DOWN]
//     moondraw layout <input.mmd>            # print node coordinates
//     moondraw check  <input.mmd>            # graph sanity: cycles, dangling edges

///|
struct Options {
  algorithm : String
  direction : String
}

///|
fn default_options() -> Options {
  Options::{ algorithm: "layered", direction: "DOWN" }
}

///|
fn parse_options(args : Array[String]) -> Options {
  let mut opts = default_options()
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == "--algorithm" && i + 1 < args.length() {
      opts = { algorithm: args[i + 1], direction: opts.direction }
      i = i + 2
    } else if a == "--direction" && i + 1 < args.length() {
      opts = { algorithm: opts.algorithm, direction: args[i + 1] }
      i = i + 2
    } else {
      i = i + 1
    }
  }
  opts
}

///|
fn positional(args : Array[String]) -> Array[String] {
  let out : Array[String] = []
  let mut skip = false
  for i = 0; i < args.length(); i = i + 1 {
    let a = args[i]
    if skip {
      skip = false
    } else if a == "--algorithm" || a == "--direction" {
      skip = true
    } else if a.has_prefix("--") {
      ()
    } else {
      out.push(a)
    }
  }
  out
}

///| Graph sanity report: cycles, dangling edges, isolated nodes.
fn check_graph(scene : @k.Scene) -> StringBuilder {
  let b = StringBuilder(size_hint=256)
  let n = scene.shapes.length()
  let e = scene.edges.length()
  let indeg : Array[Int] = []
  let outdeg : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    indeg.push(0)
    outdeg.push(0)
  }
  let ids : Array[Int] = []
  for s in scene.shapes {
    ids.push(s.id)
  }
  let mut dangling = 0
  for edge in scene.edges {
    let fi = index_of(ids, edge.from)
    let ti = index_of(ids, edge.to)
    if fi < 0 || ti < 0 {
      dangling = dangling + 1
    } else {
      outdeg[fi] = outdeg[fi] + 1
      indeg[ti] = indeg[ti] + 1
    }
  }
  let mut isolated = 0
  for i = 0; i < n; i = i + 1 {
    if indeg[i] == 0 && outdeg[i] == 0 {
      isolated = isolated + 1
    }
  }
  b.write_string("节点 ")
  b.write_string(n.to_string())
  b.write_string(" · 边 ")
  b.write_string(e.to_string())
  if dangling > 0 {
    b.write_string(" · 悬空边 ")
    b.write_string(dangling.to_string())
  }
  if isolated > 0 {
    b.write_string(" · 孤立节点 ")
    b.write_string(isolated.to_string())
  }
  if has_cycle(scene) {
    b.write_string(" · ⚠ 存在环")
  } else {
    b.write_string(" · 无环")
  }
  b
}

///|
fn index_of(ids : Array[Int], id : Int) -> Int {
  let mut found = -1
  for i = 0; i < ids.length(); i = i + 1 {
    if ids[i] == id {
      found = i
    }
  }
  found
}

///| Depth-first cycle detection over the edge set.
fn has_cycle(scene : @k.Scene) -> Bool {
  let ids : Array[Int] = []
  for s in scene.shapes {
    ids.push(s.id)
  }
  let n = ids.length()
  let state : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    state.push(0)
  }
  for start = 0; start < n; start = start + 1 {
    if state[start] == 0 && visit(scene, ids, state, start) {
      return true
    }
  }
  false
}

///|
fn visit(scene : @k.Scene, ids : Array[Int], state : Array[Int], at : Int) -> Bool {
  state[at] = 1
  for e in scene.edges {
    let fi = index_of(ids, e.from)
    let ti = index_of(ids, e.to)
    if fi == at && ti >= 0 {
      if state[ti] == 1 {
        return true
      }
      if state[ti] == 0 && visit(scene, ids, state, ti) {
        return true
      }
    }
  }
  state[at] = 2
  false
}

///|
fn usage() -> Unit {
  println("moondraw — MoonBit structured diagram engine")
  println("")
  println("用法:")
  println("  moondraw render <in.mmd> <out.svg> [--algorithm layered] [--direction DOWN]")
  println("  moondraw layout <in.mmd> [--algorithm layered] [--direction RIGHT]")
  println("  moondraw check  <in.mmd>")
  println("")
  println("算法: layered / force / stress / mrtree / radial / rectpacking")
  println("方向: DOWN / RIGHT / UP / LEFT")
}

///|
async fn run(args : Array[String]) -> Unit {
  if args.length() < 2 {
    usage()
    return
  }
  let cmd = args[1]
  let rest : Array[String] = []
  for i = 1; i < args.length(); i = i + 1 {
    rest.push(args[i])
  }
  let pos = positional(rest)
  if cmd == "--help" || cmd == "-h" || cmd == "help" {
    usage()
    return
  }
  if cmd != "render" && cmd != "layout" && cmd != "check" {
    println("未知命令: " + cmd)
    usage()
    return
  }
  if pos.length() < 2 {
    println("缺少输入文件")
    usage()
    return
  }
  let input = pos[1]
  let opts = parse_options(rest)
  let src = @fs.read_file(input).text()
  let doc = @k.parse_mermaid(src)
  if doc.nodes.length() == 0 {
    println("解析失败：没有识别到节点（只支持 Mermaid flowchart 子集）")
    return
  }
  let scene = @k.scene_from_mermaid(doc)
  let elk_err = @elk_layout.layout_with_elk(scene, opts.algorithm, opts.direction)
  if elk_err.length() > 0 {
    println("ELK 布局: " + elk_err + "（已回退到内置分层布局）")
  }
  match cmd {
    "check" => {
      println(check_graph(scene).to_string())
    }
    "layout" => {
      println(check_graph(scene).to_string())
      for s in scene.shapes {
        println(
          "  " + s.text + "  @(" + s.x.to_int().to_string() + "," +
          s.y.to_int().to_string() + ")",
        )
      }
    }
    _ => {
      if pos.length() < 3 {
        println("缺少输出文件")
        return
      }
      let svg = @k.scene_to_svg(scene)
      @fs.write_file(pos[2], svg)
      println(
        "已写入 " + pos[2] + " · " + check_graph(scene).to_string(),
      )
    }
  }
}

///|
async fn main {
  let args = @env.args()
  run(args)
}
