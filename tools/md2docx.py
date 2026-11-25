"""Convert the proposal Markdown into a submission-ready DOCX.

Targeted converter: headings, paragraphs, bullet/numbered lists, pipe tables and
fenced code blocks — everything PROJECT_PROPOSAL.md actually uses.
"""

import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor, Cm

BODY_FONT_LATIN = "Calibri"
BODY_FONT_CJK = "宋体"
HEAD_FONT_CJK = "微软雅黑"


def set_run_font(run, latin=BODY_FONT_LATIN, cjk=BODY_FONT_CJK, size=None, bold=None):
    run.font.name = latin
    run._element.rPr.rFonts.set(qn("w:eastAsia"), cjk)
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.font.bold = bold


def set_style_font(style, latin, cjk, size, bold=False):
    style.font.name = latin
    style.font.size = Pt(size)
    style.font.bold = bold
    rpr = style.element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = rpr.makeelement(qn("w:rFonts"), {})
        rpr.append(rfonts)
    rfonts.set(qn("w:eastAsia"), cjk)
    rfonts.set(qn("w:ascii"), latin)
    rfonts.set(qn("w:hAnsi"), latin)


def inline_runs(paragraph, text):
    """Emit text, honouring **bold** and `code` spans."""
    pattern = re.compile(r"(\*\*[^*]+\*\*|`[^`]+`)")
    for chunk in pattern.split(text):
        if not chunk:
            continue
        if chunk.startswith("**") and chunk.endswith("**"):
            run = paragraph.add_run(chunk[2:-2])
            set_run_font(run, bold=True)
        elif chunk.startswith("`") and chunk.endswith("`"):
            run = paragraph.add_run(chunk[1:-1])
            set_run_font(run, latin="Consolas", cjk=BODY_FONT_CJK)
            run.font.color.rgb = RGBColor(0x8B, 0x1A, 0x1A)
        else:
            run = paragraph.add_run(chunk)
            set_run_font(run)


def add_code_block(doc, lines):
    for line in lines:
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(0)
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.line_spacing = 1.0
        run = p.add_run(line if line else " ")
        set_run_font(run, latin="Consolas", cjk=BODY_FONT_CJK, size=9)
        run.font.color.rgb = RGBColor(0x33, 0x33, 0x33)


def add_table(doc, rows):
    header, *body = rows
    table = doc.add_table(rows=1, cols=len(header))
    table.style = "Light Grid Accent 1"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = table.rows[0].cells
    for i, cell_text in enumerate(header):
        hdr[i].text = ""
        p = hdr[i].paragraphs[0]
        run = p.add_run(cell_text)
        set_run_font(run, cjk=HEAD_FONT_CJK, size=10, bold=True)
    for row in body:
        cells = table.add_row().cells
        for i, cell_text in enumerate(row[: len(header)]):
            cells[i].text = ""
            p = cells[i].paragraphs[0]
            run = p.add_run(cell_text)
            set_run_font(run, size=9.5)
    doc.add_paragraph()


def parse_table_row(line):
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    return cells


def is_separator(line):
    return bool(re.fullmatch(r"\|[\s:\-|]+\|", line.strip()))


def build(md_text, out_path, title, subtitle):
    doc = Document()

    # Page + default styles
    section = doc.sections[0]
    section.top_margin = Cm(2.4)
    section.bottom_margin = Cm(2.4)
    section.left_margin = Cm(2.8)
    section.right_margin = Cm(2.6)

    normal = doc.styles["Normal"]
    set_style_font(normal, BODY_FONT_LATIN, BODY_FONT_CJK, 10.5)
    normal.paragraph_format.line_spacing = 1.5
    normal.paragraph_format.space_after = Pt(4)

    for name, size in (("Heading 1", 16), ("Heading 2", 13), ("Heading 3", 11.5)):
        set_style_font(doc.styles[name], HEAD_FONT_CJK, HEAD_FONT_CJK, size, bold=True)
        doc.styles[name].font.color.rgb = RGBColor(0x1F, 0x2A, 0x44)

    # Cover block
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(36)
    run = p.add_run(title)
    set_run_font(run, latin=HEAD_FONT_CJK, cjk=HEAD_FONT_CJK, size=26, bold=True)
    run.font.color.rgb = RGBColor(0x2F, 0x6F, 0xED)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(subtitle)
    set_run_font(run, latin=HEAD_FONT_CJK, cjk=HEAD_FONT_CJK, size=12)
    run.font.color.rgb = RGBColor(0x60, 0x6B, 0x7F)
    doc.add_paragraph()

    lines = md_text.splitlines()
    i = 0
    in_code = False
    code_buf = []
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("```"):
            if in_code:
                add_code_block(doc, code_buf)
                code_buf = []
                in_code = False
            else:
                in_code = True
            i += 1
            continue
        if in_code:
            code_buf.append(line)
            i += 1
            continue

        if not stripped:
            i += 1
            continue
        if stripped == "---":
            i += 1
            continue

        # Tables
        if stripped.startswith("|") and i + 1 < len(lines) and is_separator(lines[i + 1]):
            rows = [parse_table_row(stripped)]
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(parse_table_row(lines[i]))
                i += 1
            add_table(doc, rows)
            continue

        m = re.match(r"^(#{1,4})\s+(.*)$", stripped)
        if m:
            level = len(m.group(1))
            text = m.group(2).strip()
            # The document title is already on the cover.
            if level == 1:
                i += 1
                continue
            heading = doc.add_heading(level=min(level - 1, 3))
            run = heading.add_run(text)
            set_run_font(run, latin=HEAD_FONT_CJK, cjk=HEAD_FONT_CJK, size=None, bold=True)
            i += 1
            continue

        if re.match(r"^[-*]\s+", stripped):
            text = re.sub(r"^[-*]\s+", "", stripped)
            p = doc.add_paragraph(style="List Bullet")
            inline_runs(p, text)
            i += 1
            continue

        if re.match(r"^\d+\.\s+", stripped):
            text = re.sub(r"^\d+\.\s+", "", stripped)
            p = doc.add_paragraph(style="List Number")
            inline_runs(p, text)
            i += 1
            continue

        p = doc.add_paragraph()
        p.paragraph_format.first_line_indent = Cm(0.74)
        inline_runs(p, stripped)
        i += 1

    if in_code and code_buf:
        add_code_block(doc, code_buf)

    doc.save(out_path)
    return doc


def main():
    src = Path(sys.argv[1])
    out = Path(sys.argv[2])
    title = sys.argv[3] if len(sys.argv) > 3 else "MoonDraw 项目申请书"
    subtitle = sys.argv[4] if len(sys.argv) > 4 else "基于 MoonBit 的流程图与白板编辑器"
    doc = build(src.read_text(encoding="utf-8"), out, title, subtitle)

    # Verify structure.
    paras = [p for p in doc.paragraphs if p.text.strip()]
    headings = [p for p in doc.paragraphs if p.style.name.startswith("Heading")]
    tables = doc.tables
    print(f"paragraphs={len(paras)} headings={len(headings)} tables={len(tables)}")
    print(f"table_rows={[len(t.rows) for t in tables]}")
    print(f"words~={sum(len(p.text) for p in doc.paragraphs)} chars")
    print(f"saved={out}")


if __name__ == "__main__":
    main()
