"""Prefix kernel symbols with @k. inside the app package.

Token-level rewrite that respects string/char literals and comments, skips
field/method positions (anything after a dot) and never touches names the app
package defines itself.
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


def prefix_file(path, targets):
    src = io.open(path, encoding="utf-8").read()
    out = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        two = src[i : i + 2]

        if two == "//":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(src[i:j])
            i = j
            continue
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
            # char literal like 'a' or '\n'
            j = i + 1
            if j < n and src[j] == "\\":
                j += 3
            else:
                j += 2
            out.append(src[i:j])
            i = j
            continue

        m = re.match(r"[A-Za-z_]\w*", src[i:])
        if m:
            word = m.group(0)
            prev = out[-1][-1] if out and out[-1] else ""
            if word in targets and prev != ".":
                out.append("@k." + word)
            else:
                out.append(word)
            i += len(word)
            continue

        out.append(ch)
        i += 1

    io.open(path, "w", encoding="utf-8", newline="\n").write("".join(out))


def main():
    kernel_files = glob.glob("src/kernel/*.mbt")
    app_files = glob.glob("src/app/*.mbt")
    kernel_names = scan_defs(kernel_files)
    app_names = scan_defs(app_files)
    targets = kernel_names - app_names
    print(f"kernel names={len(kernel_names)} app names={len(app_names)} to prefix={len(targets)}")
    io.open(".kexports.txt", "w", encoding="utf-8").write("\n".join(sorted(targets)))
    for path in app_files:
        prefix_file(path, targets)
    print(f"prefixed {len(app_files)} app files")


if __name__ == "__main__":
    main()
