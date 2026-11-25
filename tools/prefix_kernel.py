"""Prefix kernel symbols with @k. inside the app package.

Token-level rewrite that respects string/char literals, comments, parameter
labels (`name : Type`) and raw `#|` JavaScript lines. Names the app package
defines itself are never touched, and already-qualified `@k.x` stays as is.
"""

import glob
import io
import re

QUOTE = '"'
APOS = "'"


def scan_defs(paths):
    names = set()
    for path in paths:
        src = io.open(path, encoding="utf-8").read()
        for m in re.finditer(r"^(?:pub\s+)?(?:async\s+)?fn\s+(?:\w+::)?([A-Za-z_]\w*)", src, re.M):
            names.add(m.group(1))
        for m in re.finditer(r"^(?:pub\s+)?(?:struct|enum|type|let)\s+([A-Za-z_]\w*)", src, re.M):
            names.add(m.group(1))
        for m in re.finditer(r"^(?:pub\s+)?enum\s+\w+\s*\{(.*?)\n\}", src, re.M | re.S):
            for c in re.finditer(r"^\s{2}([A-Z]\w*)", m.group(1), re.M):
                names.add(c.group(1))
    return names


def prefix_line(src, targets):
    """Rewrite one line, keeping literals and comments intact."""
    out = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        two = src[i : i + 2]

        if two == "//":
            out.append(src[i:])
            break
        if two == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(src[i:j])
            i = j
            continue
        if ch == QUOTE:
            j = i + 1
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == QUOTE:
                    j += 1
                    break
                j += 1
            out.append(src[i:j])
            i = j
            continue
        if ch == APOS:
            j = i + 1
            if j < n and src[j] == "\\":
                j += 3
            else:
                j += 2
            j = min(j, n)
            out.append(src[i:j])
            i = j
            continue

        m = re.match(r"[A-Za-z_]\w*", src[i:])
        if m:
            word = m.group(0)
            prev = out[-1][-1] if out and out[-1] else ""
            rest = src[i + len(word) :]
            is_label = rest.lstrip().startswith(":")
            if word in targets and prev != "." and not is_label:
                out.append("@k." + word)
            else:
                out.append(word)
            i += len(word)
            continue

        out.append(ch)
        i += 1
    return "".join(out)


def prefix_file(path, targets):
    raw = io.open(path, encoding="utf-8").read()
    lines = []
    for line in raw.split("\n"):
        if line.lstrip().startswith("#|"):
            lines.append(line)  # raw JavaScript body
        else:
            lines.append(prefix_line(line, targets))
    io.open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))


def main():
    kernel_files = glob.glob("src/kernel/*.mbt")
    app_files = glob.glob("src/app/*.mbt")
    kernel_names = scan_defs(kernel_files)
    app_names = scan_defs(app_files)
    targets = kernel_names - app_names
    print(f"kernel names={len(kernel_names)} app names={len(app_names)} to prefix={len(targets)}")
    for path in app_files:
        prefix_file(path, targets)
    print(f"prefixed {len(app_files)} app files")


if __name__ == "__main__":
    main()
