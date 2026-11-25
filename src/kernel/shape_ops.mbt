// Mutators for shape/edge fields. Kept in the kernel so the data types stay
// mutable only through named operations, and so the kernel owns the semantics
// of "moving", "resizing" and "relabelling".

///|
pub fn Shape::place(self : Shape, x : Double, y : Double) -> Unit {
  self.x = x
  self.y = y
}

///|
pub fn Shape::resize_to(self : Shape, w : Double, h : Double) -> Unit {
  self.w = w
  self.h = h
}

///|
pub fn Shape::set_text(self : Shape, text : String) -> Unit {
  self.text = text
}

///|
pub fn Shape::restyle(self : Shape, fill : String, stroke : String) -> Unit {
  self.fill = fill
  self.stroke = stroke
}

///|
pub fn Shape::reassign_id(self : Shape, id : Int) -> Unit {
  self.id = id
}

///|
pub fn Edge::set_label(self : Edge, label : String) -> Unit {
  self.label = label
}

///|
pub fn Edge::reassign_id(self : Edge, id : Int) -> Unit {
  self.id = id
}

///|
pub fn Shape::set_group(self : Shape, group : Int) -> Unit {
  self.group = group
}
