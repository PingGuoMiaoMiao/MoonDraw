///| Shape kinds supported by the editor.
pub(all) enum ShapeKind {
  Rect
  Round
  Diamond
  Ellipse
  Text
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
