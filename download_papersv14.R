#!/usr/bin/env Rscript
# =============================================================================
# 📚 学术文献搜索与 PDF 下载工具（v3.0 - Semantic Scholar 首选版）
# =============================================================================
#
# 【功能介绍】
# 本工具用于自动搜索学术文献、获取摘要、下载全文 PDF。支持多数据源搜索和
# 多渠道 PDF 下载，大幅提高文献获取成功率。
#
# 主要功能：
#  ✓ 多源搜索：Semantic Scholar（首选）、Europe PMC、arXiv、OpenAlex
#  ✓ 智能 PDF 下载：7 个候选源自动切换（成功率高）
#  ✓ 自动获取摘要：多种策略补全缺失的摘要
#  ✓ 结果导出：CSV、JSON、纯文本报告
#  ✓ 时间筛选：支持按天数筛选最新文献
#  ✓ 自动重试：网络请求失败自动重试，提高稳定性
#  ✓ 邮件发送：搜索完成后自动发送文献报告到邮箱（包含题目、摘要、日期、来源）
#
# ─────────────────────────────────────────────────────────────────────────────
# 【数据源说明】
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. Semantic Scholar (首选推荐) ⭐
#    - 类型：AI 驱动的学术知识图谱（由艾伦人工智能研究所提供）
#    - 特点：
#      • 高度结构化数据（标题、摘要、作者、引用数、参考文献）
#      • 强大的语义分析能力（不仅仅是关键词匹配）
#      • 支持推荐算法 API
#      • 涵盖所有学科领域
#    - API：https://api.semanticscholar.org/
#    - API Key：可选（无 Key 限制 100次/5分钟，有 Key 限制更宽松）
#    - 国内访问：基本可用（偶尔会慢，已内置重试机制）
#    - 适用场景：构建 AI 应用、文献问答、Agent、引用网络分析
#
# 2. Europe PMC (欧洲 PubMed Central)
#    - 类型：生物医学和生命科学文献数据库
#    - 特点：包含大量开放获取论文，有完整的摘要和 PDF 链接
#    - API：https://europepmc.org/RestfulWebService
#    - 无需 API Key
#    - 适用场景：生物医学、生命科学领域
#
# 3. arXiv
#    - 类型：物理、数学、计算机科学等领域的预印本论文库
#    - 特点：所有论文免费开放，PDF 下载成功率 100%
#    - API：https://arxiv.org/help/api/
#    - 无需 API Key
#    - 适用场景：物理、数学、计算机科学、统计学
#
# 4. OpenAlex
#    - 类型：开放学术知识图谱（涵盖所有学科）
#    - 特点：元数据丰富，包含论文引用、作者机构等信息
#    - API：https://api.openalex.org/
#    - 无需 API Key（建议添加邮箱参数以提升速率限制）
#    - 适用场景：全学科文献检索、学术统计分析
#
# 5. Google Custom Search Engine (CSE)【可选】
#    - 类型：自定义搜索引擎，可搜索学术网站
#    - 特点：作为补充源，可搜索到其他源遗漏的论文
#    - API：https://developers.google.com/custom-search
#    - **需要 API Key 和 Search Engine ID**（见配置章节）
#    - 适用场景：补充搜索
#
# ─────────────────────────────────────────────────────────────────────────────
# 【PDF 下载策略】（7 个候选源，按优先级）
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. arXiv 官方 PDF (https://arxiv.org/pdf/...)
#    - 最可靠，适用于所有 arXiv 论文
#
# 2. 原始 PDF 链接
#    - 使用搜索结果中提供的 pdf_url 字段
#
# 3. Unpaywall (https://unpaywall.org/)
#    - 基于 DOI 查找开放获取版本
#    - 数据库包含超过 3000 万篇开放论文
#
# 4. Semantic Scholar (https://www.semanticscholar.org/)
#    - AI 驱动的学术搜索引擎
#    - 提供开放获取 PDF 链接
#
# 5. Europe PMC PDF
#    - 基于 DOI 或标题查找 PMC 论文的 PDF
#
# 6. OpenAlex Open Access
#    - 查询 OpenAlex 中标记为开放获取的论文 PDF
#
# 7. Google Custom Search【可选】
#    - 兜底策略，搜索 PDF 文件链接
#
# ─────────────────────────────────────────────────────────────────────────────
# 【依赖要求】
# ─────────────────────────────────────────────────────────────────────────────
#
# 1. R 环境（>= 4.0）
# 2. R 包（脚本会自动安装）：
#    - jsonlite：JSON 解析
#    - dplyr：数据处理
# 3. Node.js（>= 14.0）- 用于调用 MCP 工具
# 4. curl：网络请求（macOS/Linux 自带）
# 5. 可选：Google API Key（如需使用 Google 搜索源）
#
# ─────────────────────────────────────────────────────────────────────────────
# 【安装步骤】
# ─────────────────────────────────────────────────────────────────────────────
#
# 步骤 1: 安装 R（如果还没安装）
#   macOS:   brew install r
#   Ubuntu:  sudo apt-get install r-base
#   Windows: 从 https://cran.r-project.org/ 下载安装包
#
# 步骤 2: 安装 Node.js（如果还没安装）
#   macOS:   brew install node
#   Ubuntu:  sudo apt-get install nodejs npm
#   Windows: 从 https://nodejs.org/ 下载安装包
#
# 步骤 3: 安装项目依赖（在项目目录下执行）
#   npm install
#
# 步骤 4: 构建项目（如果 dist 目录不存在）
#   npm run build
#
# 步骤 5: 给脚本添加执行权限（macOS/Linux）
#   chmod +x download_papersv11.R
#
# 步骤 6: 配置 Google API（可选，如需使用 Google 搜索源）
#   # 6.1 获取 Google API Key
#   - 访问：https://console.cloud.google.com/
#   - 创建项目 → 启用 "Custom Search API"
#   - 创建凭据 → API 密钥
#
#   # 6.2 创建自定义搜索引擎
#   - 访问：https://programmablesearchengine.google.com/
#   - 创建搜索引擎，添加要搜索的网站（如 arxiv.org, pubmed.gov）
#   - 获取 Search Engine ID (CX)
#
#   # 6.3 设置环境变量
#   export GOOGLE_API_KEY="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#   export GOOGLE_CX="012345678901234567890:abcdefghij"
#
#   # 或者添加到 ~/.bashrc 或 ~/.zshrc 使其永久生效
#
# ─────────────────────────────────────────────────────────────────────────────
# 【使用方法】
# ─────────────────────────────────────────────────────────────────────────────
#
# 基本语法：
#   Rscript download_papersv11.R <关键词> [论文数量] [天数]
#
# 参数说明：
#   <关键词>    : 必需，搜索关键词（用引号包含多个词）
#   [论文数量]  : 可选，每个数据源返回的论文数（默认：5，最大：20）
#   [天数]      : 可选，搜索最近多少天的论文（默认：10，最大：365）
#
# 使用示例：
#
#   # 示例 1: 搜索 "starch" 相关论文（默认每源 5 篇，最近 10 天）
#   Rscript download_papersv11.R starch
#
#   # 示例 2: 搜索 10 篇最近 30 天的 "machine learning" 论文
#   Rscript download_papersv11.R "machine learning" 10 30
#
#   # 示例 3: 搜索 15 篇最近 7 天的 "COVID-19" 论文
#   Rscript download_papersv11.R "COVID-19" 15 7
#
#   # 示例 4: 搜索 "CRISPR gene editing" 相关论文
#   Rscript download_papersv11.R "CRISPR gene editing" 8 14
#
# 注意事项：
#   - 多个词的关键词需要用引号包围
#   - 数量设置过大可能导致运行时间较长
#   - 部分 PDF 可能因版权限制无法下载
#
# ─────────────────────────────────────────────────────────────────────────────
# 【输出说明】
# ─────────────────────────────────────────────────────────────────────────────
#
# 输出目录结构：
#   output/
#   ├── <关键词>_papers/
#   │   ├── papers_YYYYMMDD_HHMMSS.csv      # CSV 格式结果
#   │   ├── papers_YYYYMMDD_HHMMSS.json     # JSON 格式结果
#   │   └── report_YYYYMMDD_HHMMSS.txt      # 纯文本报告
#   └── <关键词>_pdfs/
#       ├── paper1.pdf
#       ├── paper2.pdf
#       └── ...
#
# CSV 文件包含字段：
#   - id: 论文唯一标识符
#   - title: 论文标题
#   - authors: 作者列表
#   - date: 发表日期
#   - days_ago: 距今天数
#   - abstract: 摘要
#   - pdf_url: 原始 PDF 链接
#   - source: 数据源（europepmc/arxiv/openalex/google）
#   - pdf_ok: PDF 是否下载成功
#   - pdf_file: 下载的 PDF 文件名
#   - pdf_mb: PDF 文件大小（MB）
#   - pdf_source: PDF 来源
#
# ─────────────────────────────────────────────────────────────────────────────
# 【配置说明】
# ─────────────────────────────────────────────────────────────────────────────
#
# 可在下方 CONFIG 列表中修改的参数：
#
#   DEFAULT_COUNT    : 默认每源论文数（默认：5）
#   DEFAULT_DAYS     : 默认搜索天数（默认：10）
#   OUTPUT_DIR       : 输出目录（默认：output）
#   SOURCES          : 启用的数据源列表
#   DELAY_SEC        : 请求间隔（秒，避免被限流）
#   UNPAYWALL_EMAIL  : Unpaywall API 邮箱（建议修改为你的邮箱）
#   MAX_ABSTRACT_LEN : 摘要最大长度（防止全文误入）
#   GOOGLE_API_KEY   : Google API 密钥（通过环境变量传入）
#   GOOGLE_CX        : Google 搜索引擎 ID（通过环境变量传入）
#   EMAIL_ENABLED    : 是否启用邮件发送（默认：TRUE）
#   EMAILJS_*        : EmailJS 邮件服务配置（用于发送文献报告）
#
# ─────────────────────────────────────────────────────────────────────────────
# 【常见问题】
# ─────────────────────────────────────────────────────────────────────────────
#
# Q1: 提示 "node: command not found"
# A1: 需要安装 Node.js，参考上方【安装步骤】
#
# Q2: PDF 下载失败率高
# A2: 部分论文确实无开放 PDF，这是正常现象。可以：
#     - 通过学校/机构的图书馆数据库下载
#     - 联系作者索取
#
# Q3: Google 搜索源不可用
# A3: 需要配置 GOOGLE_API_KEY 和 GOOGLE_CX 环境变量
#     如果不需要，可以在 SOURCES 中删除 "google"
#
# Q4: 运行速度慢
# A4: 可以减少搜索的论文数量，或减少启用的数据源
#
# Q5: 摘要显示 "(无)"
# A5: 部分数据源不提供摘要，或摘要获取失败
#     可以通过论文 ID 访问原始网站查看
#
# Q6: 如何修改 Unpaywall 邮箱？
# A6: 修改下方 CONFIG 中的 UNPAYWALL_EMAIL 字段
#
# Q7: 输出文件编码问题
# A7: 使用 UTF-8 编码打开 CSV 文件（Excel 可能需要导入向导）
#
# ─────────────────────────────────────────────────────────────────────────────
# 【更新日志】
# ─────────────────────────────────────────────────────────────────────────────
#
# v3.0 (当前版本): Semantic Scholar 首选版
#      - 新增 Semantic Scholar 作为首选搜索源
#      - 添加自动重试机制（HTTP 请求失败自动重试 3 次）
#      - 支持 Semantic Scholar API Key（可选）
#      - 优化超时设置（从 15 秒增加到 30 秒）
#      - 更新数据源优先级：S2 > Europe PMC > arXiv > OpenAlex
#
# v2.7: 新增 Google Custom Search API 支持
#      - 作为第四搜索源搜索学术论文
#      - 作为 PDF 查找最终兜底（第 7 候选源）
#
# v2.6: 严格限制摘要长度
#      - 防止全文误入 CSV
#      - 优化摘要提取正则逻辑
#
# v2.5: 搜索源优先 Europe PMC
#      - 修复 CSV 输出时的换行符导致乱行问题
#
#
# =============================================================================

args_cmd <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args_cmd[grep("--file=", args_cmd)])
if (length(script_path) > 0) setwd(dirname(normalizePath(script_path)))

