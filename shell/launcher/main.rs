#![windows_subsystem = "windows"]
// MoonDraw portable launcher.
//
// Zero crates on purpose: this workspace has no crates.io access, so the
// launcher only uses `std`. It embeds the built single-file app, writes it to
// %LOCALAPPDATA%\MoonDraw, and opens it in the Edge/Chrome Chromium shell in
// app mode (no address bar, no tabs) — same engine WebView2 would use.
//
// Usage:
//   MoonDraw.exe                launch the editor
//   MoonDraw.exe --dump-html    write the embedded HTML next to the exe and exit
//   MoonDraw.exe --where        print the resolved browser + html path, exit

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

static APP_HTML: &[u8] = include_bytes!("../../dist/moondraw.html");



fn app_dir() -> PathBuf {
    let base = env::var("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|_| env::temp_dir());
    base.join("MoonDraw")
}

fn log_path() -> PathBuf {
    app_dir().join("launcher.log")
}

fn write_log(msg: &str) {
    let _ = fs::create_dir_all(app_dir());
    let path = log_path();
    let mut prev = fs::read_to_string(&path).unwrap_or_default();
    prev.push_str(msg);
    prev.push('\n');
    let _ = fs::write(path, prev);
}

fn find_browser() -> Option<PathBuf> {
    // Chrome first: it starts reliably in app mode with a fresh profile.
    // Edge is the guaranteed fallback on Windows 10/11.
    let candidates = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ];
    for c in candidates {
        let p = PathBuf::from(c);
        if p.exists() {
            return Some(p);
        }
    }
    // Fall back to whatever Chrome lives in LOCALAPPDATA.
    if let Ok(local) = env::var("LOCALAPPDATA") {
        let p = Path::new(&local)
            .join("Google")
            .join("Chrome")
            .join("Application")
            .join("chrome.exe");
        if p.exists() {
            return Some(p);
        }
    }
    None
}

fn write_html_into(dir: &Path) -> std::io::Result<PathBuf> {
    fs::create_dir_all(dir)?;
    let path = dir.join("moondraw.html");
    fs::write(&path, APP_HTML)?;
    Ok(path)
}

fn exe_dir() -> PathBuf {
    env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."))
}

/// Where the UI file lives. A portable app unpacks next to itself first; only
/// read-only locations fall back to per-user and temp directories.
fn resolve_html() -> Option<PathBuf> {
    let beside = exe_dir().join("moondraw.html");
    if beside.exists() {
        return Some(beside);
    }
    for dir in [exe_dir(), app_dir(), env::temp_dir().join("MoonDraw")] {
        if let Ok(p) = write_html_into(&dir) {
            return Some(p);
        }
    }
    None
}

fn file_url(path: &Path) -> String {
    let s = path.to_string_lossy().replace('\\', "/");
    format!("file:///{}", s)
}

fn trace_path() -> PathBuf {
    env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.join("launcher-trace.txt")))
        .unwrap_or_else(|| PathBuf::from("launcher-trace.txt"))
}

// Minimal Win32 message box, so a broken environment is visible instead of silent.
#[link(name = "user32")]
extern "system" {
    fn MessageBoxW(hwnd: usize, text: *const u16, caption: *const u16, flags: u32) -> i32;
}

fn show_error(title: &str, text: &str) {
    fn wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(std::iter::once(0)).collect()
    }
    let t = wide(text);
    let c = wide(title);
    unsafe {
        MessageBoxW(0, t.as_ptr(), c.as_ptr(), 0x10);
    }
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();

    // Diagnostics go next to the exe first: %LOCALAPPDATA% may be unwritable and
    // we must not die silently in that case.
    let mut trace = format!("args={:?}\n", args);
    trace.push_str(&format!("localappdata={:?}\n", env::var("LOCALAPPDATA")));
    let _ = fs::write(trace_path(), &trace);

    if args.iter().any(|a| a == "--dump-html") {
        let out = env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.join("moondraw.html")))
            .unwrap_or_else(|| PathBuf::from("moondraw.html"));
        match fs::write(&out, APP_HTML) {
            Ok(()) => println!("wrote {} ({} bytes)", out.display(), APP_HTML.len()),
            Err(e) => eprintln!("failed: {}", e),
        }
        return;
    }

    let html = match resolve_html() {
        Some(p) => p,
        None => {
            trace.push_str("no writable location for moondraw.html\n");
            let _ = fs::write(trace_path(), &trace);
            show_error("MoonDraw", "无法写出界面文件，请把 MoonDraw.exe 放到可写目录再试。");
            return;
        }
    };
    trace.push_str(&format!("html={}\n", html.display()));

    let browser = match find_browser() {
        Some(b) => b,
        None => {
            trace.push_str("no browser found\n");
            let _ = fs::write(trace_path(), &trace);
            show_error(
                "MoonDraw",
                "没有找到 Microsoft Edge 或 Google Chrome，无法启动界面。",
            );
            return;
        }
    };
    trace.push_str(&format!("browser={}\n", browser.display()));
    let _ = fs::write(trace_path(), &trace);

    // The browser profile must live somewhere writable too; keep it beside the
    // html so the whole thing stays portable.
    let profile = html.parent().unwrap_or(Path::new(".")).join("profile");
    let _ = fs::create_dir_all(&profile);
    // Chromium skips its first-run screen when this marker exists. Without it,
    // Edge opens an app window that stays blank on a brand-new profile.
    let first_run = profile.join("First Run");
    if !first_run.exists() {
        let _ = fs::write(&first_run, b"");
    }

    // GUI binary: no console, so report through a file instead of stdout.
    if args.iter().any(|a| a == "--where") {
        let report = format!(
            "browser: {}\nhtml:    {}\nprofile: {}\n",
            browser.display(),
            html.display(),
            profile.display()
        );
        let _ = fs::write(exe_dir().join("where.txt"), report);
        return;
    }

    let url = file_url(&html);
    write_log(&format!("launch {} {}", browser.display(), url));

    // Spawning the browser directly from a GUI-subsystem process makes Chrome
    // abort during startup (0x80000003), while going through the shell's `start`
    // works. Use the verified path, with a hidden console so nothing flashes.
    let mut cmd = Command::new("cmd");
    cmd.arg("/C")
        .arg("start")
        .arg("")
        .arg(browser.display().to_string())
        .arg(format!("--app={}", url))
        .arg(format!("--user-data-dir={}", profile.display()))
        .arg("--window-size=1440,900")
        .arg("--no-first-run")
        .arg("--no-default-browser-check")
        // Edge's first-run experience takes over a brand-new profile and leaves
        // the app window blank, so disable it explicitly.
        .arg("--disable-features=msEdgeFirstRunExperience,msEdgeWelcomePage")
        .arg("--no-service-autorun")
        .arg("--disable-sync")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        // DETACHED_PROCESS rather than CREATE_NO_WINDOW: the latter makes `start`
        // create the browser with SW_HIDE, so the window never shows up.
        const DETACHED_PROCESS: u32 = 0x0000_0008;
        cmd.creation_flags(DETACHED_PROCESS);
    }
    let _ = cmd.spawn();
}
