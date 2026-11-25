// App-side records: a tab holds the serialised form of every inactive doc.

///| One tab. Holds the serialized scene for every *inactive* document; the
///| active one lives in `App.scene` so hot paths never touch JSON.
pub struct Doc {
  mut name : String
  mut json : String
  mut cam_x : Double
  mut cam_y : Double
  mut zoom : Double
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

///| Editor state.
pub struct App {
  mut scene : @k.Scene
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

///|
pub fn App::view(self : App) -> @k.View {
  @k.View::{ cam_x: self.cam_x, cam_y: self.cam_y, zoom: self.zoom }
}