for (pkg in c("jsonlite", "dplyr")) {
  if (!require(pkg, quietly = TRUE, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
    library(pkg, character.only = TRUE)
  }
}

CONFIG <- list(
  # 每个数据源默认返回的论文数量（用户可通过命令行参数覆盖）
  DEFAULT_COUNT    = 5,

  # 默认搜索最近多少天的论文（用户可通过命令行参数覆盖）
  DEFAULT_DAYS     = 10,

  # 输出目录，所有结果都保存在此目录下
  OUTPUT_DIR       = "output",

  # 启用的数据源列表（可删除不需要的源以提高速度）
  # ⭐ "semanticscholar" = Semantic Scholar（首选推荐，全学科）
  # "europepmc"         = 欧洲PubMed（生物医学）
  # "arxiv"             = arXiv预印本（物理/数学/计算机）
  # "openalex"          = OpenAlex开放学术（全学科）
  # "google"            = Google自定义搜索（需配置API，可选）
  SOURCES          = c("semanticscholar", "europepmc", "arxiv", "openalex"),

  # 请求间隔秒数，避免被API限流（建议保持 2-3 秒）
  DELAY_SEC        = 2,

  # HTTP 请求超时时间（秒），针对国内网络环境优化
  HTTP_TIMEOUT     = 30,

  # HTTP 请求失败后的最大重试次数
  MAX_RETRIES      = 3,

  # 每次重试之间的等待时间（秒）
  RETRY_DELAY      = 2,

  # Unpaywall API 邮箱（用于查找开放获取PDF）
  # ⚠️ 建议修改为你自己的邮箱，这样如有问题 Unpaywall 可以联系你
  UNPAYWALL_EMAIL  = "479321347@qq.com",

  # 摘要最大长度限制（字符数），防止全文误入 CSV
  MAX_ABSTRACT_LEN = 4000,

  # ── Semantic Scholar API 配置 ────────────────────────────────────────────
  # Semantic Scholar API Key（可选，推荐申请）
  # 无 Key 模式：100 次请求 / 5 分钟（适合小规模测试）
  # 有 Key 模式：速率限制更宽松（推荐用于生产环境）
  #
  # 申请地址：https://www.semanticscholar.org/product/api#api-key
  # 通过环境变量传入（推荐）：
  #   export S2_API_KEY="your_api_key_here"
  S2_API_KEY       = Sys.getenv("S2_API_KEY", ""),
  # ──────────────────────────────────────────────────────────────────────────

  # ── Google Custom Search API 配置 ───────────────────────────────────────
  # 推荐通过环境变量传入，避免密钥硬编码到脚本中：
  #   export GOOGLE_API_KEY="AIza..."
  #   export GOOGLE_CX="012345678..."
  #
  # 如果不使用 Google 搜索源，保持为空字符串即可（会自动跳过）
  GOOGLE_API_KEY   = Sys.getenv("GOOGLE_API_KEY", ""),
  GOOGLE_CX        = Sys.getenv("GOOGLE_CX",      ""),
  # ────────────────────────────────────────────────────────────────────────

  # ── 邮件发送配置 ───────────────────────────────────────────────────────
  # 通过 Python smtplib 发送邮件（无需 Java/mailR，macOS 自带 Python）
  EMAIL_ENABLED   = TRUE,                            # 是否启用邮件发送功能
  SMTP_USER       = "479321347@qq.com",              # 发件人 QQ 邮箱
  SMTP_AUTH_CODE  = Sys.getenv("QQ_AUTH_CODE", "utdwpcjamkewcbbd"),  # QQ 授权码
  RECIPIENT_EMAIL = Sys.getenv("RECIPIENT_EMAIL", "479321347@qq.com")  # 收件人邮箱
  # ────────────────────────────────────────────────────────────────────────
)

log_msg <- function(msg, type = "INFO") {
  ts  <- format(Sys.time(), "%H:%M:%S")
  sym <- switch(type, "ERROR" = "✖", "SUCCESS" = "✔", "WARN" = "⚠", "🔄" = "🔄", "ℹ")
  cat(sprintf("[%s] %s %s\n", ts, sym, msg))
}

# ─── HTTP 请求工具（带重试机制）───────────────────────────────────────────────

curl_with_retry <- function(url, max_retries = CONFIG$MAX_RETRIES,
                             timeout = CONFIG$HTTP_TIMEOUT,
                             headers = NULL, verbose = FALSE) {
  for (attempt in 1:max_retries) {
    tryCatch({
      # 构建 curl 命令
      header_args <- if (!is.null(headers)) {
        paste(sapply(names(headers), function(k)
          sprintf("-H '%s: %s'", k, headers[[k]])), collapse = " ")
      } else ""

      cmd <- sprintf(
        "curl -sL --max-time %d %s '%s' 2>&1",
        timeout, header_args, url
      )

      if (verbose && attempt > 1) {
        cat(sprintf("    🔄 重试第 %d/%d 次...\n", attempt - 1, max_retries - 1))
      }

      result <- system(cmd, intern = TRUE)

      # 检查结果是否有效
      if (length(result) > 0 && !grepl("curl: \\(", result[1])) {
        return(list(success = TRUE, content = paste(result, collapse = "\n")))
      }

      # 如果是最后一次尝试，返回失败
      if (attempt == max_retries) {
        return(list(success = FALSE, content = "", error = "Max retries reached"))
      }

      # 等待后重试
      Sys.sleep(CONFIG$RETRY_DELAY)

    }, error = function(e) {
      if (attempt == max_retries) {
        return(list(success = FALSE, content = "", error = e$message))
      }
      Sys.sleep(CONFIG$RETRY_DELAY)
    })
  }
  list(success = FALSE, content = "", error = "Unknown error")
}

# ─── Semantic Scholar 搜索 ────────────────────────────────────────────────────

search_semanticscholar <- function(q, n, days) {
  api_key <- CONFIG$S2_API_KEY

  log_msg(sprintf("搜索 SEMANTIC SCHOLAR: '%s' (最近 %d 天)", q, days))

  if (api_key != "") {
    log_msg("使用 Semantic Scholar API Key", "SUCCESS")
  } else {
    log_msg("无 API Key 模式（限制 100次/5分钟）", "WARN")
  }

  # 计算日期范围
  date_from <- format(Sys.Date() - days, "%Y-%m-%d")

  # 构建查询
  # Semantic Scholar 支持高级查询语法
  query_parts <- c(q)
  query_parts <- c(query_parts, sprintf("year>=%s", format(Sys.Date() - days, "%Y")))
  full_query <- paste(query_parts, collapse = " ")

  # API 端点
  base_url <- "https://api.semanticscholar.org/graph/v1/paper/search"
  url <- sprintf(
    "%s?query=%s&limit=%d&fields=paperId,title,abstract,authors,year,publicationDate,citationCount,openAccessPdf,externalIds",
    base_url,
    utils::URLencode(full_query, reserved = FALSE),
    n * 2  # 请求更多以便过滤
  )

  # 构建请求头
  headers <- if (api_key != "") {
    list("x-api-key" = api_key)
  } else {
    NULL
  }

  # 发起请求（带重试）
  response <- curl_with_retry(url, headers = headers, verbose = TRUE)

  if (!response$success) {
    log_msg("Semantic Scholar API 请求失败", "ERROR")
    return(NULL)
  }

  # 解析 JSON
  tryCatch({
    parsed <- fromJSON(response$content)

    if (is.null(parsed$data) || length(parsed$data) == 0) {
      log_msg("Semantic Scholar: 未找到结果", "WARN")
      return(NULL)
    }

    data <- parsed$data

    # 构建论文列表
    papers_list <- lapply(seq_len(nrow(data)), function(i) {
      paper <- data[i, ]

      # 提取作者
      authors <- if (!is.null(paper$authors) && length(paper$authors) > 0) {
        if (is.list(paper$authors[[1]])) {
          author_names <- sapply(paper$authors[[1]], function(a) a$name %||% "")
          paste(author_names, collapse = "; ")
        } else {
          ""
        }
      } else {
        ""
      }

      # 提取 PDF URL
      pdf_url <- NA_character_
      if (!is.null(paper$openAccessPdf) && length(paper$openAccessPdf) > 0) {
        if (is.list(paper$openAccessPdf)) {
          pdf_url <- paper$openAccessPdf[[1]]$url %||% NA_character_
        } else if (!is.na(paper$openAccessPdf)) {
          pdf_url <- paper$openAccessPdf
        }
      }

      # 提取 DOI 和 arXiv ID
      doi <- NA_character_
      arxiv_id <- NA_character_
      if (!is.null(paper$externalIds) && length(paper$externalIds) > 0) {
        ext_ids <- paper$externalIds[[1]]
        if (!is.null(ext_ids$DOI)) doi <- ext_ids$DOI
        if (!is.null(ext_ids$ArXiv)) arxiv_id <- ext_ids$ArXiv
      }

      # 构建论文 ID
      paper_id <- if (!is.na(doi)) {
        paste0("https://doi.org/", doi)
      } else if (!is.na(arxiv_id)) {
        paste0("https://arxiv.org/abs/", arxiv_id)
      } else {
        paste0("https://www.semanticscholar.org/paper/", paper$paperId)
      }

      # 日期处理
      pub_date <- paper$publicationDate %||%
                  (if (!is.null(paper$year) && !is.na(paper$year))
                    paste0(paper$year, "-01-01") else NA_character_)

      data.frame(
        id       = paper_id,
        title    = paper$title %||% "",
        authors  = authors,
        date     = pub_date,
        doi      = doi,
        abstract = paper$abstract %||% "",
        source   = "semanticscholar",
        pdf_url  = pdf_url,
        citations = paper$citationCount %||% 0,
        stringsAsFactors = FALSE
      )
    })

    df <- do.call(rbind, papers_list)

    # 过滤日期
    df$days_ago <- sapply(df$date, days_since)
    df <- df[!is.na(df$date) & df$days_ago <= days & df$days_ago >= 0, ]

    if (nrow(df) == 0) {
      log_msg(sprintf("Semantic Scholar: 最近 %d 天无结果", days), "WARN")
      return(NULL)
    }

    # 按引用数排序（Semantic Scholar 的优势）
    df <- df[order(-df$citations), ]

    # 限制数量
    if (nrow(df) > n) df <- df[1:n, ]

    log_msg(sprintf("Semantic Scholar: 找到 %d 篇 (平均引用: %.1f)",
                    nrow(df), mean(df$citations, na.rm = TRUE)))

    list(content = df)

  }, error = function(e) {
    log_msg(paste("Semantic Scholar 解析错误:", e$message), "ERROR")
    return(NULL)
  })
}

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

# ─── 文本清洗工具 ───

limit_text_length <- function(x, max_len = CONFIG$MAX_ABSTRACT_LEN) {
  if (is.null(x) || is.na(x)) return("")
  x <- as.character(x)
  if (nchar(x) > max_len) return(paste0(substr(x, 1, max_len), "... [Truncated/Content too long]"))
  x
}

clean_text_for_csv <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return("")
  x <- as.character(x)
  x <- limit_text_length(x)
  x <- gsub("[\r\n\t]+", " ", x)
  x <- gsub("\\s+", " ", x)
  x <- gsub('"', '""', x, fixed = TRUE)
  trimws(x)
}

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a) && nchar(as.character(a)) > 0) a else b

