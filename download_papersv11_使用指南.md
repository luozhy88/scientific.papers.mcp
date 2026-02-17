# 📚 download_papersv11.R 使用指南

## 🎯 快速开始

```bash
# 最简单的用法（搜索 "starch" 相关论文）
Rscript download_papersv11.R starch

# 自定义参数（10 篇，最近 30 天）
Rscript download_papersv11.R "machine learning" 10 30
```

---

## 📖 功能特性

### ✨ 核心功能
- **多源搜索**：Europe PMC、arXiv、OpenAlex、Google CSE
- **智能 PDF 下载**：7 个候选源自动切换
- **自动摘要获取**：多策略补全缺失摘要
- **多格式导出**：CSV、JSON、纯文本报告
- **时间筛选**：按天数筛选最新文献

### 🔍 数据源说明

| 数据源 | 类型 | 特点 | 需要 API Key |
|--------|------|------|-------------|
| **Europe PMC** | 生物医学/生命科学 | 大量开放获取论文，有完整摘要 | ❌ 否 |
| **arXiv** | 物理/数学/计算机 | 预印本，PDF 下载成功率 100% | ❌ 否 |
| **OpenAlex** | 全学科 | 开放学术知识图谱，元数据丰富 | ❌ 否 |
| **Google CSE** | 补充源 | 搜索其他源遗漏的论文 | ✅ 是（可选）|

### 📥 PDF 下载策略（7 个候选源）

1. **arXiv 官方 PDF** - 最可靠（仅限 arXiv 论文）
2. **原始 PDF 链接** - 搜索结果提供的直接链接
3. **Unpaywall** - 基于 DOI 查找开放获取版本
4. **Semantic Scholar** - AI 驱动的学术搜索引擎
5. **Europe PMC PDF** - PMC 数据库的 PDF
6. **OpenAlex Open Access** - OpenAlex 的开放获取 PDF
7. **Google CSE（兜底）** - 最后的搜索策略

---

## 🛠️ 安装步骤

### 1. 系统要求

```bash
# 检查 R 是否安装
R --version

# 检查 Node.js 是否安装
node --version
npm --version
```

### 2. 安装 R（如果未安装）

```bash
# macOS
brew install r

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install r-base

# CentOS/RHEL
sudo yum install R
```

Windows 用户请访问：https://cran.r-project.org/

### 3. 安装 Node.js（如果未安装）

```bash
# macOS
brew install node

# Ubuntu/Debian
sudo apt-get install nodejs npm

# 或使用 nvm（推荐）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install node
```

Windows 用户请访问：https://nodejs.org/

### 4. 安装项目依赖

```bash
# 进入项目目录
cd /path/to/scientific.papers.mcp

# 安装 Node.js 依赖
npm install

# 构建项目（如果 dist 目录不存在）
npm run build
```

### 5. 添加执行权限

```bash
chmod +x download_papersv11.R
```

### 6. 配置 Google API（可选）

如果需要使用 Google 搜索源：

#### 步骤 1: 获取 Google API Key

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目
3. 启用 "Custom Search API"
4. 创建凭据 → 选择 "API 密钥"

#### 步骤 2: 创建自定义搜索引擎

