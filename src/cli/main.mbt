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
  has_algorithm : Bool
  has_direction : Bool
}

///|
fn default_options() -> Options {
  Options::{
    algorithm: "layered",
    direction: "DOWN",
    has_algorithm: false,
    has_direction: false,
  }
}

///|
fn parse_options(args : Array[String]) -> Options {
  let mut opts = default_options()
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == "--algorithm" && i + 1 < args.length() {
      opts = {
        algorithm: args[i + 1],
        direction: opts.direction,
        has_algorithm: true,
        has_direction: opts.has_direction,
      }
      i = i + 2
    } else if a == "--direction" && i + 1 < args.length() {
      opts = {
        algorithm: opts.algorithm,
        direction: args[i + 1],
        has_algorithm: opts.has_algorithm,
        has_direction: true,
      }
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

///| Walk a module tree and collect (package path, moon.pkg text) pairs.
///| Package identity comes from the package directory relative to `root`.
async fn scan_packages(root : String) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let mod = module_name(root)
  let stack : Array[String] = []
  stack.push(root)
  while stack.length() > 0 {
    let dir = stack.pop().unwrap()
    let entries = @fs.readdir(dir) catch { _ => [] }
    for name in entries {
      if name == ".mooncakes" || name == "_build" || name == ".git" || name == "target" {
        continue
      }
      let full = dir + "/" + name
      let k = @fs.kind(full) catch { _ => @fs.FileKind::Unknown }
      match k {
        @fs.FileKind::Directory => stack.push(full)
        @fs.FileKind::Regular =>
          if name == "moon.pkg" {
            let text = @fs.read_file(full).text() catch { _ => "" }
            out.push((pkg_id(mod, root, dir), text))
          }
        _ => ()
      }
    }
  }
  out
}

///| Build the module-qualified package id that `moon.pkg` imports use:
///| `root/src/kernel` -> `<module-name>/kernel`.
fn pkg_id(module_name : String, root : String, dir : String) -> String {
  let r = root.replace_all(old="\\", new="/")
  let d = dir.replace_all(old="\\", new="/")
  let mut s = d
  if s.has_prefix(r) {
    s = s.substring(start=r.length(), end=s.length())
  }
  while s.has_prefix("/") {
    s = s.substring(start=1, end=s.length())
  }
  if s.has_prefix("src/") {
    s = s.substring(start=4, end=s.length())
  }
  if s.length() == 0 {
    module_name
  } else {
    module_name + "/" + s
  }
}

///| Read `name = "..."` from a moon.mod, falling back to the directory name.
async fn module_name(root : String) -> String {
  let path = root + "/moon.mod"
  let text = @fs.read_file(path).text() catch { _ => "" }
  for part in text.split("\n") {
    let line = part.to_owned().trim().to_owned()
    if line.has_prefix("name") {
      let q1 = @k.first_quote(line)
      if q1 >= 0 {
        let v = @k.substr_until_quote(line, q1 + 1)
        if v.length() > 0 {
          return v
        }
      }
    }
  }
  "module"
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
  println("  moondraw mindmap <in.md> <out.svg>      # 缩进大纲 -> 思维导图")
  println("  moondraw deps <moon.mod 所在目录> <out.svg>   # MoonBit 包依赖图")
  println("")
  println("算法: layered / force / stress / mrtree / radial / rectpacking")
  println("mindmap 默认使用 mrtree + RIGHT（树形横向展开）")
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
  if cmd != "render" && cmd != "layout" && cmd != "check" && cmd != "mindmap" && cmd != "deps" {
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
  // mindmap defaults to a tree layout; explicit flags still win.
  let given = parse_options(rest)
  let opts = if cmd == "mindmap" {
    Options::{
      algorithm: if given.has_algorithm { given.algorithm } else { "mrtree" },
      direction: if given.has_direction { given.direction } else { "RIGHT" },
      has_algorithm: given.has_algorithm,
      has_direction: given.has_direction,
    }
  } else {
    given
  }
  if cmd == "deps" {
    let entries = scan_packages(input)
    let pg = @k.build_project_graph(entries)
    if pg.packages.length() == 0 {
      println("没有找到 moon.pkg：请指定模块根目录")
      return
    }
    let (edges, max_in, max_out) = @k.graph_degrees(pg)
    println(
      "包 " + pg.packages.length().to_string() + " · 依赖 " + edges.to_string() +
      " · 最大入度 " + max_in.to_string() + " · 最大出度 " + max_out.to_string(),
    )
    let scene = @k.scene_from_project(pg)
    let err = @elk_layout.layout_with_elk(scene, "layered", "DOWN")
    if err.length() > 0 && cmd == "deps" {
      println("ELK: " + err)
    }
    if pos.length() >= 3 {
      let svg = @k.scene_to_svg(scene)
      @fs.write_file(pos[2], svg)
      println("已写入 " + pos[2])
    } else {
      for s in scene.shapes {
        println("  " + s.text + "  @(" + s.x.to_int().to_string() + "," + s.y.to_int().to_string() + ")")
      }
    }
    return
  }
  let src = @fs.read_file(input).text()
  let scene = if cmd == "mindmap" || input.has_suffix(".md") || input.has_suffix(".txt") {
    let mm = @k.parse_outline(src)
    if mm.texts.length() == 0 {
      println("解析失败：大纲为空")
      return
    }
    @k.scene_from_outline(mm)
  } else {
    let doc = @k.parse_mermaid(src)
    if doc.nodes.length() == 0 {
      println("解析失败：没有识别到节点（支持 Mermaid flowchart 与缩进大纲）")
      return
    }
    @k.scene_from_mermaid(doc)
  }
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