create_dirs <- function(kw) {
  name <- safe_name(kw)
  base <- file.path(CONFIG$OUTPUT_DIR, paste0(name, "_papers"))
  pdf  <- file.path(CONFIG$OUTPUT_DIR, paste0(name, "_pdfs"))
  if (!dir.exists(base)) dir.create(base, recursive = TRUE)
  if (!dir.exists(pdf))  dir.create(pdf,  recursive = TRUE)
  list(base = base, pdf = pdf, name = name)
}

days_since <- function(date_str) {
  if (is.na(date_str) || date_str == "") return(Inf)
  tryCatch(as.numeric(Sys.Date() - as.Date(date_str)), error = function(e) Inf)
}

# ─── 摘要提取工具 ──────────────────────────────────────────────────────────────

get_abstract_text <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  if (is.character(x)) return(trimws(paste(x, collapse = " ")))
  if (is.list(x))      return(trimws(paste(unlist(x), collapse = " ")))
  trimws(as.character(x))
}

extract_abstract_from_text <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")
  m <- regmatches(text, regexpr(
    "(?i)Abstract[:\\s]*\\n?([\\s\\S]+?)(?=\\n[A-Z][a-zA-Z ]{2,}\\n|\\n\\d\\.\\s|$)",
    text, perl = TRUE))
  if (length(m) > 0) {
    abst <- trimws(gsub("\\s+", " ", sub("(?i)^Abstract[:\\s]*\\n?", "", m[1], perl = TRUE)))
    if (nchar(abst) > 30) return(abst)
  }
  m2 <- regmatches(text, regexpr("(?i)Abstract[:\\s]+(.+)", text, perl = TRUE))
  if (length(m2) > 0) {
    abst <- trimws(sub("(?i)Abstract[:\\s]+", "", m2[1], perl = TRUE))
    if (nchar(abst) > 30) return(abst)
  }
  ""
}

reconstruct_openalex_abstract <- function(inv_index) {
  if (is.null(inv_index) || length(inv_index) == 0) return("")
  tryCatch({
    pairs <- lapply(names(inv_index), function(word) {
      data.frame(word = word, pos = as.integer(unlist(inv_index[[word]])), stringsAsFactors = FALSE)
    })
    df <- do.call(rbind, pairs)
    paste(df[order(df$pos), "word"], collapse = " ")
  }, error = function(e) "")
}

fetch_abstract_arxiv <- function(paper_id) {
  id  <- gsub(".*/abs/|v\\d+$", "", paper_id)
  url <- sprintf("https://export.arxiv.org/api/query?id_list=%s", id)
  tryCatch({
    txt <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "\n")
    m   <- regmatches(txt, regexpr("(?s)<summary>(.+?)</summary>", txt, perl = TRUE))
    if (length(m) == 0) return("")
    trimws(gsub("\\s+", " ", sub("</?summary>", "", m[1])))
  }, error = function(e) "")
}

fetch_abstract_openalex <- function(paper_id) {
  id <- paper_id
  if (grepl("openalex.org/W", id)) id <- gsub(".*/", "", id)
  else if (grepl("doi.org", id))   id <- paste0("doi:", gsub(".*doi.org/", "", id))
  url <- sprintf("https://api.openalex.org/works/%s?select=abstract_inverted_index", id)
  tryCatch({
    parsed <- fromJSON(paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = ""))
    reconstruct_openalex_abstract(parsed$abstract_inverted_index)
  }, error = function(e) "")
}

# ─── 【新增】通过 CrossRef API 获取摘要（适用于高档期刊）─────────────────
fetch_abstract_crossref <- function(doi) {
  if (is.null(doi) || is.na(doi) || doi == "") return("")
  url <- sprintf("https://api.crossref.org/works/%s",
                 utils::URLencode(doi, reserved = TRUE))
  tryCatch({
    result <- curl_with_retry(url, timeout = 20)
    if (!result$success) return("")

    parsed <- fromJSON(result$content)
    if (!is.null(parsed$message$abstract)) {
      # CrossRef 的摘要可能包含 HTML 标签，需要清理
      abstract <- parsed$message$abstract
      abstract <- gsub("<[^>]+>", "", abstract)  # 移除 HTML 标签
      abstract <- gsub("&[a-z]+;", "", abstract)  # 移除 HTML 实体
      abstract <- trimws(gsub("\\s+", " ", abstract))
      if (nchar(abstract) > 50) return(abstract)
    }
    ""
  }, error = function(e) "")
}

# ─── 【新增】通过 PubMed API 获取摘要 ─────────────────────────────────────
fetch_abstract_pubmed <- function(title = NULL, doi = NULL) {
  if ((is.null(title) || title == "") && (is.null(doi) || doi == "")) return("")

  tryCatch({
    # 步骤 1: 搜索获取 PMID
    search_term <- if (!is.null(doi) && doi != "") {
      sprintf('"%s"[DOI]', doi)
    } else {
      # 对标题进行清理，提取关键部分
      title_clean <- substr(title, 1, 100)
      sprintf('"%s"[Title]', title_clean)
    }

    search_url <- sprintf(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=%s&retmode=json&retmax=1",
      utils::URLencode(search_term, reserved = FALSE)
    )

    search_result <- curl_with_retry(search_url, timeout = 15)
    if (!search_result$success) return("")

    search_data <- fromJSON(search_result$content)
    pmid_list <- search_data$esearchresult$idlist

    if (is.null(pmid_list) || length(pmid_list) == 0) return("")

    pmid <- pmid_list[1]

    # 步骤 2: 通过 PMID 获取摘要
    fetch_url <- sprintf(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&id=%s&retmode=xml",
      pmid
    )

    fetch_result <- curl_with_retry(fetch_url, timeout = 15)
    if (!fetch_result$success) return("")

    xml_content <- fetch_result$content

    # 从 XML 中提取摘要
    abstract_match <- regmatches(xml_content,
      regexpr("<AbstractText[^>]*>([\\s\\S]*?)</AbstractText>", xml_content, perl = TRUE))

    if (length(abstract_match) > 0) {
      abstract <- gsub("<[^>]+>", "", abstract_match[1])  # 移除 XML 标签
      abstract <- trimws(gsub("\\s+", " ", abstract))
      if (nchar(abstract) > 50) {
        cat(sprintf("      ✔ PubMed 获取成功 (PMID: %s)\n", pmid))
        return(abstract)
      }
    }

    ""
  }, error = function(e) {
    cat(sprintf("      ✗ PubMed 错误: %s\n", e$message))
    ""
  })
}

