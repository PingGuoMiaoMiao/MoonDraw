// Tauri shell for MoonDraw.
//
// The frontend is the single-file build produced by `tools/build-exe.ps1`
// (dist/index.html), so this crate only needs to create the window. All editor
// logic stays in MoonBit — nothing here knows about the document model.

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running MoonDraw");
}
