#!/usr/bin/env Rscript
#
# =============================================================================
# 学术文献搜索与 PDF 下载工具（支持日期范围，自动获取摘要）
# =============================================================================
#
# 作者: Scientific-Papers-MCP
# 版本: 2.0
# 更新日期: 2026-02-15
#
# -----------------------------------------------------------------------------
# 功能简介
# -----------------------------------------------------------------------------
#
# 本脚本使用 R 语言调用 Scientific-Papers-MCP 服务，实现：
#   1. 从多个学术数据源（arXiv、OpenAlex）搜索最新论文
#   2. 按日期范围过滤（默认搜索最近 10 天）
#   3. 自动获取论文摘要（即使无 PDF 也会保存）
#   4. 下载 PDF 文件（如果可用）
#   5. 生成结构化输出（CSV、JSON、文本报告）
#
# -----------------------------------------------------------------------------
# 使用方法
# -----------------------------------------------------------------------------
#
#   Rscript download_papers.R <关键词> [数量] [天数]
#
# 参数:
#   关键词   - 搜索主题（如: starch, "machine learning", COVID-19）
#   数量     - 每数据源获取的论文数量（默认: 5，范围: 1-20）
#   天数     - 搜索最近多少天的文献（默认: 10，范围: 1-365）
#
# -----------------------------------------------------------------------------
# 使用示例
# -----------------------------------------------------------------------------
#
# # 示例 1: 搜索最近 10 天的淀粉论文（默认参数）
# Rscript download_papers.R starch
#
# # 示例 2: 搜索最近 5 天的机器学习论文，每数据源 3 篇
# Rscript download_papers.R "machine learning" 3 5
#
# # 示例 3: 搜索最近 30 天的 COVID-19 论文，每数据源 10 篇
# Rscript download_papers.R COVID-19 10 30
#
# # 示例 4: 搜索最近 7 天的人工智能论文
# Rscript download_papers.R "artificial intelligence" 5 7
#
# # 示例 5: 搜索最近一年（365天）的论文
# Rscript download_papers.R "quantum computing" 5 365
#
# # 示例 6: 查看帮助信息
# Rscript download_papers.R --help
#
# -----------------------------------------------------------------------------
# 输出文件
# -----------------------------------------------------------------------------
#
# 脚本会在 output/ 目录下创建以下文件：
#
# output/<关键词>_papers/
#   ├── papers_YYYYMMDD_HHMMSS.csv   # Excel 可读格式，包含摘要
#   ├── papers_YYYYMMDD_HHMMSS.json  # 结构化 JSON 数据
#   └── report_YYYYMMDD_HHMMSS.txt   # 人类可读文本报告
#
# output/<关键词>_pdfs/
#   ├── arxiv_xxx.pdf                # 下载的 PDF 文件
#   └── ...
#
# CSV 文件列说明:
#   - id: 论文唯一标识
#   - title: 论文标题
#   - authors: 作者列表（分号分隔）
#   - date: 发表日期
#   - days_ago: 距今多少天
#   - abstract: 论文摘要（即使无 PDF 也会保存）
#   - pdf_url: PDF 下载链接
#   - source: 数据来源 (europepmc/arxiv/openalex)
#   - pdf_ok: 是否成功下载 PDF
#   - pdf_file: 本地 PDF 文件名
#   - pdf_mb: PDF 大小 (MB)
#
# -----------------------------------------------------------------------------
# 安装前提
# -----------------------------------------------------------------------------
#
# 首次使用前，请确保已安装：
#
# 1. Node.js (>= 18.0.0)
#    检查: node --version
#    安装: https://nodejs.org/
#
# 2. R (>= 4.0.0)
#    检查: Rscript --version
#    安装: https://cran.r-project.org/
#
# 3. 项目依赖
#    cd /Users/apple/Desktop/kimi/test3/Scientific-Papers-MCP
#    npm install
#    npm run build
#
# 4. R 包（脚本会自动安装）
#    - jsonlite: 解析 JSON 数据
#    - dplyr: 数据处理
#
# -----------------------------------------------------------------------------
# 数据源说明
# -----------------------------------------------------------------------------
#
# 本脚本使用以下学术数据源：
#
# 1. arXiv (https://arxiv.org/)
#    - 类型: 预印本论文库
#    - 覆盖领域: 物理、数学、计算机科学、生物学等
#    - PDF 可用性: 高（几乎所有论文都有免费 PDF）
#    - 更新频率: 每日
#
# 2. OpenAlex (https://openalex.org/)
#    - 类型: 开放学术图谱
#    - 覆盖领域: 全学科
#    - PDF 可用性: 中（取决于出版社开放获取政策）
#    - 更新频率: 每日
#
# -----------------------------------------------------------------------------
# 注意事项
# -----------------------------------------------------------------------------
#
# 1. 日期范围
#    - 默认搜索最近 10 天的论文
#    - 如果搜索不到结果，建议增加天数范围（如 30 天或 365 天）
#    - 日期基于数据源提供的发表日期，可能有 1-2 天误差
#
# 2. 速率限制
#    - 脚本内置 2-3 秒请求间隔，避免被封
#    - 请勿频繁大量下载，以免 IP 被限制
#
# 3. 摘要获取（重要更新）
#    - 脚本使用多数据源策略获取最完整摘要：
#      1) EuropePMC: 通常提供最完整的生物医学文献摘要 ⭐推荐
#      2) arXiv: 预印本，摘要较简短
#      3) OpenAlex: 取决于原始来源
#    - 搜索顺序: EuropePMC > arXiv > OpenAlex
#    - 即使某个数据源无摘要，脚本会尝试其他数据源补充
#
# 4. PDF 下载
#    - arXiv 论文几乎都有免费 PDF
#    - EuropePMC 部分论文有免费 PDF
#    - OpenAlex 论文可能需要通过 DOI 到出版社网站获取
#    - 部分论文可能因版权原因无法直接下载
#
# 5. 存储空间
#    - PDF 文件可能较大（通常 1-50 MB/篇）
#    - 请确保有足够的磁盘空间
#
# -----------------------------------------------------------------------------
# 常见问题
# -----------------------------------------------------------------------------
#
# Q1: 提示 "最近 X 天内未找到相关论文"
#    解决: 增加天数范围，如 Rscript download_papers.R starch 5 30
#
# Q2: 提示 "node: command not found"
#    解决: 安装 Node.js (https://nodejs.org/)
#
# Q3: 提示 "Cannot find module './dist/tools/search-papers.js'"
#    解决: 运行 npm run build 生成 dist 目录
#
# Q4: PDF 下载失败 或 提示 "被网站保护阻止"
#    原因: 某些网站（如 PMC、ScienceDirect）使用 Cloudflare 等保护机制
#    解决: 
#      - 脚本会保存文章链接到CSV，请使用浏览器手动下载
#      - 对于PMC文章，尝试使用 Europe PMC 数据源
#      - 使用 --max-time 参数增加超时时间
#
# Q5: CSV 文件中的 abstract 列是空的
#    解决: 这是正常现象，某些数据源不提供摘要，但其他元数据仍会保存
#
# -----------------------------------------------------------------------------
# 技术支持
# -----------------------------------------------------------------------------
#
# 项目地址: https://github.com/benedict2310/Scientific-Papers-MCP
# 问题反馈: 请查看项目 README.md 或提交 Issue
#
# =============================================================================