# ─── 【新增】通过 Semantic Scholar 详细API 获取摘要 ──────────────────────
fetch_abstract_s2_detailed <- function(doi = NULL, title = NULL) {
  if (is.null(doi) && is.null(title)) return("")

  api_key <- CONFIG$S2_API_KEY
  headers <- if (api_key != "") list("x-api-key" = api_key) else NULL

  tryCatch({
    # 优先使用 DOI 查询
    if (!is.null(doi) && doi != "") {
      paper_id <- paste0("DOI:", doi)
      url <- sprintf(
        "https://api.semanticscholar.org/graph/v1/paper/%s?fields=abstract,title,year",
        utils::URLencode(paper_id, reserved = FALSE)
      )

      result <- curl_with_retry(url, headers = headers, timeout = 20)
      if (result$success) {
        parsed <- fromJSON(result$content)
        if (!is.null(parsed$abstract) && nchar(parsed$abstract) > 50) {
          return(trimws(parsed$abstract))
        }
      }
    }

    # 如果 DOI 失败，尝试标题搜索
    if (!is.null(title) && nchar(title) > 10) {
      search_url <- sprintf(
        "https://api.semanticscholar.org/graph/v1/paper/search?query=%s&fields=abstract,paperId&limit=1",
        utils::URLencode(substr(title, 1, 100), reserved = FALSE)
      )

      result <- curl_with_retry(search_url, headers = headers, timeout = 20)
      if (result$success) {
        parsed <- fromJSON(result$content)
        if (!is.null(parsed$data) && length(parsed$data) > 0) {
          abstract <- parsed$data[[1]]$abstract
          if (!is.null(abstract) && nchar(abstract) > 50) {
            return(trimws(abstract))
          }
        }
      }
    }

    ""
  }, error = function(e) "")
}

fetch_abstract_fallback <- function(src, paper_id, doi = NULL, title = NULL) {
  if (src == "arxiv")    return(fetch_abstract_arxiv(paper_id))
  if (src == "openalex") return(fetch_abstract_openalex(paper_id))

  # 【新增】对于其他来源，如果有 DOI，尝试高档期刊摘要获取策略
  if (!is.null(doi) && doi != "") {
    cat("      🔍 尝试 CrossRef API...\n")
    abstract <- fetch_abstract_crossref(doi)
    if (nchar(abstract) > 50) return(abstract)

    cat("      🔍 尝试 PubMed API...\n")
    abstract <- fetch_abstract_pubmed(doi = doi)
    if (nchar(abstract) > 50) return(abstract)

    cat("      🔍 尝试 Semantic Scholar 详细查询...\n")
    abstract <- fetch_abstract_s2_detailed(doi = doi, title = title)
    if (nchar(abstract) > 50) return(abstract)
  }

  # 如果没有 DOI 但有标题，尝试 PubMed 搜索
  if (!is.null(title) && nchar(title) > 10) {
    cat("      🔍 尝试 PubMed 标题搜索...\n")
    abstract <- fetch_abstract_pubmed(title = title)
    if (nchar(abstract) > 50) return(abstract)
  }

  ""
}

# ─── PDF URL 构建：多源候选清单 ───────────────────────────────────────────────

extract_arxiv_id <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return(NULL)
  m <- regmatches(x, regexpr("(\\d{4}\\.\\d{4,5})", x, perl = TRUE))
  if (length(m) > 0) return(m[1])
  NULL
}

extract_doi <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return(NULL)
  m <- regmatches(x, regexpr("10\\.\\d{4,}/[^\\s\"'<>]+", x, perl = TRUE))
  if (length(m) > 0) return(m[1])
  NULL
}

get_unpaywall_pdf_url <- function(doi, email = CONFIG$UNPAYWALL_EMAIL) {
  if (is.null(doi) || doi == "") return(NULL)
  url <- sprintf("https://api.unpaywall.org/v2/%s?email=%s",
                 utils::URLencode(doi, reserved = TRUE), email)
  tryCatch({
    txt    <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "")
    parsed <- fromJSON(txt)
    pdf_url <- parsed$best_oa_location$url_for_pdf %||%
               parsed$best_oa_location$url %||% NULL
    if (!is.null(pdf_url) && grepl("^https?://", pdf_url)) return(pdf_url)
    locs <- parsed$oa_locations
    if (!is.null(locs) && is.data.frame(locs)) {
      for (i in seq_len(nrow(locs))) {
        u <- locs$url_for_pdf[i] %||% ""
        if (!is.na(u) && grepl("^https?://", u)) return(u)
      }
    }
    NULL
  }, error = function(e) NULL)
}

get_semanticscholar_pdf_url <- function(doi = NULL, arxiv_id = NULL, title = NULL) {
  query_id <- NULL
  if (!is.null(arxiv_id)) query_id <- paste0("ARXIV:", arxiv_id)
  else if (!is.null(doi)) query_id <- paste0("DOI:", utils::URLencode(doi, reserved = TRUE))

  if (!is.null(query_id)) {
    url <- sprintf("https://api.semanticscholar.org/graph/v1/paper/%s?fields=openAccessPdf,externalIds", query_id)
    tryCatch({
      txt    <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "")
      parsed <- fromJSON(txt)
      pdf_url <- parsed$openAccessPdf$url %||% NULL
      if (!is.null(pdf_url) && grepl("^https?://", pdf_url)) return(pdf_url)
    }, error = function(e) NULL)
  }

  if (!is.null(title) && nchar(title) > 10) {
    q   <- utils::URLencode(substr(title, 1, 80), reserved = TRUE)
    url <- sprintf("https://api.semanticscholar.org/graph/v1/paper/search?query=%s&fields=openAccessPdf&limit=1", q)
    tryCatch({
      txt    <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "")
      parsed <- fromJSON(txt)
      if (!is.null(parsed$data) && length(parsed$data) > 0) {
        pdf_url <- parsed$data[[1]]$openAccessPdf$url %||% NULL
        if (!is.null(pdf_url) && grepl("^https?://", pdf_url)) return(pdf_url)
      }
    }, error = function(e) NULL)
  }
  NULL
}

get_pmc_pdf_url <- function(doi = NULL, title = NULL) {
  query <- if (!is.null(doi)) sprintf("DOI:\"%s\"", doi) else if (!is.null(title)) sprintf("TITLE:\"%s\"", substr(title, 1, 60)) else return(NULL)
  url <- sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%s&format=json&resulttype=core&pageSize=1",
                 utils::URLencode(query, reserved = TRUE))
  tryCatch({
    txt    <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "")
    parsed <- fromJSON(txt)
    result <- parsed$resultList$result
    if (!is.null(result) && length(result) > 0) {
      pmcid <- result[[1]]$pmcid %||% NULL
      if (!is.null(pmcid) && grepl("^PMC", pmcid)) {
        id_num <- gsub("PMC", "", pmcid)
        return(sprintf("https://www.ncbi.nlm.nih.gov/pmc/articles/PMC%s/pdf/", id_num))
      }
    }
    NULL
  }, error = function(e) NULL)
}

# ─── 【新增】Google CSE 搜索论文 ──────────────────────────────────────────────

search_google_papers <- function(q, n, days) {
  api_key <- CONFIG$GOOGLE_API_KEY
  cx      <- CONFIG$GOOGLE_CX

  if (api_key == "" || cx == "") {
    log_msg("Google API Key 或 CX 未配置，跳过 Google 搜索源", "WARN")
    return(NULL)
  }

  site_filter <- paste(
    "site:arxiv.org OR site:pubmed.ncbi.nlm.nih.gov",
    "OR site:biorxiv.org OR site:medrxiv.org OR site:semanticscholar.org",
    sep = " "
  )
  full_query <- sprintf("%s %s after:%s", q, site_filter,
                        format(Sys.Date() - days, "%Y-%m-%d"))

  max_pages <- ceiling(min(n, 30) / 10)
  all_items <- list()

  log_msg(sprintf("搜索 GOOGLE CSE: '%s' (最近 %d 天)", q, days))

  for (page in seq_len(max_pages)) {
    start_idx <- (page - 1) * 10 + 1
    url <- sprintf(
      "https://www.googleapis.com/customsearch/v1?key=%s&cx=%s&q=%s&num=10&start=%d&dateRestrict=d%d&fields=items(title,link,snippet,pagemap)",
      utils::URLencode(api_key, reserved = TRUE),
      utils::URLencode(cx,      reserved = TRUE),
      utils::URLencode(full_query, reserved = FALSE),
      start_idx,
      days
    )
    tryCatch({
      json_txt <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "")
      if (nchar(json_txt) < 10) break
      parsed <- fromJSON(json_txt)
      if (!is.null(parsed$error)) {
        log_msg(sprintf("Google API 错误: %s", parsed$error$message), "ERROR")
        break
      }
      if (is.null(parsed$items) || length(parsed$items) == 0) break
      all_items <- c(all_items, list(parsed$items))
      Sys.sleep(0.5)
    }, error = function(e) {
      log_msg(paste("Google CSE 请求失败:", e$message), "WARN")
    })
  }

  if (length(all_items) == 0) {
    log_msg("Google CSE: 未找到结果", "WARN")
    return(NULL)
  }

  items_all   <- do.call(rbind, lapply(all_items, as.data.frame))
  papers_list <- lapply(seq_len(nrow(items_all)), function(i) {
    item    <- items_all[i, ]
    link    <- item$link    %||% ""
    title   <- item$title   %||% ""
    snippet <- item$snippet %||% ""

    arxiv_id    <- extract_arxiv_id(link)
    doi_val     <- extract_doi(link)
    authors_val <- ""
    date_val    <- NA_character_

    tryCatch({
      pm <- item$pagemap
      if (!is.null(pm$metatags)) {
        mt <- pm$metatags[[1]]
        if (!is.null(mt[["citation_author"]]))
          authors_val <- mt[["citation_author"]]
        if (!is.null(mt[["citation_publication_date"]]))
          date_val <- substr(mt[["citation_publication_date"]], 1, 10)
        if (!is.null(mt[["citation_doi"]]) && is.null(doi_val))
          doi_val <- mt[["citation_doi"]]
      }
    }, error = function(e) NULL)

    if (is.na(date_val) || date_val == "")
      date_val <- as.character(Sys.Date())

    pdf_url_val <- NA_character_
    if (!is.null(arxiv_id)) {
      pdf_url_val <- sprintf("https://arxiv.org/pdf/%s.pdf", arxiv_id)
    } else if (grepl("biorxiv\\.org|medrxiv\\.org", link)) {
      pdf_url_val <- paste0(gsub("\\?.*$", "", link), ".full.pdf")
    }

    data.frame(
      id       = if (!is.null(arxiv_id)) paste0("https://arxiv.org/abs/", arxiv_id)
                 else if (!is.null(doi_val)) paste0("https://doi.org/", doi_val)
                 else link,
      title    = trimws(gsub("\\s*[-|].*$", "", title)),
      authors  = authors_val,
      date     = date_val,
      doi      = doi_val %||% NA_character_,
      abstract = snippet,
      source   = "google",
      pdf_url  = pdf_url_val,
      stringsAsFactors = FALSE
    )
  })

  df          <- do.call(rbind, papers_list)
  df$days_ago <- sapply(df$date, days_since)
  df          <- df[!is.na(df$date) & df$id != "", ]
  df          <- df[!duplicated(df$id), ]

  if (nrow(df) == 0) {
    log_msg("Google CSE: 解析后无有效论文", "WARN")
    return(NULL)
  }

  log_msg(sprintf("Google CSE: 找到 %d 篇", nrow(df)))
  list(content = df)
}

