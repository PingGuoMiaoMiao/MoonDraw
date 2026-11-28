// Project graph: read a MoonBit package tree and turn its import edges into a
// diagram. This is the third input dialect — after Mermaid flowcharts and
// indented outlines — and the only one that reads the project itself.

///|
pub struct PkgDep {
  from : String
  to : String
}

///|
pub struct ProjectGraph {
  packages : Array[String]
  deps : Array[PkgDep]
}

///| Extract the quoted module paths from the `import { ... }` block of a
///| `moon.pkg`. Everything outside that block is ignored.
fn parse_imports(src : String) -> Array[String] {
  let out : Array[String] = []
  let mut in_import = false
  let mut depth = 0
  for part in src.split("\n") {
    let line = part.to_owned().trim().trim().to_owned()
    if line.length() == 0 {
      continue
    }
    if !in_import {
      if line.has_prefix("import") {
        in_import = true
        // the `{` may be on the same line
        for c in line {
          if c == '{' {
            depth = depth + 1
          } else if c == '}' {
            depth = depth - 1
          }
        }
        if depth <= 0 && line.has_prefix("import {") && line.contains("}") {
          // single-line import, keep scanning below for contents
          ()
        }
      }
      continue
    }
    // inside the block: pull out the first quoted string of each line
    if line.has_prefix("}") {
      in_import = false
      depth = 0
      continue
    }
    let q1 = first_quote(line)
    if q1 >= 0 {
      let path = substr_until_quote(line, q1 + 1)
      if path.length() > 0 {
        out.push(path)
      }
    }
  }
  out
}

///| Index of the first `"` in a line, or -1.
pub fn first_quote(line : String) -> Int {
  let cs = line.to_array()
  let mut i = 0
  while i < cs.length() {
    if cs[i] == '"' {
      return i
    }
    i = i + 1
  }
  -1
}

///| Text between `start` and the next `"`.
pub fn substr_until_quote(line : String, start : Int) -> String {
  let cs = line.to_array()
  let b = StringBuilder(size_hint=32)
  let mut i = start
  while i < cs.length() && cs[i] != '"' {
    b.write_char(cs[i])
    i = i + 1
  }
  b.to_string()
}

///| Shorten a module path to its last one or two segments, for legibility.
pub fn short_pkg_name(path : String) -> String {
  let cs = path.to_array()
  let mut last = 0
  for i = 0; i < cs.length(); i = i + 1 {
    if cs[i] == '/' {
      last = i + 1
    }
  }
  if last == 0 {
    return path
  }
  substr_from(path, last)
}

///|
fn substr_from(s : String, start : Int) -> String {
  let cs = s.to_array()
  let b = StringBuilder(size_hint=32)
  let mut i = start
  while i < cs.length() {
    b.write_char(cs[i])
    i = i + 1
  }
  b.to_string()
}

///| Build the project graph from (package id, moon.pkg text) pairs.
///
/// `id` is the *module-relative* package path with the module prefix applied,
/// e.g. `PingGuoMiaoMiao/moondraw/kernel`. Import strings are compared against
/// this full id, because that is what `moon.pkg` records.
pub fn build_project_graph(entries : Array[(String, String)]) -> ProjectGraph {
  let names : Array[String] = []
  for e in entries {
    names.push(e.0)
  }
  let known : Array[String] = []
  let deps : Array[PkgDep] = []
  for e in entries {
    let from = e.0
    let seen : Array[String] = []
    for raw in parse_imports(e.1) {
      if !names.contains(raw) {
        continue
      }
      if seen.contains(raw) || raw == from {
        continue
      }
      seen.push(raw)
      deps.push(PkgDep::{ from: from, to: raw })
    }
    known.push(from)
  }
  ProjectGraph::{ packages: known, deps: deps }
}

///| Degree summary used by the CLI report.
pub fn graph_degrees(pg : ProjectGraph) -> (Int, Int, Int) {
  let n = pg.packages.length()
  let indeg : Array[Int] = []
  let outdeg : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    indeg.push(0)
    outdeg.push(0)
  }
  for d in pg.deps {
    let mut fi = -1
    let mut ti = -1
    for i = 0; i < n; i = i + 1 {
      if pg.packages[i] == d.from {
        fi = i
      }
      if pg.packages[i] == d.to {
        ti = i
      }
    }
    if fi >= 0 {
      outdeg[fi] = outdeg[fi] + 1
    }
    if ti >= 0 {
      indeg[ti] = indeg[ti] + 1
    }
  }
  // return (edges, max in-degree, max out-degree)
  let mut mi = 0
  let mut mo = 0
  for i = 0; i < n; i = i + 1 {
    if indeg[i] > mi {
      mi = indeg[i]
    }
    if outdeg[i] > mo {
      mo = outdeg[i]
    }
  }
  (pg.deps.length(), mi, mo)
}

///| Render the project graph as an editable scene, one node per package.
pub fn scene_from_project(pg : ProjectGraph) -> Scene {
  let sc = new_scene()
  let ids : Array[Int] = []
  for p in pg.packages {
    let label = short_pkg_name(p)
    let s = add_shape(sc, Round, 0.0, 0.0, 150.0, 52.0, label)
    ids.push(s.id)
  }
  for d in pg.deps {
    let mut fi = -1
    let mut ti = -1
    for i = 0; i < pg.packages.length(); i = i + 1 {
      if pg.packages[i] == d.from {
        fi = i
      }
      if pg.packages[i] == d.to {
        ti = i
      }
    }
    if fi >= 0 && ti >= 0 {
      let _ = add_edge(sc, ids[fi], ids[ti], "")
    }
  }
  sc
}
