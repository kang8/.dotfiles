---
name: web-to-epub
description: 将在线书籍网站（每章一个页面）转换为 EPUB 电子书。提供网站 URL 即可自动抓取、提取正文、生成带目录的 EPUB。
allowed-tools: Bash, Read, Write, WebFetch, Grep, Glob
argument-hint: [book-url]
---

# 网页书籍转 EPUB

将在线书籍网站转换为 EPUB 电子书。目标 URL: `$ARGUMENTS`

## 整体流程

1. **分析目录页** — 获取章节链接和书籍结构
2. **生成章节配置** — 创建 `chapters.json` 定义章节顺序和元数据
3. **下载所有页面** — 使用 wget 批量下载，带限速避免触发反爬
4. **提取正文内容** — 使用 Python 脚本剥离导航栏等 UI 元素，只保留正文
5. **生成 EPUB** — 使用 pandoc 合并生成带分层目录的 EPUB

## 前置依赖

确保以下工具已安装（macOS 用 Homebrew）：

```bash
brew install pandoc wget
pip3 install --break-system-packages beautifulsoup4
```

## 步骤详解

### Step 1: 分析目录页

使用 WebFetch 获取目标 URL 的目录页，提取所有章节链接。注意：

- 识别书名、作者
- 识别前言/序言/致谢等前置内容
- 识别分篇/分卷结构（如：第一篇、第二篇...）
- 按阅读顺序排列所有章节 URL
- 注意区分正文链接和导航/外部链接

### Step 2: 创建工作目录和配置文件

在当前目录下创建 `epub_build/` 工作目录，生成以下文件：

#### urls.txt — 所有章节的完整 URL，每行一个

```text
https://example.com/book/preface
https://example.com/book/ch01
https://example.com/book/ch02
...
```

#### chapters.json — 章节结构定义

```json
{
  "book_title": "书名",
  "author": "作者",
  "content_selector": "article",
  "prose_selector": { "tag": "div", "class": "prose" },
  "parts": [
    { "title": "第一篇 标题", "before_index": 4 }
  ],
  "chapters": [
    { "path": "foreword.html", "title": "前言" },
    { "path": "preface.html", "title": "自序" },
    { "path": "s01/ch01.html", "title": null, "chapter_num": 1 }
  ]
}
```

配置说明：

- `content_selector`: 正文所在的 HTML 容器标签（通常是 `article`、`main` 或
  `div.content`）
- `prose_selector`: 正文文字所在的子容器（可选，用于过滤侧边栏等噪声）
- `parts[].before_index`: 该篇标题应插入在第几个章节之前（0-indexed）
- `chapters[].path`: 对应 wget 下载后的本地文件相对路径
- `chapters[].title`: 显示标题；为 null 时使用 chapter_num 自动生成"第N章"

**关键**：需要先用 WebFetch 查看一个章节页面的 HTML 结构，确定正确的
`content_selector` 和 `prose_selector`。

### Step 3: 下载所有页面

```bash
cd epub_build
mkdir -p html

wget \
  --directory-prefix=html \
  --convert-links \
  --adjust-extension \
  --page-requisites \
  --no-parent \
  --random-wait --wait=1 \
  --input-file=urls.txt
```

下载参数说明：

- `--adjust-extension`: 自动加 `.html` 后缀
- `--page-requisites`: 同时下载图片等资源
- `--convert-links`: 将链接转为本地路径
- `--random-wait --wait=1`: 随机等待 0.5-1.5 秒，避免过快请求

下载完成后确认文件数量与 urls.txt 行数一致。

### Step 4: 确定 HTML 路径映射

wget 下载后的文件路径取决于 URL 结构。通常在 `html/<域名>/<路径>.html`。

用以下命令查看实际下载路径：

```bash
find html -name "*.html" | sort
```

根据实际路径更新 `chapters.json` 中每个章节的 `path` 字段，使其相对于 HTML
根目录。

### Step 5: 提取正文并生成 clean HTML

```bash
python3 ~/.claude/skills/web-to-epub/scripts/extract_and_build.py \
  --html-dir html/<域名>/<书籍路径> \
  --chapters-json chapters.json \
  --output-dir clean \
  --files-list files.txt
```

脚本会：

- 从每个 HTML 中提取 `content_selector` > `prose_selector` 区域的正文
- 在适当位置插入篇标题（h1）和章节标题（h2）
- 输出 clean HTML 文件和有序文件列表

### Step 6: 生成 EPUB

```bash
pandoc \
  --from=html \
  --to=epub3 \
  --output="<书名>.epub" \
  --metadata title="<书名>" \
  --metadata author="<作者>" \
  --metadata lang="zh-CN" \
  --toc --toc-depth=2 \
  --split-level=2 \
  $(cat files.txt)
```

参数说明：

- `--toc --toc-depth=2`: 自动生成两级目录（篇 h1 + 章 h2）
- `--split-level=2`: 按 h2 拆分 EPUB 章节，每章一个独立页面

可选增强：

- `--css=style.css`: 自定义样式
- `--epub-cover-image=cover.jpg`: 添加封面图

### Step 7: 验证

用 Python 检查 EPUB 结构：

```python
import zipfile
from bs4 import BeautifulSoup

with zipfile.ZipFile("<书名>.epub", "r") as z:
    with z.open("EPUB/nav.xhtml") as f:
        soup = BeautifulSoup(f.read(), "html.parser")
        for li in soup.find_all("li"):
            a = li.find("a")
            if a:
                depth = sum(1 for p in li.parents if p.name == "li")
                print("  " * depth + a.get_text(strip=True))
```

将最终 EPUB 复制到当前工作目录根下，告知用户文件路径和大小。

## 可选：自定义样式

如需更好的阅读体验，创建 `style.css`：

```css
body {
  font-family: serif;
  line-height: 1.8;
  text-align: justify;
}
h1 {
  text-align: center;
  margin-top: 2em;
  margin-bottom: 1em;
}
h2 {
  text-align: center;
  margin-top: 1.5em;
  margin-bottom: 1em;
}
p {
  text-indent: 2em;
  margin: 0.5em 0;
}
```

## 注意事项

- 下载时使用限速（`--wait`），尊重网站服务器
- 每个网站的 HTML 结构不同，Step 2 中的 selector 配置需要根据实际页面调整
- 如果网站使用 JavaScript 渲染内容（SPA），wget 可能无法获取正文，需考虑使用
  headless browser
- 生成的 EPUB 可直接用 Apple Books 打开，发送到 Kindle 需要转换格式或通过 Send
  to Kindle