# ─── 【新增】Google CSE 补充查找 PDF 链接（兜底第 7 源）──────────────────────

get_google_pdf_url <- function(title, doi = NULL, arxiv_id = NULL) {
  api_key <- CONFIG$GOOGLE_API_KEY
  cx      <- CONFIG$GOOGLE_CX
  if (api_key == "" || cx == "") return(NULL)

  q_parts <- character(0)
  if (!is.null(doi)      && doi      != "") q_parts <- c(q_parts, sprintf('"%s"', doi))
  if (!is.null(arxiv_id) && arxiv_id != "") q_parts <- c(q_parts, arxiv_id)
  if (length(q_parts) == 0)                 q_parts <- sprintf('"%s"', substr(title, 1, 60))
  q_parts <- c(q_parts, "filetype:pdf OR arxiv.org/pdf")

  url <- sprintf(
    "https://www.googleapis.com/customsearch/v1?key=%s&cx=%s&q=%s&num=5&fields=items(link,title)",
    utils::URLencode(api_key, reserved = TRUE),
    utils::URLencode(cx,      reserved = TRUE),
    utils::URLencode(paste(q_parts, collapse = " "), reserved = FALSE)
  )
  tryCatch({
    parsed <- fromJSON(paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = ""))
    if (is.null(parsed$items)) return(NULL)
    for (item in parsed$items) {
      link <- item$link %||% ""
      if (grepl("arxiv\\.org/pdf",           link)) return(link)
      if (grepl("\\.pdf($|\\?)",             link)) return(link)
      if (grepl("biorxiv\\.org|medrxiv\\.org", link))
        return(paste0(gsub("\\?.*$", "", link), ".full.pdf"))
    }
    NULL
  }, error = function(e) NULL)
}

# ─── PDF 候选清单构建（含第 7 源 Google）────────────────────────────────────

build_pdf_candidates <- function(src, paper_id, pdf_url, title, doi_hint = NULL) {
  candidates <- list()

  arxiv_id <- extract_arxiv_id(paper_id) %||% extract_arxiv_id(pdf_url %||% "")
  doi      <- extract_doi(doi_hint %||% "") %||% extract_doi(paper_id) %||% extract_doi(pdf_url %||% "")

  # 1. arXiv
  if (!is.null(arxiv_id)) {
    candidates[["arxiv_pdf"]]    <- sprintf("https://arxiv.org/pdf/%s.pdf", arxiv_id)
    candidates[["arxiv_mirror"]] <- sprintf("https://ar5iv.labs.arxiv.org/html/%s", arxiv_id)
    candidates[["arxiv_export"]] <- sprintf("https://export.arxiv.org/pdf/%s", arxiv_id)
  }

  # 2. 原始（Europe PMC 的 pdf_url 会在这里被优先使用）
  if (!is.null(pdf_url) && !is.na(pdf_url) && pdf_url != "") {
    url2 <- pdf_url
    url2 <- sub("arxiv\\.org/abs/", "arxiv.org/pdf/", url2)
    if (grepl("arxiv.org/pdf/", url2) && !grepl("\\.pdf$", url2)) url2 <- paste0(url2, ".pdf")
    candidates[["original"]] <- url2
  }

  # 3. Unpaywall
  if (!is.null(doi)) {
    candidates[["unpaywall_doi"]] <- list(type = "unpaywall", doi = doi)
  }

  # 4. Semantic Scholar
  candidates[["semanticscholar"]] <- list(type = "s2", doi = doi, arxiv_id = arxiv_id, title = title)

  # 5. Europe PMC
  candidates[["europepmc"]] <- list(type = "pmc", doi = doi, title = title)

  # 6. OpenAlex OA
  if (src == "openalex") {
    oa_id <- gsub(".*/", "", paper_id)
    candidates[["openalex_oa"]] <- list(type = "openalex_oa", id = oa_id)
  }

  # 7. 【新增】Google CSE 兜底
  candidates[["google_search"]] <- list(
    type     = "google",
    doi      = doi,
    arxiv_id = arxiv_id,
    title    = title
  )

  candidates
}

resolve_candidate <- function(cand) {
  if (is.character(cand)) return(cand)
  if (is.list(cand)) {
    switch(cand$type,
      "unpaywall"   = get_unpaywall_pdf_url(cand$doi),
      "s2"          = get_semanticscholar_pdf_url(cand$doi, cand$arxiv_id, cand$title),
      "pmc"         = get_pmc_pdf_url(cand$doi, cand$title),
      "google"      = get_google_pdf_url(cand$title, cand$doi, cand$arxiv_id),  # 【新增】
      "openalex_oa" = {
        tryCatch({
          url <- sprintf("https://api.openalex.org/works/%s?select=open_access", cand$id)
          txt <- paste(system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE), collapse = "")
          p   <- fromJSON(txt)
          p$open_access$oa_url %||% NULL
        }, error = function(e) NULL)
      },
      NULL
    )
  }
}

# ─── 实际下载（带 PDF 校验）────────────────────────────────────────────────

download_pdf_url <- function(url, path) {
  if (is.null(url) || is.na(url) || !grepl("^https?://", url)) return(list(ok = FALSE, blocked = FALSE))
  cmd <- sprintf(
    "curl -sL --max-time 90 -o '%s' -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36' '%s'",
    path, url
  )
  tryCatch({
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (!file.exists(path) || file.size(path) < 200) {
      if (file.exists(path)) unlink(path)
      return(list(ok = FALSE, blocked = FALSE))
    }
    con    <- file(path, "rb")
    header <- readBin(con, "raw", n = 4); close(con)
    is_pdf <- length(header) == 4 &&
              header[1] == 0x25 && header[2] == 0x50 &&
              header[3] == 0x44 && header[4] == 0x46
    if (is_pdf && file.size(path) > 10000) {
      return(list(ok = TRUE, mb = round(file.size(path) / 1048576, 2), blocked = FALSE))
    }
    lines   <- readLines(path, warn = FALSE, n = 50)
    blocked <- any(grepl("cloudflare|challenge|captcha|checking your browser", lines, ignore.case = TRUE))
    unlink(path)
    list(ok = FALSE, blocked = blocked)
  }, error = function(e) {
    if (file.exists(path)) unlink(path)
    list(ok = FALSE, blocked = FALSE)
  })
}

download_pdf_multi <- function(src, paper_id, pdf_url, title, dir, doi_hint = NULL) {
  candidates <- build_pdf_candidates(src, paper_id, pdf_url %||% "", title, doi_hint)
  base_name  <- sprintf("%s_%s_%s", src, safe_name(title, 20), substr(gsub("[^a-z0-9]", "", tolower(paper_id)), 1, 12))
  found_links <- list()

  for (key in names(candidates)) {
    cand <- candidates[[key]]

    if (is.list(cand)) {
      cat(sprintf("    🔍 [%s] 查询中...\n", key))
      resolved <- resolve_candidate(cand)
      if (is.null(resolved) || !grepl("^https?://", resolved %||% "")) {
        cat(sprintf("    ✗ [%s] 未找到链接\n", key))
        Sys.sleep(0.5)
        next
      }
      url_try <- resolved
    } else {
      url_try <- cand
    }

    if (!is.null(url_try) && grepl("^https?://", url_try)) found_links[[key]] <- url_try

    if (grepl("ar5iv\\.labs\\.arxiv\\.org", url_try)) {
      cat(sprintf("    ℹ [%s] HTML 版链接（跳过 PDF 下载）: %s\n", key, url_try))
      next
    }

    fname <- paste0(base_name, ".pdf")
    path  <- file.path(dir, fname)
    cat(sprintf("    ⬇ [%s] %s\n", key, substr(url_try, 1, 70)))

    r <- download_pdf_url(url_try, path)

    if (r$ok) {
      cat(sprintf("    ✔ 成功 %.2f MB（来源: %s）\n", r$mb, key))
      return(list(ok = TRUE, mb = r$mb, file = fname, source = key, blocked = FALSE, links = found_links))
    }
    if (r$blocked) {
      cat(sprintf("    ⚠ [%s] 网站保护，跳过\n", key))
    } else {
      cat(sprintf("    ✗ [%s] 失败，尝试下一源\n", key))
    }
    Sys.sleep(0.8)
  }

  list(ok = FALSE, blocked = FALSE, file = NA_character_, source = NA_character_, links = found_links)
}

# ─── MCP 调用 ────────────────────────────────────────────────────────────────

run_mjs <- function(code, prefix = "R") {
  tmp <- sprintf(".temp_%s_%04d.mjs", format(Sys.time(), "%Y%m%d%H%M%OS3"), sample(1000:9999, 1))
  cat(code, file = tmp)
  out <- tryCatch(system(sprintf("node '%s' 2>&1", tmp), intern = TRUE), error = function(e) character(0))
  unlink(tmp)
  line <- grep(paste0("^", prefix, ":"), out, value = TRUE)[1]
  if (is.na(line)) return(NULL)
  tryCatch(fromJSON(sub(paste0("^", prefix, ":"), "", line)), error = function(e) NULL)
}