1. 访问 [Programmable Search Engine](https://programmablesearchengine.google.com/)
2. 点击 "Add" 创建新搜索引擎
3. 添加要搜索的网站：
   - `arxiv.org`
   - `pubmed.ncbi.nlm.nih.gov`
   - `biorxiv.org`
   - `medrxiv.org`
   - `semanticscholar.org`
4. 获取 Search Engine ID (CX)

#### 步骤 3: 设置环境变量

```bash
# 临时设置（当前终端会话）
export GOOGLE_API_KEY="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export GOOGLE_CX="012345678901234567890:abcdefghij"

# 永久设置（添加到 ~/.bashrc 或 ~/.zshrc）
echo 'export GOOGLE_API_KEY="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXX"' >> ~/.zshrc
echo 'export GOOGLE_CX="012345678901234567890:abcdefghij"' >> ~/.zshrc
source ~/.zshrc
```

---

## 🚀 使用方法

### 基本语法

```bash
Rscript download_papersv11.R <关键词> [论文数量] [天数]
```

### 参数说明

| 参数 | 必需 | 说明 | 默认值 | 范围 |
|------|------|------|--------|------|
| `<关键词>` | ✅ | 搜索关键词 | - | - |
| `[论文数量]` | ❌ | 每个数据源返回的论文数 | 5 | 1-20 |
| `[天数]` | ❌ | 搜索最近多少天的论文 | 10 | 1-365 |

### 使用示例

```bash
# 示例 1: 基本搜索（默认 5 篇，最近 10 天）
Rscript download_papersv11.R starch

# 示例 2: 多词关键词（用引号包围）
Rscript download_papersv11.R "machine learning"

# 示例 3: 自定义论文数量
Rscript download_papersv11.R "COVID-19" 15

# 示例 4: 自定义时间范围（最近 30 天）
Rscript download_papersv11.R "CRISPR" 10 30

# 示例 5: 完整参数
Rscript download_papersv11.R "deep learning" 8 14

# 示例 6: 生物医学主题
Rscript download_papersv11.R "cancer immunotherapy" 12 7

# 示例 7: 物理学主题
Rscript download_papersv11.R "quantum computing" 10 20
```

---

## 📂 输出说明

### 目录结构

```
output/
├── <关键词>_papers/              # 论文元数据
│   ├── papers_20260217_143052.csv      # CSV 格式
│   ├── papers_20260217_143052.json     # JSON 格式
│   └── report_20260217_143052.txt      # 纯文本报告
└── <关键词>_pdfs/                # 下载的 PDF 文件
    ├── europepmc_title1_id1.pdf
    ├── arxiv_title2_id2.pdf
    └── openalex_title3_id3.pdf
```

### CSV 文件字段

| 字段名 | 说明 | 示例 |
|--------|------|------|
| `id` | 论文唯一标识符 | https://arxiv.org/abs/2401.12345 |
| `title` | 论文标题 | Deep Learning for Medical Image Analysis |
| `authors` | 作者列表 | Zhang L; Wang X; Li Y |
| `date` | 发表日期 | 2024-01-15 |
| `days_ago` | 距今天数 | 33 |
| `abstract` | 摘要 | This paper presents... |
| `pdf_url` | 原始 PDF 链接 | https://arxiv.org/pdf/2401.12345.pdf |
| `openalex_pdf` | OpenAlex PDF 链接 | https://... |
| `europepmc_pdf` | Europe PMC PDF 链接 | https://... |
| `source` | 数据源 | arxiv |
| `pdf_ok` | PDF 是否下载成功 | TRUE |
| `pdf_blocked` | 是否被网站保护 | FALSE |
| `pdf_file` | 下载的文件名 | arxiv_deep_learning_2401.pdf |
| `pdf_mb` | 文件大小（MB）| 2.35 |
| `pdf_source` | PDF 来源 | arxiv_pdf |

### 报告文件内容

纯文本格式，包含：
- 搜索参数摘要
- 论文总数、摘要统计、PDF 下载统计
- 每篇论文的详细信息
- 可用的 PDF 链接

---

## ⚙️ 高级配置

### 修改默认配置

编辑 `download_papersv11.R` 文件中的 `CONFIG` 部分：

```r
CONFIG <- list(
  # 修改默认论文数量
  DEFAULT_COUNT    = 5,

  # 修改默认天数
  DEFAULT_DAYS     = 10,

  # 修改输出目录
  OUTPUT_DIR       = "output",

  # 禁用某些数据源（例如：不使用 Google）
  SOURCES          = c("europepmc", "arxiv", "openalex"),

  # 修改请求间隔（秒）
  DELAY_SEC        = 2,

  # 修改 Unpaywall 邮箱（建议使用你自己的）
  UNPAYWALL_EMAIL  = "your.email@example.com",

  # 修改摘要最大长度
  MAX_ABSTRACT_LEN = 4000
)
```

### 仅搜索特定数据源

```r
# 只使用 arXiv
SOURCES = c("arxiv")

# 只使用生物医学数据库
SOURCES = c("europepmc")

# 使用所有源（含 Google）
SOURCES = c("europepmc", "arxiv", "openalex", "google")
```

---

## ❓ 常见问题

### Q1: 提示 "node: command not found"
**解决**：需要安装 Node.js，参考上方【安装步骤】

### Q2: 提示 "Error in library(pkg, character.only = TRUE)"
**解决**：R 包安装失败，手动安装：
```r
install.packages("jsonlite")
install.packages("dplyr")
```

### Q3: PDF 下载失败率高
**原因**：部分论文确实无开放 PDF，这是正常现象

**解决方案**：
- 通过学校/机构图书馆数据库下载
- 联系作者索取全文
- 使用报告中提供的备用 PDF 链接

### Q4: Google 搜索源提示未配置
**解决**：
- 如不需要 Google 源，可忽略此警告
- 如需使用，参考上方【配置 Google API】章节

### Q5: 运行速度慢
**优化方法**：
- 减少论文数量（第 2 个参数）
- 减少启用的数据源（修改 `SOURCES`）
- 缩短时间范围（第 3 个参数）

### Q6: 摘要显示 "(无)"
**原因**：部分数据源不提供摘要，或摘要获取失败

**解决**：可通过论文 ID 访问原始网站查看

### Q7: Excel 打开 CSV 乱码
**解决**：
```
1. 打开 Excel
2. 数据 → 从文本/CSV
3. 选择文件
4. 文件原始格式：65001 (UTF-8)
5. 导入
```

### Q8: 如何修改 Unpaywall 邮箱？
**解决**：编辑脚本，修改 `CONFIG` 中的 `UNPAYWALL_EMAIL` 字段

### Q9: 网络请求超时
**解决**：
- 检查网络连接
- 增加 `DELAY_SEC` 值（如改为 3）
- 如在国内，可能需要配置代理

### Q10: 提示 "dist/tools/search-papers.js" 不存在
**解决**：需要构建项目
```bash
npm run build
```

---

## 📊 性能提示

| 参数组合 | 预计时间 | 适用场景 |
|---------|---------|---------|
| 5 篇 × 3 源 × 10 天 | ~5 分钟 | 快速预览 |
| 10 篇 × 4 源 × 30 天 | ~15 分钟 | 标准搜索 |
| 20 篇 × 4 源 × 90 天 | ~40 分钟 | 深度调研 |

**影响速度的因素**：
- 论文数量
- 数据源数量
- 时间范围
- PDF 下载成功率
- 网络速度

---

## 🔐 隐私与安全

- ✅ 所有数据源的 API 都是公开的
- ✅ 不会上传或分享你的搜索记录
- ✅ PDF 直接下载到本地
- ⚠️ Google API Key 敏感，请妥善保管
- ⚠️ 建议通过环境变量传递 API Key，不要硬编码

---

## 📝 引用与致谢

本工具使用了以下开放 API：
- [Europe PMC API](https://europepmc.org/RestfulWebService)
- [arXiv API](https://arxiv.org/help/api/)
- [OpenAlex API](https://docs.openalex.org/)
- [Unpaywall API](https://unpaywall.org/products/api)
- [Semantic Scholar API](https://www.semanticscholar.org/product/api)
- [Google Custom Search API](https://developers.google.com/custom-search)

---

## 🆘 获取帮助

如果遇到问题：

1. 查看本文档的【常见问题】章节
2. 检查脚本开头的详细注释
3. 查看运行时的错误信息
4. 确认所有依赖已正确安装

---

## 📄 许可证

本工具仅供学术研究使用，请遵守各数据源的使用条款。

**免责声明**：
- 下载的论文仅供个人学习研究使用
- 请尊重论文版权，不得用于商业用途
- 本工具不对下载内容的版权问题负责

---

**最后更新**: 2026-02-17
**版本**: v2.7