# 设置工作目录为脚本所在目录
args_cmd <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args_cmd[grep("--file=", args_cmd)])
if (length(script_path) > 0) {
  setwd(dirname(normalizePath(script_path)))
}

# 加载依赖
if (!require("jsonlite", quietly = TRUE)) {
  install.packages("jsonlite", repos = "https://cloud.r-project.org/", quiet = TRUE)
  library(jsonlite)
}
if (!require("dplyr", quietly = TRUE)) {
  install.packages("dplyr", repos = "https://cloud.r-project.org/", quiet = TRUE)
  library(dplyr)
}

# 配置
CONFIG <- list(
  DEFAULT_COUNT = 5,
  DEFAULT_DAYS = 10,
  OUTPUT_DIR = "output",
  SOURCES = c("arxiv", "openalex"),  # 主要数据源 (europepmc API 暂时不可用)
  DELAY_SEC = 2
)

# 日志函数
log_msg <- function(msg, type = "INFO") {
  ts <- format(Sys.time(), "%H:%M:%S")
  sym <- switch(type, "ERROR" = "✖", "SUCCESS" = "✔", "WARN" = "⚠", "📄" = "📄", "ℹ")
  cat(sprintf("[%s] %s %s\n", ts, sym, msg))
}

# 安全文件名
safe_name <- function(text, max = 25) {
  text <- as.character(text)
  text <- iconv(text, to = "ASCII//TRANSLIT", sub = "_")
  text <- gsub("[^a-zA-Z0-9\\s_-]", "_", text)
  text <- gsub("[\\s_]+", "_", text)
  text <- gsub("^_+|_+$", "", text)
  text <- tolower(text)
  if (nchar(text) > max) text <- substr(text, 1, max)
  if (text == "") text <- "paper"
  text
}