search_europepmc_r <- function(q, n, days) {
  date_from <- format(Sys.Date() - days, "%Y-%m-%d")
  date_to   <- format(Sys.Date(), "%Y-%m-%d")
  query_str <- sprintf("%s AND (FIRST_PDATE:[%s TO %s] OR PDATE:[%s TO %s])",
                       q, date_from, date_to, date_from, date_to)
  url <- sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%s&format=json&resulttype=core&pageSize=%d&sort=P_PDATE_D desc",
                 utils::URLencode(query_str, reserved = FALSE), n * 2)
  log_msg(sprintf("搜索 EUROPEPMC: '%s' (API)", q))
  tryCatch({
    json_txt <- paste(system(sprintf("curl -sL --max-time 20 '%s'", url), intern = TRUE), collapse = "")
    if (nchar(json_txt) < 10) return(NULL)
    parsed  <- fromJSON(json_txt)
    results <- parsed$resultList$result
    if (is.null(results) || length(results) == 0) return(NULL)

    ids      <- character(nrow(results))
    pdf_urls <- character(nrow(results))
    for (i in 1:nrow(results)) {
      pmcid <- if ("pmcid" %in% names(results)) results$pmcid[i] else NA
      pmid  <- if ("id"    %in% names(results)) results$id[i]    else NA
      if (!is.null(pmcid) && !is.na(pmcid) && pmcid != "") {
        ids[i]      <- pmcid
        pdf_urls[i] <- sprintf("https://europepmc.org/articles/%s?pdf=render", pmcid)
      } else {
        ids[i]      <- as.character(pmid)
        pdf_urls[i] <- NA
      }
    }

    df <- data.frame(
      id       = ids,
      title    = results$title,
      authors  = results$authorString,
      date     = results$firstPublicationDate,
      doi      = if ("doi"          %in% names(results)) results$doi          else NA,
      abstract = if ("abstractText" %in% names(results)) results$abstractText else "",
      source   = "europepmc",
      pdf_url  = pdf_urls,
      stringsAsFactors = FALSE
    )
    df          <- df[!is.na(df$date), ]
    df$days_ago <- sapply(df$date, days_since)
    df          <- df[df$days_ago <= days & df$days_ago >= 0, ]
    return(list(content = df))
  }, error = function(e) {
    log_msg(paste("EuropePMC API 错误:", e$message), "WARN")
    return(NULL)
  })
}

