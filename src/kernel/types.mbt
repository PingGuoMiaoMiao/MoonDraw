///| Shape kinds supported by the editor.
pub(all) enum ShapeKind {
  Rect
  Round
  Diamond
  Ellipse
  Text
  Parallelogram
  Hexagon
  Cylinder
  Document
  Circle
  // --- non-diagram content; same Scene, different payload ---
  /// A chart (bar / line). `data` holds the series.
  Chart
  /// A freehand stroke. `points` holds the polyline.
  Stroke
  /// A gantt bar spanning `start`..`end` on a shared timeline.
  GanttBar
}

///| A diagram node.
pub(all) struct Shape {
  mut id : Int
  kind : ShapeKind
  mut x : Double
  mut y : Double
  mut w : Double
  mut h : Double
  mut text : String
  mut fill : String
  mut stroke : String
  mut group : Int
  /// Chart series, stroke polyline, or empty. Interpreted by `kind`.
  mut data : Array[Double]
  /// Gantt start/end in abstract time units (0..100), unused otherwise.
  mut start : Double
  mut end : Double
  /// Gantt row (0-based), used to stack bars.
  mut lane : Int
}

///| A directed connector between two nodes.
pub(all) struct Edge {
  mut id : Int
  from : Int
  to : Int
  mut label : String
}

///| The document.
pub(all) struct Scene {
  mut shapes : Array[Shape]
  mut edges : Array[Edge]
  mut next_id : Int
}

///| A camera: world -> screen is `world * zoom + cam`.
pub(all) struct View {
  cam_x : Double
  cam_y : Double
  zoom : Double
}
