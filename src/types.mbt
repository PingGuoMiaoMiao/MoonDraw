///| Shape kinds supported by the editor.
pub enum ShapeKind {
  Rect
  Round
  Diamond
  Ellipse
  Text
}

///| A diagram node.
pub struct Shape {
  mut id : Int
  kind : ShapeKind
  mut x : Double
  mut y : Double
  mut w : Double
  mut h : Double
  mut text : String
  mut fill : String
  mut stroke : String
}

///| A directed connector between two nodes.
pub struct Edge {
  mut id : Int
  from : Int
  to : Int
  mut label : String
}

///| The document.
pub struct Scene {
  mut shapes : Array[Shape]
  mut edges : Array[Edge]
  mut next_id : Int
}

///| A camera: world -> screen is `world * zoom + cam`.
pub struct View {
  cam_x : Double
  cam_y : Double
  zoom : Double
}

///| Current pointer gesture.
pub enum Drag {
  Idle
  /// Moving the current selection; payload is the grab point in world space.
  Move(Double, Double)
  /// Rubber-band selection; payload is the anchor in world space.
  Band(Double, Double)
  Create(Int, Double, Double)
  Resize(Int, Int)
  Pan(Double, Double, Double, Double)
  Connect(Int)
}

///| One tab. Holds the serialized scene for every *inactive* document; the
///| active one lives in `App.scene` so hot paths never touch JSON.
pub struct Doc {
  mut name : String
  mut json : String
  mut cam_x : Double
  mut cam_y : Double
  mut zoom : Double
}

///| Editor state.
pub struct App {
  mut scene : Scene
  mut cam_x : Double
  mut cam_y : Double
  mut zoom : Double
  mut tool : String
  /// Selected shapes, in selection order.
  mut sel : Array[Int]
  /// Selected connector id, or -1.
  mut sel_edge : Int
  mut drag : Drag
  mut mx : Double
  mut my : Double
  /// Positions captured when a move gesture starts: (id, x, y).
  mut drag_from : Array[(Int, Double, Double)]
  /// Alignment guides to draw this frame: (x1, y1, x2, y2).
  mut guides : Array[(Double, Double, Double, Double)]
  /// Tabs; `active` indexes the one currently in `scene`.
  mut docs : Array[Doc]
  mut active : Int
  undo : Array[String]
  mut undo_len : Int
  redo : Array[String]
  mut redo_len : Int
}