# 创建目录
create_dirs <- function(kw) {
  name <- safe_name(kw)
  base <- file.path(CONFIG$OUTPUT_DIR, paste0(name, "_papers"))
  pdf <- file.path(CONFIG$OUTPUT_DIR, paste0(name, "_pdfs"))
  if (!dir.exists(base)) dir.create(base, recursive = TRUE)
  if (!dir.exists(pdf)) dir.create(pdf, recursive = TRUE)
  list(base = base, pdf = pdf, name = name)
}

# 计算日期差（天）
days_since <- function(date_str) {
  if (is.na(date_str) || date_str == "") return(Inf)
  tryCatch({
    paper_date <- as.Date(date_str)
    today <- Sys.Date()
    as.numeric(today - paper_date)
  }, error = function(e) Inf)
}

# 搜索论文
search_papers <- function(src, q, n, days) {
  log_msg(sprintf("搜索 %s: '%s' (最近 %d 天)", toupper(src), q, days))
  
  tmp <- sprintf(".temp_%s_%d.mjs", src, as.integer(Sys.time()))
  
  cat(sprintf("import { searchPapers } from './dist/tools/search-papers.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rl = new RateLimiter();
try {
  const r = await searchPapers({source:'%s',query:'%s',field:'all',count:%d,sortBy:'date'}, rl);
  console.log('R:'+JSON.stringify(r));
} catch(e) { console.log('E:'+e.message); }
", src, q, n * 3), file = tmp)
  
  res <- tryCatch({
    out <- system(sprintf("node '%s' 2>&1", tmp), intern = TRUE)
    unlink(tmp)
    line <- grep("^R:", out, value = TRUE)[1]
    if (is.na(line)) return(NULL)
    fromJSON(sub("^R:", "", line))
  }, error = function(e) { unlink(tmp); NULL })
  
  # 按日期过滤
  if (!is.null(res) && !is.null(res$content) && length(res$content) > 0) {
    papers <- res$content
    papers$days_ago <- sapply(papers$date, days_since)
    recent_papers <- papers[papers$days_ago <= days & papers$days_ago >= 0, ]
    
    if (nrow(recent_papers) > 0) {
      res$content <- recent_papers
      log_msg(sprintf("%s: 找到 %d 篇 (最近 %d 天)", toupper(src), nrow(recent_papers), days))
    } else {
      log_msg(sprintf("%s: 无最近 %d 天的结果", toupper(src), days), "WARN")
      res$content <- NULL
    }
  }
  
  res
}

# 获取论文详情（包括摘要）
fetch_content <- function(src, paper_id) {
  tmp <- sprintf(".temp_content_%s_%d.mjs", src, as.integer(Sys.time()))
  
  cat(sprintf("import { fetchContent } from './dist/tools/fetch-content.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rl = new RateLimiter();
try {
  const r = await fetchContent({source:'%s',id:'%s'}, rl);
  console.log('R:'+JSON.stringify(r));
} catch(e) { console.log('E:'+e.message); }
", src, paper_id), file = tmp)
  
  res <- tryCatch({
    out <- system(sprintf("node '%s' 2>&1", tmp), intern = TRUE)
    unlink(tmp)
    line <- grep("^R:", out, value = TRUE)[1]
    if (is.na(line)) return(NULL)
    fromJSON(sub("^R:", "", line))
  }, error = function(e) { unlink(tmp); NULL })
  
  res
}

# 处理摘要字段
get_abstract_text <- function(abstract_field) {
  if (is.null(abstract_field)) return("")
  if (is.character(abstract_field)) {
    if (length(abstract_field) == 0) return("")
    return(paste(abstract_field, collapse = " "))
  }
  if (is.list(abstract_field)) {
    return(paste(unlist(abstract_field), collapse = " "))
  }
  return(as.character(abstract_field))
}

# 从 arXiv text 中提取摘要
extract_abstract_from_text <- function(text) {
  if (is.null(text) || text == "") return("")
  
  # 尝试匹配 Abstract: 开头的内容
  pattern <- "Abstract:([^\n]+)"
  matches <- regmatches(text, regexpr(pattern, text, ignore.case = TRUE))
  
  if (length(matches) > 0 && nchar(matches[1]) > 10) {
    # 移除 "Abstract:" 前缀
    abstract <- sub("^[Aa]bstract:", "", matches[1])
    return(trimws(abstract))
  }
  
  return("")
}

# 下载PDF
download_pdf <- function(url, file, dir) {
  if (is.null(url) || url == "") return(list(ok = FALSE, blocked = FALSE))
  
  # 处理 arXiv URL
  url <- sub("/abs/", "/pdf/", url)
  if (grepl("arxiv.org/pdf/", url) && !grepl("\\.pdf$", url)) {
    url <- paste0(url, ".pdf")
  }
  
  path <- file.path(dir, file)
  cat(sprintf("  📥 %s\n", substr(file, 1, 40)))
  
  # 检查是否是受保护的网站
  is_protected <- grepl("ncbi.nlm.nih.gov", url) || 
                  grepl("sciencedirect.com", url) || 
                  grepl("springer.com", url) ||
                  grepl("wiley.com", url)
  
  if (is_protected) {
    cat(sprintf("  ⚠ 检测到受保护网站，尝试高级下载...\n"))
  }
  
  # 构建 curl 命令 - 模拟浏览器
  cmd <- sprintf(
    "curl -sL --max-time 90 -o '%s' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' -H 'Accept: application/pdf,text/html,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.9' '%s'",
    path, url
  )
  
  tryCatch({
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    
    if (file.exists(path)) {
      # 检查文件大小
      file_size <- file.size(path)
      
      # 检查是否是真实的 PDF（不是 HTML 错误页面）
      is_html <- FALSE
      is_pdf <- FALSE
      
      if (file_size > 0) {
        # 读取文件前几个字节检查是否是 PDF
        con <- file(path, "rb")
        header <- readBin(con, "raw", n = 100)
        close(con)
        # 检查是否以 %PDF 开头（PDF 文件魔数）
        is_pdf <- length(header) >= 4 && 
                  header[1] == 0x25 && header[2] == 0x50 && 
                  header[3] == 0x44 && header[4] == 0x46
        is_html <- !is_pdf && file_size < 50000  # 小文件可能是 HTML 错误页
      }
      
      if (file_size > 10000 && !is_html) {
        sz <- round(file_size / 1024 / 1024, 2)
        cat(sprintf("  ✔ %.2f MB\n", sz))
        return(list(ok = TRUE, mb = sz, blocked = FALSE))
      } else if (is_html) {
        # 读取 HTML 内容判断是否是 Cloudflare/JS 挑战
        html_content <- readLines(path, warn = FALSE, n = 50)
        is_cloudflare <- any(grepl("cloudflare|challenge|captcha|javascript|checking your browser", 
                                   html_content, ignore.case = TRUE))
        unlink(path)
        
        if (is_cloudflare || is_protected) {
          cat(sprintf("  ⚠ 网站保护阻止下载（可在浏览器手动打开链接）\n"))
          return(list(ok = FALSE, blocked = TRUE, reason = "protected"))
        } else {
          cat("  ✗ 下载的是 HTML 而非 PDF\n")
          return(list(ok = FALSE, blocked = FALSE))
        }
      } else {
        unlink(path)
        cat("  ✗ 文件太小或为空\n")
        return(list(ok = FALSE, blocked = FALSE))
      }
    } else {
      cat("  ✗ 下载失败\n")
      return(list(ok = FALSE, blocked = FALSE))
    }
  }, error = function(e) {
    if (file.exists(path)) unlink(path)
    cat("  ✗ 错误\n")
    return(list(ok = FALSE, blocked = FALSE))
  })
}

# 主程序
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) < 1 || args[1] %in% c("-h", "--help", "help")) {
    cat(sprintf("╔══════════════════════════════════════════════════════════╗
║     学术文献搜索与 PDF 下载工具（支持日期范围）          ║
╚══════════════════════════════════════════════════════════╝

用法: Rscript download_papers.R <关键词> [数量] [天数]

参数:
  关键词   搜索主题 (如: starch, machine learning, COVID-19)
  数量     每数据源论文数 (默认: 5)
  天数     搜索最近多少天的文献 (默认: 10)

示例:
  # 搜索最近10天的淀粉论文（默认）
  Rscript download_papers.R starch

  # 搜索最近5天的机器学习论文，每源3篇
  Rscript download_papers.R machine\\ learning 3 5

  # 搜索最近30天的COVID-19论文，每源10篇
  Rscript download_papers.R COVID-19 10 30

  # 搜索最近7天的人工智能论文
  Rscript download_papers.R artificial\\ intelligence 5 7

输出:
  output/<关键词>_papers/  - CSV/JSON/报告 (包含摘要)
  output/<关键词>_pdfs/    - PDF 文件

说明:
  - 从 arXiv 和 OpenAlex 获取论文和摘要
  - 无论是否成功下载PDF，CSV文件都会包含论文元数据
  - 脚本会尝试获取摘要，但取决于数据源提供情况
  - 详细文档请查看脚本头部注释
"))
    quit(status = 0)
  }
  
  kw <- args[1]
  n <- ifelse(length(args) >= 2, as.integer(args[2]), CONFIG$DEFAULT_COUNT)
  days <- ifelse(length(args) >= 3, as.integer(args[3]), CONFIG$DEFAULT_DAYS)
  
  if (is.na(n) || n < 1) n <- 5
  if (n > 20) n <- 20
  if (is.na(days) || days < 1) days <- 10
  if (days > 365) days <- 365
  
  cat("\n╔══════════════════════════════════════════════════════════╗\n")
  cat("║     学术文献搜索与 PDF 下载工具（最新文献版）            ║\n")
  cat("╚══════════════════════════════════════════════════════════╝\n\n")
  
  log_msg(sprintf("关键词: \"%s\"", kw))
  log_msg(sprintf("每数据源数量: %d", n))
  log_msg(sprintf("时间范围: 最近 %d 天", days))
  log_msg(sprintf("日期范围: %s 至 %s", format(Sys.Date() - days), format(Sys.Date())))
  
  dirs <- create_dirs(kw)
  log_msg(sprintf("输出目录: %s/", dirs$name))
  cat("\n")
  
  # 搜索 - 优先使用 EuropePMC 获取更完整摘要
  all_papers <- list()
  
  # 搜索顺序：arxiv 和 openalex
  search_order <- c("arxiv", "openalex")
  
  for (src in search_order) {
    if (!(src %in% CONFIG$SOURCES)) next
    r <- search_papers(src, kw, n, days)
    if (!is.null(r) && !is.null(r$content) && length(r$content) > 0) {
      df <- r$content
      df$source <- src
      
      # 处理作者字段
      if ("authors" %in% names(df)) {
        df$authors <- sapply(df$authors, function(a) {
          if (is.null(a)) return("")
          if (is.character(a)) return(paste(a, collapse = "; "))
          if (is.list(a)) return(paste(unlist(a), collapse = "; "))
          return(as.character(a))
        })
      } else {
        df$authors <- ""
      }
      
      # 处理摘要字段
      if ("abstract" %in% names(df)) {
        df$abstract <- sapply(df$abstract, get_abstract_text)
      } else {
        df$abstract <- ""
      }
      
      all_papers[[src]] <- df
    }
    Sys.sleep(CONFIG$DELAY_SEC)
  }
  
  if (length(all_papers) == 0) {
    log_msg(sprintf("最近 %d 天内未找到相关论文", days), "ERROR")
    log_msg("建议:", "INFO")
    log_msg("  1. 增加天数范围（如 30 天）", "INFO")
    log_msg("  2. 尝试更通用的关键词", "INFO")
    quit(status = 1)
  }
  
  # 合并
  all <- do.call(rbind, all_papers)
  rownames(all) <- NULL
  all <- all[!duplicated(all$id), ]
  
  log_msg(sprintf("总计: %d 篇 (最近 %d 天)", nrow(all), days))
  cat("\n")
  
  # 按日期排序
  all <- all[order(all$days_ago), ]
  
  # 限制总数
  if (nrow(all) > n * length(CONFIG$SOURCES)) {
    all <- all[1:(n * length(CONFIG$SOURCES)), ]
  }
  
  # 确保abstract字段存在
  if (!"abstract" %in% names(all)) {
    all$abstract <- ""
  }
  
  # 获取详细内容（补充摘要）
  log_msg("获取论文摘要...")
  log_msg("提示: 尝试从数据源获取完整摘要", "📄")
  
  for (i in 1:nrow(all)) {
    current_abstract <- get_abstract_text(all$abstract[i])
    original_source <- all$source[i]
    
    # 如果摘要为空或太短，尝试获取详情
    if (nchar(current_abstract) < 50) {
      cat(sprintf("  [%d/%d] %s... ", i, nrow(all), substr(all$title[i], 1, 30)))
      
      # 尝试从原始数据源获取详细内容
      content_res <- fetch_content(original_source, all$id[i])
      if (!is.null(content_res) && !is.null(content_res$content)) {
        # 尝试获取 abstract 字段
        new_abstract <- get_abstract_text(content_res$content$abstract)
        
        # 如果是 arXiv 且 abstract 为空，尝试从 text 中提取
        if (nchar(new_abstract) < 50 && original_source == "arxiv" && !is.null(content_res$content$text)) {
          extracted_abstract <- extract_abstract_from_text(content_res$content$text)
          if (nchar(extracted_abstract) > nchar(new_abstract)) {
            new_abstract <- extracted_abstract
          }
        }
        
        if (nchar(new_abstract) > nchar(current_abstract)) {
          all$abstract[i] <- new_abstract
          cat(sprintf("✓ (%d字符)\n", nchar(new_abstract)))
        } else {
          cat("⚠ 数据源无摘要\n")
        }
      } else {
        cat("✗ 无法获取详情\n")
      }
      
      Sys.sleep(1)
    } else {
      cat(sprintf("  [%d/%d] %s... ✓ 已有摘要 (%d字符)\n", 
                  i, nrow(all), substr(all$title[i], 1, 30), nchar(current_abstract)))
    }
  }
  cat("\n")
  
  # 下载PDF
  log_msg("开始下载 PDF...")
  all$pdf_ok <- FALSE
  all$pdf_file <- NA_character_
  all$pdf_mb <- NA_real_
  all$pdf_blocked <- FALSE  # 新增：标记是否被网站保护阻止
  
  for (i in 1:nrow(all)) {
    p <- all[i, ]
    cat(sprintf("\n[%d/%d] %s\n", i, nrow(all), substr(p$title, 1, 45)))
    cat(sprintf("    发布于: %s (%d 天前)\n", p$date, p$days_ago))
    
    # 显示摘要预览
    abstract_preview <- get_abstract_text(p$abstract)
    if (nchar(abstract_preview) > 0) {
      if (nchar(abstract_preview) > 80) {
        abstract_preview <- paste0(substr(abstract_preview, 1, 80), "...")
      }
      cat(sprintf("    摘要: %s\n", abstract_preview))
    } else {
      cat("    摘要: (无)\n")
    }
    
    if (!is.na(p$pdf_url) && p$pdf_url != "") {
      fn <- sprintf("%s_%s_%s.pdf", p$source, safe_name(p$title, 20), substr(p$id, 1, 15))
      r <- download_pdf(p$pdf_url, fn, dirs$pdf)
      if (r$ok) {
        all$pdf_ok[i] <- TRUE
        all$pdf_file[i] <- fn
        all$pdf_mb[i] <- r$mb
      } else {
        all$pdf_blocked[i] <- ifelse(!is.null(r$blocked), r$blocked, FALSE)
        if (all$pdf_blocked[i]) {
          cat(sprintf("  💡 提示: 请手动在浏览器中打开下载\n     %s\n", p$pdf_url))
        }
      }
    } else {
      cat("  ⚠ 无 PDF 链接 (摘要已保存到CSV)\n")
    }
    Sys.sleep(CONFIG$DELAY_SEC)
  }
  
  # 保存
  cat("\n")
  ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # 统一处理abstract字段
  all$abstract <- sapply(all$abstract, get_abstract_text)
  
  # 选择要保存的列
  save_cols <- c("id", "title", "authors", "date", "days_ago", 
                 "abstract", "pdf_url", "source", 
                 "pdf_ok", "pdf_blocked", "pdf_file", "pdf_mb")
  
  # 确保所有列都存在
  for (col in save_cols) {
    if (!col %in% names(all)) {
      all[[col]] <- NA
    }
  }
  
  # CSV
  csv_data <- all[, save_cols]
  write.csv(csv_data, file.path(dirs$base, sprintf("papers_%s.csv", ts)), 
            row.names = FALSE, fileEncoding = "UTF-8")
  log_msg("保存: CSV (包含摘要)")
  
  # JSON
  write_json(all, file.path(dirs$base, sprintf("papers_%s.json", ts)), pretty = TRUE)
  log_msg("保存: JSON (包含摘要)")
  
  # 统计
  has_abstract <- sum(nchar(all$abstract) > 10)
  log_msg(sprintf("摘要统计: %d/%d 篇有摘要", has_abstract, nrow(all)))
  
  # 报告
  rp <- file.path(dirs$base, sprintf("report_%s.txt", ts))
  con <- file(rp, "w", encoding = "UTF-8")
  
  blocked_count <- sum(all$pdf_blocked, na.rm = TRUE)
  
  writeLines(c(
    sprintf("最新文献搜索报告"),
    sprintf("=================="),
    sprintf(""),
    sprintf("搜索关键词: %s", kw),
    sprintf("时间范围: 最近 %d 天 (%s 至 %s)", days, format(Sys.Date() - days), format(Sys.Date())),
    sprintf("搜索时间: %s", format(Sys.time())),
    sprintf(""),
    sprintf("结果统计:"),
    sprintf("  总论文: %d 篇", nrow(all)),
    sprintf("  有摘要: %d 篇", has_abstract),
    sprintf("  PDF下载: %d 个 (%.1f MB)", sum(all$pdf_ok), sum(all$pdf_mb, na.rm = TRUE)),
    sprintf("  被保护阻止: %d 个 (请手动下载)", blocked_count),
    sprintf(""),
    sprintf("按来源分布:"),
    capture.output(print(table(all$source))),
    sprintf(""),
    sprintf("=" %>% rep(60) %>% paste(collapse = "")),
    sprintf("")
  ), con)
  
  for (i in 1:nrow(all)) {
    p <- all[i,]
    abst <- get_abstract_text(p$abstract)
    abstract_display <- ifelse(nchar(abst) > 0, substr(abst, 1, 300), "无摘要")
    
    # PDF 状态
    if (p$pdf_ok) {
      pdf_status <- sprintf("已下载: %s (%.1f MB)", p$pdf_file, p$pdf_mb)
    } else if (!is.na(p$pdf_blocked) && p$pdf_blocked) {
      pdf_status <- "被网站保护阻止 (请使用浏览器手动下载)"
    } else if (!is.na(p$pdf_url) && p$pdf_url != "") {
      pdf_status <- "下载失败"
    } else {
      pdf_status <- "无PDF链接"
    }
    
    writeLines(c(
      sprintf("\n[%d] %s", i, p$title),
      sprintf("  ID: %s", p$id),
      sprintf("  来源: %s", p$source),
      sprintf("  发布日期: %s (%d 天前)", p$date, p$days_ago),
      sprintf("  作者: %s", ifelse(nchar(p$authors) > 80, paste0(substr(p$authors, 1, 80), "..."), p$authors)),
      sprintf("  PDF状态: %s", pdf_status),
      sprintf("  链接: %s", ifelse(is.na(p$pdf_url) || p$pdf_url == "", "无", p$pdf_url)),
      sprintf(""),
      sprintf("  摘要:"),
      sprintf("    %s", abstract_display),
      sprintf(""),
      "-" %>% rep(50) %>% paste(collapse = "")
    ), con)
  }
  
  close(con)
  log_msg("保存: 报告 (包含摘要)")
  
  # 完成
  blocked_count <- sum(all$pdf_blocked, na.rm = TRUE)
  
  cat("\n══════════════════════════════════════════════════════════\n")
  cat("✅ 完成!\n")
  cat("══════════════════════════════════════════════════════════\n")
  cat(sprintf("\n统计:\n"))
  cat(sprintf("  最近 %d 天论文: %d 篇\n", days, nrow(all)))
  cat(sprintf("  有摘要: %d 篇\n", has_abstract))
  cat(sprintf("  PDF下载: %d 个 (%.1f MB)\n", sum(all$pdf_ok), sum(all$pdf_mb, na.rm = TRUE)))
  if (blocked_count > 0) {
    cat(sprintf("  ⚠️  被网站保护阻止: %d 个\n", blocked_count))
  }
  cat(sprintf("\n文件位置:\n"))
  cat(sprintf("  %s\n", dirs$base))
  cat(sprintf("  %s\n", dirs$pdf))
  if (blocked_count > 0) {
    cat(sprintf("\n⚠️  注意: %d 个PDF被网站保护阻止下载\n", blocked_count))
    cat("   请查看报告文件中的链接，使用浏览器手动下载\n")
  }
  cat(sprintf("\n提示: CSV文件中的'abstract'列包含了所有论文的摘要信息\n"))
  cat("\n")
}

# 清理临时文件
unlink(list.files(".", "^\\.temp_.*\\.mjs$", full.names = TRUE))

# 运行
main()
