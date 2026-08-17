#!/usr/bin/env python3
"""
extract_and_build.py — 从下载的 HTML 文件中提取正文内容，生成干净的 HTML 供 pandoc 合并。

用法:
    python3 extract_and_build.py \
        --html-dir <下载的HTML目录> \
        --chapters-json <章节定义JSON文件> \
        --output-dir <输出clean HTML目录> \
        --files-list <输出文件列表路径>

chapters.json 格式示例:
{
  "content_selector": "article",
  "prose_selector": {"tag": "div", "class": "prose"},
  "parts": [
    {
      "title": "第一篇 1949-1957",
      "before_index": 4
    }
  ],
  "chapters": [
    {"path": "foreword.html", "title": "前言"},
    {"path": "preface.html", "title": "自序"},
    {"path": "s01/ch01.html", "title": null, "chapter_num": 1},
    ...
  ]
}

如果 title 为 null 且提供了 chapter_num，则标题自动生成为 "第N章"。
如果 title 为 null 且无 chapter_num，则使用 HTML 中的 <h1> 文本。
"""

import argparse
import json
import os
import sys

from bs4 import BeautifulSoup


def extract_content(filepath, content_selector, prose_selector):
    """从 HTML 文件中提取正文内容。"""
    with open(filepath, "r", encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "html.parser")

    # 查找内容容器
    container = soup.find(content_selector)
    if not container:
        # 回退：尝试 body
        container = soup.find("body")
    if not container:
        return None, None

    # 查找正文区域
    prose = None
    if prose_selector:
        tag = prose_selector.get("tag", "div")
        cls = prose_selector.get("class")
        if cls:
            prose = container.find(tag, class_=cls)
        else:
            prose = container.find(tag)

    if not prose:
        prose = container

    # 获取标题
    h1 = container.find("h1")
    title = h1.get_text(strip=True) if h1 else None

    return str(prose), title


def main():
    parser = argparse.ArgumentParser(description="从下载的 HTML 中提取正文，生成 clean HTML")
    parser.add_argument("--html-dir", required=True, help="下载的 HTML 文件根目录")
    parser.add_argument("--chapters-json", required=True, help="章节定义 JSON 文件路径")
    parser.add_argument("--output-dir", required=True, help="输出 clean HTML 的目录")
    parser.add_argument("--files-list", required=True, help="输出文件列表的路径")
    args = parser.parse_args()

    with open(args.chapters_json, "r", encoding="utf-8") as f:
        config = json.load(f)

    content_selector = config.get("content_selector", "article")
    prose_selector = config.get("prose_selector")
    parts = {p["before_index"]: p["title"] for p in config.get("parts", [])}
    chapters = config["chapters"]

    os.makedirs(args.output_dir, exist_ok=True)
    file_list = []
    processed = 0
    errors = 0

    for idx, ch in enumerate(chapters):
        rel_path = ch["path"]
        filepath = os.path.join(args.html_dir, rel_path)

        if not os.path.exists(filepath):
            print(f"WARNING: {filepath} not found, skipping", file=sys.stderr)
            errors += 1
            continue

        content_html, detected_title = extract_content(filepath, content_selector, prose_selector)
        if not content_html:
            print(f"WARNING: No content extracted from {rel_path}", file=sys.stderr)
            errors += 1
            continue

        # 确定标题
        title = ch.get("title")
        if not title:
            ch_num = ch.get("chapter_num")
            if ch_num is not None:
                title = f"第{ch_num}章"
            elif detected_title:
                title = detected_title
            else:
                title = os.path.splitext(os.path.basename(rel_path))[0]

        # 构建 clean HTML
        clean = "<html><body>\n"

        # 插入篇标题（h1）
        if idx in parts:
            clean += f"<h1>{parts[idx]}</h1>\n"

        clean += f"<h2>{title}</h2>\n"
        clean += content_html
        clean += "\n</body></html>"

        out_file = os.path.join(args.output_dir, f"{idx:03d}.html")
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(clean)
        file_list.append(out_file)
        processed += 1

    # 写入文件列表
    with open(args.files_list, "w") as f:
        for path in file_list:
            f.write(path + "\n")

    print(f"Done: {processed} chapters processed, {errors} errors")
    if errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
