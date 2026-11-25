// Camera math shared by the kernel and every front end. Pure functions.

///|
pub fn sx(v : View, wx : Double) -> Double {
  wx * v.zoom + v.cam_x
}

///|
pub fn sy(v : View, wy : Double) -> Double {
  wy * v.zoom + v.cam_y
}

///|
pub fn wx_of(v : View, x : Double) -> Double {
  (x - v.cam_x) / v.zoom
}

///|
pub fn wy_of(v : View, y : Double) -> Double {
  (y - v.cam_y) / v.zoom
}