search_papers <- function(src, q, n, days) {
  log_msg(sprintf("搜索 %s: '%s' (最近 %d 天)", toupper(src), q, days))
  code <- sprintf(
    "import { searchPapers } from './dist/tools/search-papers.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rl = new RateLimiter();
try {
  const r = await searchPapers({source:'%s',query:'%s',field:'all',count:%d,sortBy:'date'}, rl);
  console.log('R:'+JSON.stringify(r));
} catch(e) { console.log('E:'+e.message); }
", src, q, n * 3)
  res <- run_mjs(code)
  if (is.null(res) || is.null(res$content) || length(res$content) == 0) return(NULL)
  papers          <- res$content
  papers$days_ago <- sapply(papers$date, days_since)
  recent          <- papers[papers$days_ago <= days & papers$days_ago >= 0, ]
  if (nrow(recent) == 0) {
    log_msg(sprintf("%s: 无最近 %d 天的结果", toupper(src), days), "WARN"); return(NULL)
  }
  log_msg(sprintf("%s: 找到 %d 篇", toupper(src), nrow(recent)))
  res$content <- recent; res
}

fetch_content_mcp <- function(src, paper_id) {
  code <- sprintf(
    "import { fetchContent } from './dist/tools/fetch-content.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rl = new RateLimiter();
try {
  const r = await fetchContent({source:'%s',id:'%s'}, rl);
  console.log('R:'+JSON.stringify(r));
} catch(e) { console.log('E:'+e.message); }
", src, paper_id)
  run_mjs(code)
}

extract_abstract_from_content_res <- function(res, src) {
  if (is.null(res)) return("")
  candidates <- list(res$content$abstract, res$abstract)
  for (cand in candidates) {
    txt <- get_abstract_text(cand)
    if (nchar(txt) >= 50 && nchar(txt) < 10000) return(limit_text_length(txt))
  }
  if (src == "openalex") {
    inv <- res$content$abstract_inverted_index %||% res$abstract_inverted_index
    if (!is.null(inv)) return(limit_text_length(reconstruct_openalex_abstract(inv)))
  }
  if (!is.null(res$content$text)) {
    txt <- get_abstract_text(res$content$text)
    ex  <- extract_abstract_from_text(txt)
    if (nchar(ex) >= 50) return(limit_text_length(ex))
  }
  ""
}

# ─── 邮件发送功能（Python smtplib）────────────────────────────────────────

send_email_report <- function(keyword, papers_df, pdf_success_count, total_size_mb) {
  if (!CONFIG$EMAIL_ENABLED) {
    log_msg("邮件功能未启用，跳过发送", "WARN")
    return(FALSE)
  }

  # 查找 Python 发送脚本（在脚本同目录或当前工作目录）
  script_dir <- dirname(normalizePath(
    sub("--file=", "", commandArgs(FALSE)[grep("--file=", commandArgs(FALSE))][1])
  ))
  py_script <- file.path(script_dir, "send_email.py")
  if (!file.exists(py_script)) {
    py_script <- file.path(getwd(), "send_email.py")
  }
  if (!file.exists(py_script)) {
    log_msg("未找到 send_email.py，跳过邮件发送", "WARN")
    log_msg("请将 send_email.py 放在脚本目录或当前目录", "WARN")
    return(FALSE)
  }

  log_msg("正在生成邮件报告...")

  # 辅助函数：根据来源和ID生成文章链接
  get_paper_url <- function(source, id, pdf_url) {
    source <- tolower(trimws(source))
    if (source == "arxiv") {
      return(paste0("https://arxiv.org/abs/", id))
    } else if (source == "pmc" || source == "europepmc") {
      # Europe PMC 的链接格式
      return(paste0("https://europepmc.org/article/MED/", id))
    } else if (source == "openalex") {
      # OpenAlex 链接
      if (grepl("^W\\d+", id)) {
        return(paste0("https://openalex.org/works/", id))
      }
    }
    # 如果无法识别来源，尝试使用 pdf_url
    if (!is.na(pdf_url) && nzchar(pdf_url)) {
      # 移除 .pdf 扩展名，可能得到文章页面
      url <- sub("\\.pdf$", "", pdf_url)
      return(url)
    }
    return("")
  }

  # 辅助函数：从摘要中提取期刊信息
  extract_journal_info <- function(abstract_text) {
    if (is.na(abstract_text) || !nzchar(abstract_text)) {
      return("")
    }

    # 提取 Comments 部分的会议或期刊信息
    if (grepl("Comments:", abstract_text)) {
      comment_match <- regmatches(abstract_text,
        regexpr("Comments:[^\\n]*", abstract_text))
      if (length(comment_match) > 0) {
        journal_info <- sub("Comments:\\s*", "", comment_match[1])
        journal_info <- trimws(strsplit(journal_info, "Subjects:")[[1]][1])
        return(journal_info)
      }
    }

    # 提取 Subjects 部分
    if (grepl("Subjects:", abstract_text)) {
      subject_match <- regmatches(abstract_text,
        regexpr("Subjects:[^\\n]*", abstract_text))
      if (length(subject_match) > 0) {
        subject_info <- sub("Subjects:\\s*", "", subject_match[1])
        subject_info <- trimws(strsplit(subject_info, "Cite as:")[[1]][1])
        return(subject_info)
      }
    }

    return("")
  }

  # 生成 HTML 邮件正文
  html_header <- sprintf('<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 900px; margin: 0 auto; padding: 20px; }
  .header { background: linear-gradient(135deg, #667eea 0%%, #764ba2 100%%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
  .header h1 { margin: 0 0 10px 0; font-size: 28px; }
  .header .stats { font-size: 14px; opacity: 0.95; }
  .paper { background: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; margin-bottom: 20px; border-radius: 5px; }
  .paper-title { color: #2c3e50; font-size: 18px; font-weight: bold; margin-bottom: 10px; }
  .paper-meta { color: #666; font-size: 13px; margin-bottom: 8px; }
  .paper-meta strong { color: #444; }
  .paper-abstract { color: #555; font-size: 14px; line-height: 1.5; margin: 10px 0; padding: 10px; background: white; border-radius: 4px; }
  .paper-links { margin-top: 12px; }
  .paper-links a { display: inline-block; margin-right: 15px; color: #667eea; text-decoration: none; font-size: 13px; }
  .paper-links a:hover { text-decoration: underline; }
  .badge { display: inline-block; padding: 3px 8px; border-radius: 3px; font-size: 11px; font-weight: bold; margin-right: 5px; }
  .badge-success { background: #28a745; color: white; }
  .badge-warning { background: #ffc107; color: #333; }
  .badge-info { background: #17a2b8; color: white; }
  .footer { text-align: center; color: #999; font-size: 12px; margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; }
</style>
</head>
<body>
<div class="header">
  <h1>📚 文献搜索报告</h1>
  <div class="stats">
    <strong>关键词:</strong> %s<br>
    <strong>搜索日期:</strong> %s<br>
    <strong>总论文数:</strong> %d 篇 |
    <strong>PDF下载成功:</strong> %d 篇 |
    <strong>总下载大小:</strong> %.2f MB
  </div>
</div>
',
    keyword,
    format(Sys.Date(), "%Y-%m-%d"),
    nrow(papers_df),
    pdf_success_count,
    total_size_mb
  )

  # 生成每篇文章的 HTML（包含所有文章，不限制数量）
  papers_html <- ""
  for (i in seq_len(nrow(papers_df))) {
    p <- papers_df[i, ]

    # 处理摘要
    abstract_text <- gsub("\\s+", " ", p$abstract)
    abstract_text <- trimws(abstract_text)

    # 提取期刊/会议信息
    journal_info <- extract_journal_info(p$abstract)

    # 移除摘要中的 Comments、Subjects、Cite as 部分，只保留正文
    abstract_clean <- gsub("Comments:.*$", "", abstract_text)
    abstract_clean <- gsub("Subjects:.*$", "", abstract_clean)
    abstract_clean <- trimws(abstract_clean)

    if (nchar(trimws(abstract_clean)) == 0) abstract_clean <- "（无摘要）"

    # 限制摘要长度，避免邮件过大
    if (nchar(abstract_clean) > 800) {
      abstract_clean <- paste0(substr(abstract_clean, 1, 800), "...")
    }

    # 生成文章链接
    paper_url <- get_paper_url(p$source, p$id, p$pdf_url)

    # PDF 状态标记
    pdf_badge <- if (isTRUE(p$pdf_ok)) {
      sprintf('<span class="badge badge-success">✓ PDF已下载 (%.2f MB)</span>', p$pdf_mb)
    } else {
      '<span class="badge badge-warning">✗ PDF未下载</span>'
    }

    # 来源标记
    source_badge <- sprintf('<span class="badge badge-info">%s</span>', toupper(p$source))

    paper_html <- sprintf('
<div class="paper">
  <div class="paper-title">[%d] %s</div>
  <div class="paper-meta">
    <strong>作者:</strong> %s<br>
    <strong>发表日期:</strong> %s | %s %s
  </div>
  %s
  <div class="paper-abstract">%s</div>
  <div class="paper-links">
    %s
    %s
  </div>
</div>
',
      i,
      p$title,
      p$authors,
      p$date,
      source_badge,
      pdf_badge,
      if (nzchar(journal_info)) sprintf('<div class="paper-meta"><strong>期刊/会议:</strong> %s</div>', journal_info) else "",
      abstract_clean,
      if (nzchar(paper_url)) sprintf('<a href="%s" target="_blank">📄 查看文章</a>', paper_url) else "",
      if (!is.na(p$pdf_url) && nzchar(p$pdf_url)) sprintf('<a href="%s" target="_blank">📥 下载PDF</a>', p$pdf_url) else ""
    )

    papers_html <- paste0(papers_html, paper_html)
  }

  # HTML 结尾
  html_footer <- sprintf('
<div class="footer">
  <p>此邮件由文献搜索脚本自动生成并发送 | %s</p>
  <p>共收录 %d 篇文献</p>
</div>
</body>
</html>',
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    nrow(papers_df)
  )

  # 组合完整的 HTML
  email_body <- paste0(html_header, papers_html, html_footer)

  # 写入临时文件
  tmp_body <- tempfile(fileext = ".html")
  writeLines(email_body, tmp_body, useBytes = TRUE)

  # 邮件主题
  subject <- sprintf("文献搜索报告 - %s (%s) - 共%d篇",
                     keyword,
                     format(Sys.Date(), "%Y-%m-%d"),
                     nrow(papers_df))

  # 设置环境变量供 Python 脚本读取
  Sys.setenv(QQ_AUTH_CODE      = CONFIG$SMTP_AUTH_CODE)
  Sys.setenv(RECIPIENT_EMAIL   = CONFIG$RECIPIENT_EMAIL)

  # 调用 Python 脚本发送邮件（第4个参数指定为 html 格式）
  cmd <- sprintf("python3 '%s' '%s' '%s' '%s' 'html' 2>&1",
                 py_script, subject, tmp_body, CONFIG$RECIPIENT_EMAIL)

  log_msg(sprintf("发送邮件到: %s", CONFIG$RECIPIENT_EMAIL))

  tryCatch({
    result <- system(cmd, intern = TRUE)
    unlink(tmp_body)

    if (any(grepl("^SUCCESS$", result))) {
      log_msg("邮件发送成功！", "SUCCESS")
      return(TRUE)
    } else {
      log_msg("邮件发送失败", "ERROR")
      errmsg <- grep("ERROR:", result, value = TRUE)
      if (length(errmsg) > 0) cat("  错误:", errmsg[1], "\n")
      return(FALSE)
    }
  }, error = function(e) {
    unlink(tmp_body)
    log_msg(paste("邮件发送异常:", e$message), "ERROR")
    return(FALSE)
  })
}

# ─── 主程序 ──────────────────────────────────────────────────────────────────

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 1 || args[1] %in% c("-h", "--help", "help")) {
    cat("\n")
    cat("╔══════════════════════════════════════════════════════════════════════╗\n")
    cat("║  📚 学术文献搜索与 PDF 下载工具 v3.0 (Semantic Scholar 首选版)       ║\n")
    cat("╚══════════════════════════════════════════════════════════════════════╝\n\n")

    cat("【基本用法】\n")
    cat("  Rscript download_papersv12.R <关键词> [论文数量] [天数]\n\n")

    cat("【参数说明】\n")
    cat("  <关键词>    : 必需，搜索关键词（多个词用引号包围）\n")
    cat("  [论文数量]  : 可选，每个数据源返回的论文数（默认: 5, 范围: 1-20）\n")
    cat("  [天数]      : 可选，搜索最近多少天的论文（默认: 10, 范围: 1-365）\n\n")

    cat("【使用示例】\n")
    cat("  # 基本搜索（默认 5 篇，最近 10 天）\n")
    cat("  Rscript download_papersv12.R starch\n\n")

    cat("  # 多词关键词（用引号）\n")
    cat("  Rscript download_papersv12.R \"machine learning\"\n\n")

    cat("  # 自定义论文数量（10 篇）\n")
    cat("  Rscript download_papersv12.R \"COVID-19\" 10\n\n")

    cat("  # 完整参数（15 篇，最近 30 天）\n")
    cat("  Rscript download_papersv12.R \"CRISPR gene editing\" 15 30\n\n")

    cat("【数据源】（按优先级）\n")
    cat("  ⭐ Semantic Scholar : AI 驱动的学术图谱（首选，全学科）\n")
    cat("  ✓ Europe PMC        : 生物医学/生命科学（无需 API Key）\n")
    cat("  ✓ arXiv             : 物理/数学/计算机科学（无需 API Key）\n")
    cat("  ✓ OpenAlex          : 全学科开放学术（无需 API Key）\n\n")

    cat("【Semantic Scholar API Key】（可选）\n")
    cat("  无 Key: 100 次请求/5 分钟（适合测试）\n")
    cat("  有 Key: 速率限制更宽松（推荐）\n")
    cat("  申请: https://www.semanticscholar.org/product/api#api-key\n")
    cat("  设置: export S2_API_KEY=\"your_api_key\"\n\n")

    cat("【新特性】\n")
    cat("  ✓ 自动重试：网络失败自动重试 3 次\n")
    cat("  ✓ 超时优化：30 秒超时（针对国内网络）\n")
    cat("  ✓ 引用排序：Semantic Scholar 结果按引用数排序\n")
    cat("  ✓ 语义搜索：更智能的论文匹配算法\n\n")
    cat("  ✓ arXiv         : 物理/数学/计算机科学（无需 API Key）\n")
    cat("  ✓ OpenAlex      : 全学科开放学术（无需 API Key）\n")
    cat("  ✓ Google CSE    : 补充搜索源（需要 API Key，可选）\n\n")

    cat("【PDF 下载策略】（7 个候选源自动切换）\n")
    cat("  1. arXiv 官方 PDF\n")
    cat("  2. 原始 PDF 链接\n")
    cat("  3. Unpaywall（基于 DOI）\n")
    cat("  4. Semantic Scholar\n")
    cat("  5. Europe PMC PDF\n")
    cat("  6. OpenAlex Open Access\n")
    cat("  7. Google CSE（兜底）\n\n")

    cat("【输出目录】\n")
    cat("  output/<关键词>_papers/   - CSV、JSON、报告文件\n")
    cat("  output/<关键词>_pdfs/     - 下载的 PDF 文件\n\n")

    cat("【Google API 配置】（可选，如需使用 Google 搜索源）\n")
    cat("  export GOOGLE_API_KEY=\"your_api_key\"\n")
    cat("  export GOOGLE_CX=\"your_search_engine_id\"\n\n")

    cat("【详细文档】\n")
    cat("  查看脚本开头的详细注释或 download_papersv11_使用指南.md\n\n")

    cat("【快速测试】\n")
    cat("  Rscript download_papersv11.R test 3 7\n\n")

    quit(status = 0)
  }

  kw   <- args[1]
  n    <- min(20, max(1, ifelse(length(args) >= 2, as.integer(args[2]), CONFIG$DEFAULT_COUNT)))
  days <- min(365, max(1, ifelse(length(args) >= 3, as.integer(args[3]), CONFIG$DEFAULT_DAYS)))
  if (is.na(n))    n    <- CONFIG$DEFAULT_COUNT
  if (is.na(days)) days <- CONFIG$DEFAULT_DAYS

  cat("\n╔════════════════════════════════════════════════════════════╗\n")
  cat("║   学术文献搜索与 PDF 下载工具 v3.0 (S2 首选版)             ║\n")
  cat("╚════════════════════════════════════════════════════════════╝\n\n")
  log_msg(sprintf("关键词: \"%s\" | 每源: %d | 最近 %d 天", kw, n, days))

  # 提示 API 配置状态
  if (CONFIG$S2_API_KEY != "") {
    log_msg("Semantic Scholar API Key: 已配置 ✔", "SUCCESS")
  } else {
    log_msg("Semantic Scholar: 无 Key 模式（建议申请 API Key 以提升限额）", "WARN")
  }

  if (CONFIG$GOOGLE_API_KEY != "") {
    log_msg("Google CSE: 已配置 ✔", "SUCCESS")
  } else if ("google" %in% CONFIG$SOURCES) {
    log_msg("Google CSE: 未配置（设置 GOOGLE_API_KEY / GOOGLE_CX 环境变量启用）", "WARN")
  }

  dirs <- create_dirs(kw); cat("\n")

  # ── 搜索 ──
  all_papers <- list()
  for (src in CONFIG$SOURCES) {
    r <- if (src == "semanticscholar") {
      search_semanticscholar(kw, n, days)
    } else if (src == "europepmc") {
      search_europepmc_r(kw, n, days)
    } else if (src == "google") {
      search_google_papers(kw, n, days)
    } else {
      search_papers(src, kw, n, days)
    }

    if (is.null(r) || is.null(r$content) || length(r$content) == 0) {
      Sys.sleep(CONFIG$DELAY_SEC); next
    }
    df        <- r$content
    df$source <- src

    if ("authors" %in% names(df) && is.list(df$authors)) {
      df$authors <- sapply(df$authors, function(a) {
        if (is.null(a)) return(""); paste(unlist(a), collapse = "; ")
      })
    } else if (!"authors" %in% names(df)) {
      df$authors <- ""
    }

    if ("abstract" %in% names(df)) {
      df$abstract <- sapply(seq_len(nrow(df)), function(i) {
        abst <- get_abstract_text(df$abstract[i])
        if (nchar(abst) < 50 && src == "openalex" && "abstract_inverted_index" %in% names(df))
          abst <- reconstruct_openalex_abstract(df$abstract_inverted_index[[i]])
        limit_text_length(abst)
      })
    } else {
      df$abstract <- ""
    }
    if (!"doi"     %in% names(df)) df$doi     <- NA_character_
    if (!"pdf_url" %in% names(df)) df$pdf_url <- NA_character_

    all_papers[[src]] <- df
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  if (length(all_papers) == 0) {
    log_msg(sprintf("最近 %d 天内未找到论文", days), "ERROR"); quit(status = 1)
  }

  all           <- do.call(rbind, all_papers)
  rownames(all) <- NULL
  all           <- all[!duplicated(all$id), ]
  all           <- all[order(all$days_ago), ]
  max_n         <- n * length(CONFIG$SOURCES)
  if (nrow(all) > max_n) all <- all[1:max_n, ]
  if (!"abstract" %in% names(all)) all$abstract <- ""
  if (!"doi"      %in% names(all)) all$doi      <- NA_character_
  log_msg(sprintf("合并后共 %d 篇论文", nrow(all))); cat("\n")

  # ── 补充摘要 ──
  log_msg("获取摘要（包含高档期刊支持：CrossRef + PubMed）...")
  for (i in seq_len(nrow(all))) {
    src        <- all$source[i]
    pid        <- all$id[i]
    title_full <- all$title[i]
    title      <- substr(title_full, 1, 35)
    abst       <- get_abstract_text(all$abstract[i])
    doi_hint   <- if ("doi" %in% names(all) && !is.na(all$doi[i])) all$doi[i] else NULL

    cat(sprintf("  [%d/%d] %s... ", i, nrow(all), title))
    if (nchar(abst) >= 50) { cat(sprintf("✔ 已有 (%d字)\n", nchar(abst))); next }

    # 【优化】即使是 Semantic Scholar，如果没有摘要也尝试补充
    # 高档期刊文章可能在 S2 中只有元数据而无摘要
    if (src == "semanticscholar") {
      cat("⚠ S2无摘要，尝试补充...\n")
      # 尝试详细查询
      abst_s2 <- fetch_abstract_s2_detailed(doi = doi_hint, title = title_full)
      if (nchar(abst_s2) >= 50) {
        all$abstract[i] <- limit_text_length(abst_s2)
        cat(sprintf("    ✔ S2详细查询 (%d字)\n", nchar(abst_s2)))
        Sys.sleep(1); next
      }
      # 如果有 DOI，尝试 CrossRef 和 PubMed
      if (!is.null(doi_hint)) {
        abst_cross <- fetch_abstract_crossref(doi_hint)
        if (nchar(abst_cross) >= 50) {
          all$abstract[i] <- limit_text_length(abst_cross)
          cat(sprintf("    ✔ CrossRef (%d字)\n", nchar(abst_cross)))
          Sys.sleep(1); next
        }
        abst_pubmed <- fetch_abstract_pubmed(doi = doi_hint, title = title_full)
        if (nchar(abst_pubmed) >= 50) {
          all$abstract[i] <- limit_text_length(abst_pubmed)
          cat(sprintf("    ✔ PubMed (%d字)\n", nchar(abst_pubmed)))
          Sys.sleep(1); next
        }
      }
      cat("    ⚠ 所有补充策略均失败\n")
      Sys.sleep(1); next
    }

    # Google 源和其他源的补充流程
    if (src %in% c("arxiv", "openalex", "google", "europepmc")) {
      # 先尝试 MCP
      res2  <- if (src != "google") fetch_content_mcp(src, pid) else NULL
      abst2 <- extract_abstract_from_content_res(res2, src)
      if (nchar(abst2) >= 50) {
        all$abstract[i] <- abst2
        cat(sprintf("✔ MCP (%d字)\n", nchar(abst2)))
        Sys.sleep(1); next
      }

      # 再尝试 fallback（包含高档期刊策略）
      abst3 <- fetch_abstract_fallback(src, pid, doi = doi_hint, title = title_full)
      abst3 <- limit_text_length(abst3)
      if (nchar(abst3) >= 50) {
        all$abstract[i] <- abst3
        cat(sprintf("✔ 多源API (%d字)\n", nchar(abst3)))
      } else {
        cat("⚠ 无摘要\n")
      }
      Sys.sleep(1)
    }
  }
  cat("\n")

  # ── 下载 PDF ──
  log_msg("开始下载 PDF（多源策略: arXiv > 原始 > Unpaywall > S2 > PMC > OpenAlex > Google）...")
  all$pdf_ok      <- FALSE
  all$pdf_file    <- NA_character_
  all$pdf_mb      <- NA_real_
  all$pdf_blocked <- FALSE
  all$pdf_source  <- NA_character_
  all$openalex_pdf  <- NA_character_
  all$europepmc_pdf <- NA_character_

  for (i in seq_len(nrow(all))) {
    p <- all[i, ]
    cat(sprintf("\n[%d/%d] %s\n", i, nrow(all), substr(p$title, 1, 60)))
    cat(sprintf("    来源: %s | 日期: %s (%d天前)\n", p$source, p$date, p$days_ago))
    abst_prev <- get_abstract_text(all$abstract[i])
    cat(sprintf("    摘要: %s\n", if (nchar(abst_prev) > 0) substr(abst_prev, 1, 100) else "(无)"))

    doi_hint <- if (!is.na(p$doi) && p$doi != "") p$doi else NULL
    r <- download_pdf_multi(p$source, p$id, p$pdf_url %||% "", p$title, dirs$pdf, doi_hint)

    all$pdf_ok[i]      <- r$ok
    all$pdf_blocked[i] <- isTRUE(r$blocked)
    if (!is.null(r$links[["openalex_oa"]])) all$openalex_pdf[i]  <- r$links[["openalex_oa"]]
    if (!is.null(r$links[["europepmc"]]))   all$europepmc_pdf[i] <- r$links[["europepmc"]]

    if (r$ok) {
      all$pdf_file[i]   <- r$file
      all$pdf_mb[i]     <- r$mb
      all$pdf_source[i] <- r$source
    } else if (!is.na(p$pdf_url %||% NA) && (p$pdf_url %||% "") != "") {
      cat(sprintf("  💡 手动下载: %s\n", p$pdf_url))
    }
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  # ── 保存结果 ──
  cat("\n")
  ts <- format(Sys.time(), "%Y%m%d_%H%M%S")

  all$abstract <- sapply(all$abstract, clean_text_for_csv)
  all$title    <- sapply(all$title,    clean_text_for_csv)
  all$authors  <- sapply(all$authors,  clean_text_for_csv)

  save_cols <- c("id", "title", "authors", "date", "days_ago",
                 "abstract", "pdf_url", "openalex_pdf", "europepmc_pdf", "source",
                 "pdf_ok", "pdf_blocked", "pdf_file", "pdf_mb", "pdf_source")
  for (col in save_cols) if (!col %in% names(all)) all[[col]] <- NA

  write.csv(all[, save_cols],
            file.path(dirs$base, sprintf("papers_%s.csv", ts)),
            row.names = FALSE, quote = TRUE, fileEncoding = "UTF-8")

  write_json(all, file.path(dirs$base, sprintf("papers_%s.json", ts)), pretty = TRUE)
  log_msg("CSV / JSON 已保存")

  has_abstract <- sum(nchar(all$abstract) > 10)
  log_msg(sprintf("摘要统计: %d / %d 篇有摘要", has_abstract, nrow(all)))

  rp  <- file.path(dirs$base, sprintf("report_%s.txt", ts))
  con <- file(rp, "w", encoding = "UTF-8")
  writeLines(c(
    "最新文献搜索报告 v3.0 (Semantic Scholar 首选版)", "===========================================", "",
    sprintf("关键词: %s", kw),
    sprintf("时间范围: 最近 %d 天 (%s 至 %s)", days, Sys.Date() - days, Sys.Date()),
    sprintf("总论文: %d | 有摘要: %d | PDF下载: %d (%.1f MB)",
            nrow(all), has_abstract, sum(all$pdf_ok), sum(all$pdf_mb, na.rm = TRUE)),
    "", strrep("=", 60), ""
  ), con)

  for (i in seq_len(nrow(all))) {
    p    <- all[i, ]
    abst <- ifelse(nchar(p$abstract) > 0, substr(p$abstract, 1, 300), "无摘要")
    pdf_status <- if (p$pdf_ok) {
      sprintf("✔ %s (%.1f MB, 来源: %s)", p$pdf_file, p$pdf_mb, p$pdf_source %||% "?")
    } else if (isTRUE(p$pdf_blocked)) "被网站保护（请手动下载）"
    else if (!is.na(p$pdf_url %||% NA) && (p$pdf_url %||% "") != "") "所有源均失败"
    else "无PDF链接"

    extra <- ""
    if (!is.na(p$openalex_pdf))  extra <- paste0(extra, sprintf("\n  [OpenAlex PDF]: %s", p$openalex_pdf))
    if (!is.na(p$europepmc_pdf)) extra <- paste0(extra, sprintf("\n  [PMC PDF]: %s", p$europepmc_pdf))

    writeLines(c(
      sprintf("\n[%d] %s", i, p$title),
      sprintf("  来源: %s | 日期: %s | PDF: %s", p$source, p$date, pdf_status),
      extra,
      sprintf("  摘要: %s", abst),
      strrep("-", 50)
    ), con)
  }
  close(con)
  log_msg("报告已保存")

  # ── 发送邮件报告 ──
  cat("\n")
  if (CONFIG$EMAIL_ENABLED) {
    log_msg("准备发送邮件报告...")
    send_email_report(kw, all, sum(all$pdf_ok), sum(all$pdf_mb, na.rm = TRUE))
  }

  cat("\n✅ 完成!\n")
  cat(sprintf("  论文: %d篇 | 有摘要: %d篇 | PDF: %d个\n",
              nrow(all), has_abstract, sum(all$pdf_ok)))
  cat(sprintf("  输出: %s\n\n", dirs$base))
}

unlink(list.files(".", "^\\.temp_.*\\.mjs$", full.names = TRUE))
main()