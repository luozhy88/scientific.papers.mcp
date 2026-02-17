# 快速入门指南

## 🚀 首次使用（必须执行）

```bash
# 1. 进入项目目录
cd /Users/apple/Desktop/kimi/test3/Scientific-Papers-MCP

# 2. 安装依赖（只需执行一次）
npm install

# 3. 构建项目（只需执行一次）
npm run build
```

---

## 📖 常用命令

### 基本用法

```bash
# 格式
Rscript download_papers.R <关键词> [数量] [天数]
```

### 常用示例

```bash
# 搜索最近 10 天（默认）的淀粉论文
Rscript download_papers.R "starch"

# 搜索最近 5 天的机器学习论文，每源 3 篇
Rscript download_papers.R "machine learning" 3 5

# 搜索最近 30 天的 COVID-19 论文，每源 10 篇
Rscript download_papers.R "COVID-19" 10 30

# 搜索最近 7 天的人工智能论文
Rscript download_papers.R "artificial intelligence" 5 7

# 查看帮助
Rscript download_papers.R --help
```

---

## 📁 查看结果

```bash
# 查看论文列表
ls output/*_papers/

# 查看下载的 PDF
ls output/*_pdfs/

# 打开 CSV 文件（macOS）
open output/*_papers/*.csv
```

---

## ⚠️ 常见问题速查

| 问题 | 解决 |
|------|------|
| node 未找到 | `brew install node` |
| 缺少 dist/ | `npm run build` |
| R 包安装失败 | `Rscript -e "install.packages('jsonlite')"` |
| 无结果 | 增加天数范围，如 `Rscript download_papers.R starch 5 30` |

---

## 📝 参数说明

| 位置 | 参数 | 必需 | 默认值 | 说明 |
|------|------|------|--------|------|
| 1 | 关键词 | ✅ | - | 搜索主题，如 "starch" |
| 2 | 数量 | ❌ | 5 | 每数据源论文数 (1-20) |
| 3 | 天数 | ❌ | 10 | 搜索最近多少天 (1-365) |
