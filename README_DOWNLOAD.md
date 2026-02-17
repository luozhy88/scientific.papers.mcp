# 学术文献搜索与 PDF 下载工具

使用 R 语言调用 Scientific-Papers-MCP 搜索并下载**最新**学术论文 PDF。

---

## 📋 目录

- [安装说明](#安装说明)
- [使用说明](#使用说明)
- [输出文件](#输出文件)
- [常见问题](#常见问题)

---

## 安装说明

### 1. 前置条件

确保系统已安装以下软件：

| 软件 | 版本要求 | 检查命令 |
|------|---------|---------|
| **Node.js** | >= 18.0.0 | `node --version` |
| **R** | >= 4.0.0 | `Rscript --version` |
| **curl** | 任意版本 | `curl --version` |

#### 安装 Node.js

**macOS:**
```bash
brew install node
```

**Ubuntu/Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**Windows:**
访问 https://nodejs.org/ 下载安装包

#### 安装 R

**macOS:**
```bash
brew install r
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install r-base
```

**Windows:**
访问 https://cran.r-project.org/ 下载安装包

---

### 2. 安装项目依赖

#### 步骤 1: 进入项目目录

```bash
cd /Users/apple/Desktop/kimi/test3/Scientific-Papers-MCP
```

#### 步骤 2: 安装 Node.js 依赖

```bash
npm install
```

#### 步骤 3: 构建项目

```bash
npm run build
```

**验证安装成功：**

```bash
ls dist/tools/search-papers.js   # 应该存在
ls dist/core/rate-limiter.js     # 应该存在
```

---

### 3. 安装 R 包（自动）

R 脚本运行时会**自动安装**所需的 R 包：
- `jsonlite` - 解析 JSON 数据
- `dplyr` - 数据处理

手动安装：
```bash
Rscript -e "install.packages(c('jsonlite', 'dplyr'), repos='https://cloud.r-project.org/')"
```

---

## 使用说明

### 基本用法

```bash
Rscript download_papers.R <搜索关键词> [数量] [天数]
```

### 参数说明

| 参数 | 必需 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| `搜索关键词` | ✅ | - | - | 要搜索的主题，如 "starch" |
| `数量` | ❌ | 5 | 1-20 | 每数据源获取的论文数 |
| `天数` | ❌ | 10 | 1-365 | 搜索**最近多少天**的文献 |

### 使用示例

#### 示例 1: 搜索最近 10 天的论文（默认）

```bash
Rscript download_papers.R "starch"
```

只搜索最近 10 天内发表的淀粉相关论文。

#### 示例 2: 搜索最近 5 天的论文

```bash
Rscript download_papers.R "machine learning" 3 5
```

- 关键词："machine learning"
- 每数据源 3 篇
- 只搜索最近 **5 天**

#### 示例 3: 搜索最近 30 天的论文

```bash
Rscript download_papers.R "COVID-19" 10 30
```

搜索最近一个月内发表的 COVID-19 相关论文。

#### 示例 4: 搜索最近一周的论文

```bash
Rscript download_papers.R "artificial intelligence" 5 7
```

适合追踪最新研究进展。

#### 示例 5: 查看帮助

```bash
Rscript download_papers.R --help
```

---

## 输出文件

### 目录结构

```
output/
├── <关键词>_papers/          # 论文信息目录
│   ├── papers_<时间>.csv     # Excel 可读格式
│   ├── papers_<时间>.json    # 结构化 JSON 数据
│   └── report_<时间>.txt     # 文本报告
│
└── <关键词>_pdfs/            # PDF 文件目录
    ├── arxiv_xxx.pdf         # arXiv 论文
    └── ...
```

### 输出示例

运行 `Rscript download_papers.R starch 5 10` 后：

```
[21:30:15] ℹ 关键词: "starch"
[21:30:15] ℹ 每数据源数量: 5
[21:30:15] ℹ 时间范围: 最近 10 天
[21:30:15] ℹ 日期范围: 2026-02-05 至 2026-02-15

[21:30:15] ℹ 搜索 ARXIV: 'starch' (最近 10 天)
[21:30:16] ℹ ARXIV: 找到 3 篇 (最近 10 天)
...

总计: 6 篇 (最近 10 天)
```

### CSV 文件列说明

| 列名 | 说明 |
|------|------|
| `id` | 论文唯一标识 |
| `title` | 论文标题 |
| `authors` | 作者列表（分号分隔）|
| `date` | 发表日期 |
| `days_ago` | 距今多少天 |
| `abstract` | **论文摘要**（即使无PDF也会保存）|
| `pdf_url` | PDF 下载链接 |
| `source` | 数据来源 |
| `pdf_ok` | 是否成功下载 |
| `pdf_file` | 本地 PDF 文件名 |
| `pdf_mb` | PDF 大小 (MB) |

---

## 常见问题

### Q1: 提示 "最近 X 天内未找到相关论文"

**原因**: 最近这段时间确实没有相关新论文

**解决**:
```bash
# 增加天数范围，如搜索最近 30 天
Rscript download_papers.R "starch" 5 30

# 或搜索最近一年
Rscript download_papers.R "starch" 5 365
```

---

### Q2: 如何取消日期限制搜索全部论文？

```bash
# 将天数设为很大的值，如 3650 天（约 10 年）
Rscript download_papers.R "starch" 5 3650
```

---

### Q3: 为什么搜不到今天的论文？

**原因**: 
1. 论文发表到被索引需要时间（通常 1-3 天）
2. 时区差异
3. 数据源更新频率

**建议**: 设置 `天数=3` 或 `天数=7` 即可捕获最新论文

---

### Q4: 提示 "node: command not found"

**原因**: 未安装 Node.js

**解决**:
```bash
# macOS
brew install node

# 检查
node --version
```

---

### Q5: 提示 "Cannot find module './dist/tools/search-papers.js'"

**原因**: 未执行 `npm run build`

**解决**:
```bash
npm run build
```

---

### Q6: 如何只搜索预印本（arXiv）？

脚本默认只使用 arXiv 和 OpenAlex，其中 arXiv 主要提供预印本。

如果要获取 arXiv 某个分类的最新论文，可以直接用分类名：

```bash
# 获取最近 10 天的 AI 领域最新论文
Rscript download_papers.R "cs.AI" 10 10
```

常用 arXiv 分类：
- `cs.AI` - 人工智能
- `cs.LG` - 机器学习
- `cs.CL` - 计算语言学
- `cs.CV` - 计算机视觉
- `physics` - 物理学
- `math` - 数学
- `q-bio` - 定量生物学
- `stat` - 统计学

---

### Q7: PDF 下载失败

**原因**: 
- 论文没有开放获取 PDF
- 网络连接问题

**现象**: 
```
  ⚠ 无 PDF 链接
  或
  ✗ 失败
```

**解决**:
- arXiv 论文通常都有 PDF
- OpenAlex 的论文可能需要通过 DOI 到出版社网站获取
- 检查网络连接

---

### Q8: CSV 文件中的 abstract 列是空的？

**原因**: 
1. 某些数据源（如 arXiv 搜索）默认不返回摘要
2. OpenAlex 的部分论文没有提供摘要

**解决**:
- 这是正常现象，即使摘要在 CSV 中为空，你仍然可以看到论文标题、作者、日期等信息
- 脚本会尝试通过 `fetchContent` 获取摘要，但并非所有论文都能获取到
- 即使摘要在 CSV 中为空，**没有 PDF 的论文信息仍然被保存**，方便你后续手动查找

---

### Q9: 如何追踪最新文献？

**建议设置定时任务**（每天自动搜索）：

```bash
# 编辑 crontab
crontab -e

# 添加行：每天早上 9 点搜索昨天的文献
0 9 * * * cd /Users/apple/Desktop/kimi/test3/Scientific-Papers-MCP && Rscript download_papers.R "starch" 10 1
```

---

## 数据源说明

脚本使用以下数据源搜索**最新**文献：

| 数据源 | 类型 | 更新频率 | PDF 可用性 |
|--------|------|---------|-----------|
| **arXiv** | 预印本 | 每日 | ✅ 高 |
| **OpenAlex** | 综合学术 | 每日 | ⚠️ 低 |

**日期过滤逻辑**：
1. 从各数据源获取更多论文（数量为请求的 3 倍）
2. 计算每篇论文的发表日期距今天数
3. 只保留在指定天数范围内的论文
4. 按日期排序，优先显示最新论文

---

## 注意事项

1. **日期准确性**: 数据源返回的日期可能有 1-2 天误差
2. **时区问题**: 默认使用系统本地时区计算天数
3. **预印本 vs 正式发表**: arXiv 显示的是预印本提交日期
4. **尊重版权**: 下载的 PDF 仅供个人学习研究使用
5. **速率限制**: 脚本已内置延迟，避免被封

---

**最后更新**: 2026-02-15
