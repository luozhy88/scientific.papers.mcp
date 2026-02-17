#!/usr/bin/env Rscript
# =============================================================================
# 学术文献搜索与 PDF 下载工具（支持日期范围，自动获取摘要）
# 版本: 2.1 - 优化摘要获取
# =============================================================================

# 设置工作目录
args_cmd <- commandArgs(trailingOnly = FALSE)
script_path <- sub("--file=", "", args_cmd[grep("--file=", args_cmd)])
if (length(script_path) > 0) setwd(dirname(normalizePath(script_path)))

# 加载依赖
for (pkg in c("jsonlite", "dplyr")) {
  if (!require(pkg, quietly = TRUE, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org/", quiet = TRUE)
    library(pkg, character.only = TRUE)
  }
}

CONFIG <- list(
  DEFAULT_COUNT = 5,
  DEFAULT_DAYS  = 10,
  OUTPUT_DIR    = "output",
  SOURCES       = c("arxiv", "openalex"),
  DELAY_SEC     = 2
)

log_msg <- function(msg, type = "INFO") {
  ts  <- format(Sys.time(), "%H:%M:%S")
  sym <- switch(type, "ERROR" = "✖", "SUCCESS" = "✔", "WARN" = "⚠", "📄" = "📄", "ℹ")
  cat(sprintf("[%s] %s %s\n", ts, sym, msg))
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

# ─── 摘要处理工具 ─────────────────────────────────────────────────────────────

# 通用：将各类摘要字段转为字符串
get_abstract_text <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  if (is.character(x)) return(trimws(paste(x, collapse = " ")))
  if (is.list(x))      return(trimws(paste(unlist(x), collapse = " ")))
  trimws(as.character(x))
}

# 【修复1】从 arXiv 全文中多行提取摘要
extract_abstract_from_text <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")

  # 匹配 "Abstract" 到下一个章节标题或文末（多行）
  m <- regmatches(text, regexpr(
    "(?i)Abstract[:\\s]*\\n?([\\s\\S]+?)(?=\\n[A-Z][a-zA-Z ]{2,}\\n|\\n\\d\\.\\s|$)",
    text, perl = TRUE
  ))
  if (length(m) > 0) {
    abst <- sub("(?i)^Abstract[:\\s]*\\n?", "", m[1], perl = TRUE)
    abst <- gsub("\\s+", " ", abst)
    abst <- trimws(abst)
    if (nchar(abst) > 30) return(abst)
  }

  # 备用：单行匹配
  m2 <- regmatches(text, regexpr("(?i)Abstract[:\\s]+(.+)", text, perl = TRUE))
  if (length(m2) > 0) {
    abst <- sub("(?i)Abstract[:\\s]+", "", m2[1], perl = TRUE)
    if (nchar(trimws(abst)) > 30) return(trimws(abst))
  }
  ""
}

# 【修复2】还原 OpenAlex 的倒排索引摘要
reconstruct_openalex_abstract <- function(inv_index) {
  if (is.null(inv_index) || length(inv_index) == 0) return("")
  tryCatch({
    # inv_index 结构: list(word = c(pos1, pos2, ...), ...)
    pairs <- lapply(names(inv_index), function(word) {
      data.frame(word = word, pos = as.integer(unlist(inv_index[[word]])),
                 stringsAsFactors = FALSE)
    })
    df <- do.call(rbind, pairs)
    df <- df[order(df$pos), ]
    paste(df$word, collapse = " ")
  }, error = function(e) "")
}

# ─── 直接 HTTP 获取摘要（兜底，不依赖 MCP fetchContent）─────────────────────

# 从 arXiv API 直接获取摘要
fetch_abstract_arxiv <- function(paper_id) {
  # paper_id 形如 "2401.12345" 或 "http://arxiv.org/abs/2401.12345v1"
  id <- gsub(".*/abs/|v\\d+$", "", paper_id)
  url <- sprintf("https://export.arxiv.org/api/query?id_list=%s", id)
  tryCatch({
    raw <- system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE)
    txt <- paste(raw, collapse = "\n")
    # 提取 <summary> 标签内容
    m <- regmatches(txt, regexpr("(?s)<summary>(.+?)</summary>", txt, perl = TRUE))
    if (length(m) == 0) return("")
    abst <- sub("<summary>", "", sub("</summary>", "", m[1]))
    trimws(gsub("\\s+", " ", abst))
  }, error = function(e) "")
}

# 从 OpenAlex API 直接获取摘要
fetch_abstract_openalex <- function(paper_id) {
  # paper_id 可能是 DOI、OpenAlex W-ID 或 URL
  id <- paper_id
  if (grepl("^https?://", id)) {
    # 可能是 DOI URL 或 OpenAlex URL
    if (grepl("openalex.org/W", id)) {
      id <- gsub(".*/", "", id)  # 提取 Wxxxxxxxxx
    } else if (grepl("doi.org", id)) {
      id <- paste0("doi:", gsub(".*doi.org/", "", id))
    }
  }
  url <- sprintf("https://api.openalex.org/works/%s?select=abstract_inverted_index", id)
  tryCatch({
    raw <- system(sprintf("curl -sL --max-time 15 '%s'", url), intern = TRUE)
    txt <- paste(raw, collapse = "")
    parsed <- fromJSON(txt)
    reconstruct_openalex_abstract(parsed$abstract_inverted_index)
  }, error = function(e) "")
}

# 统一兜底获取摘要
fetch_abstract_fallback <- function(src, paper_id) {
  if (src == "arxiv") {
    return(fetch_abstract_arxiv(paper_id))
  } else if (src == "openalex") {
    return(fetch_abstract_openalex(paper_id))
  }
  ""
}

# ─── MCP 调用 ─────────────────────────────────────────────────────────────────

run_mjs <- function(code, prefix = "R") {
  tmp <- sprintf(".temp_%s_%04d.mjs", format(Sys.time(), "%Y%m%d%H%M%OS3"), sample(1000:9999, 1))
  cat(code, file = tmp)
  out <- tryCatch({
    system(sprintf("node '%s' 2>&1", tmp), intern = TRUE)
  }, error = function(e) character(0))
  unlink(tmp)
  line <- grep(paste0("^", prefix, ":"), out, value = TRUE)[1]
  if (is.na(line)) return(NULL)
  tryCatch(fromJSON(sub(paste0("^", prefix, ":"), "", line)), error = function(e) NULL)
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

  papers <- res$content
  papers$days_ago <- sapply(papers$date, days_since)
  recent <- papers[papers$days_ago <= days & papers$days_ago >= 0, ]
  if (nrow(recent) == 0) {
    log_msg(sprintf("%s: 无最近 %d 天的结果", toupper(src), days), "WARN")
    return(NULL)
  }
  log_msg(sprintf("%s: 找到 %d 篇", toupper(src), nrow(recent)))
  res$content <- recent
  res
}

# 【修复3】fetchContent 结果解析：正确向下钻取嵌套结构
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

# 从 fetchContent 响应中尝试提取摘要（处理多种嵌套格式）
extract_abstract_from_content_res <- function(res, src) {
  if (is.null(res)) return("")

  # 可能的结构：res$content$abstract / res$content$text / res$abstract
  candidates <- list(
    res$content$abstract,
    res$abstract,
    res$content$text
  )

  for (cand in candidates) {
    txt <- get_abstract_text(cand)
    if (nchar(txt) >= 50) {
      # 如果是 arXiv 全文，需二次提取摘要部分
      if (src == "arxiv" && nchar(txt) > 500) {
        extracted <- extract_abstract_from_text(txt)
        if (nchar(extracted) >= 50) return(extracted)
      }
      return(txt)
    }
  }

  # 尝试从 arXiv 全文中提取
  full_text <- get_abstract_text(res$content$text %||% res$text)
  if (src == "arxiv" && nchar(full_text) > 100) {
    return(extract_abstract_from_text(full_text))
  }

  # 尝试还原 OpenAlex 倒排索引
  if (src == "openalex") {
    inv <- res$content$abstract_inverted_index %||% res$abstract_inverted_index
    if (!is.null(inv)) return(reconstruct_openalex_abstract(inv))
  }

  ""
}

# NULL 合并运算符
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ─── PDF 下载 ─────────────────────────────────────────────────────────────────

download_pdf <- function(url, file, dir) {
  if (is.null(url) || url == "") return(list(ok = FALSE, blocked = FALSE))
  url <- sub("/abs/", "/pdf/", url)
  if (grepl("arxiv.org/pdf/", url) && !grepl("\\.pdf$", url)) url <- paste0(url, ".pdf")

  path <- file.path(dir, file)
  cat(sprintf("  📥 %s\n", substr(file, 1, 40)))

  is_protected <- grepl("ncbi.nlm.nih.gov|sciencedirect.com|springer.com|wiley.com", url)

  cmd <- sprintf(
    "curl -sL --max-time 90 -o '%s' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' '%s'",
    path, url
  )

  tryCatch({
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (!file.exists(path)) { cat("  ✗ 下载失败\n"); return(list(ok = FALSE, blocked = FALSE)) }

    sz <- file.size(path)
    if (sz < 100) { unlink(path); cat("  ✗ 文件为空\n"); return(list(ok = FALSE, blocked = FALSE)) }

    con    <- file(path, "rb")
    header <- readBin(con, "raw", n = 4)
    close(con)
    is_pdf <- length(header) == 4 &&
              header[1] == 0x25 && header[2] == 0x50 &&
              header[3] == 0x44 && header[4] == 0x46

    if (is_pdf && sz > 10000) {
      mb <- round(sz / 1024 / 1024, 2)
      cat(sprintf("  ✔ %.2f MB\n", mb))
      return(list(ok = TRUE, mb = mb, blocked = FALSE))
    } else {
      lines <- readLines(path, warn = FALSE, n = 50)
      blocked <- is_protected || any(grepl("cloudflare|challenge|captcha|checking your browser",
                                           lines, ignore.case = TRUE))
      unlink(path)
      if (blocked) {
        cat("  ⚠ 网站保护阻止下载\n")
        return(list(ok = FALSE, blocked = TRUE))
      }
      cat("  ✗ 下载内容非 PDF\n")
      return(list(ok = FALSE, blocked = FALSE))
    }
  }, error = function(e) {
    if (file.exists(path)) unlink(path)
    cat("  ✗ 错误\n")
    list(ok = FALSE, blocked = FALSE)
  })
}

# ─── 主程序 ───────────────────────────────────────────────────────────────────

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) < 1 || args[1] %in% c("-h", "--help", "help")) {
    cat("用法: Rscript download_papers.R <关键词> [数量] [天数]\n")
    cat("示例: Rscript download_papers.R starch 5 10\n")
    quit(status = 0)
  }

  kw   <- args[1]
  n    <- min(20, max(1, ifelse(length(args) >= 2, as.integer(args[2]), CONFIG$DEFAULT_COUNT)))
  days <- min(365, max(1, ifelse(length(args) >= 3, as.integer(args[3]), CONFIG$DEFAULT_DAYS)))
  if (is.na(n))    n    <- CONFIG$DEFAULT_COUNT
  if (is.na(days)) days <- CONFIG$DEFAULT_DAYS

  cat("\n╔══════════════════════════════════════════════════════════╗\n")
  cat("║     学术文献搜索与 PDF 下载工具（摘要优化版 2.1）        ║\n")
  cat("╚══════════════════════════════════════════════════════════╝\n\n")
  log_msg(sprintf("关键词: \"%s\" | 每源: %d | 最近 %d 天", kw, n, days))
  log_msg(sprintf("日期范围: %s 至 %s", format(Sys.Date() - days), format(Sys.Date())))

  dirs <- create_dirs(kw)
  cat("\n")

  # ── 搜索 ──
  all_papers <- list()
  for (src in CONFIG$SOURCES) {
    r <- search_papers(src, kw, n, days)
    if (is.null(r) || is.null(r$content) || length(r$content) == 0) {
      Sys.sleep(CONFIG$DELAY_SEC); next
    }
    df <- r$content
    df$source <- src

    df$authors <- sapply(df$authors, function(a) {
      if (is.null(a)) return("")
      if (is.character(a)) return(paste(a, collapse = "; "))
      paste(unlist(a), collapse = "; ")
    })

    # 【修复2 应用】搜索结果里直接还原 OpenAlex 倒排摘要
    if ("abstract" %in% names(df)) {
      df$abstract <- sapply(seq_len(nrow(df)), function(i) {
        abst <- get_abstract_text(df$abstract[i])
        if (nchar(abst) < 50 && src == "openalex" && "abstract_inverted_index" %in% names(df)) {
          inv <- df$abstract_inverted_index[[i]]
          abst <- reconstruct_openalex_abstract(inv)
        }
        abst
      })
    } else {
      df$abstract <- ""
    }

    all_papers[[src]] <- df
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  if (length(all_papers) == 0) {
    log_msg(sprintf("最近 %d 天内未找到相关论文，建议增加天数", days), "ERROR")
    quit(status = 1)
  }

  # ── 合并去重 ──
  all <- do.call(rbind, all_papers)
  rownames(all) <- NULL
  all <- all[!duplicated(all$id), ]
  all <- all[order(all$days_ago), ]
  max_n <- n * length(CONFIG$SOURCES)
  if (nrow(all) > max_n) all <- all[1:max_n, ]

  if (!"abstract" %in% names(all)) all$abstract <- ""
  log_msg(sprintf("合并后共 %d 篇论文", nrow(all)))
  cat("\n")

  # ── 补充摘要（三层策略）──
  log_msg("获取论文摘要（三层策略: 搜索结果 > MCP fetchContent > 直接 API）...")

  for (i in seq_len(nrow(all))) {
    src   <- all$source[i]
    pid   <- all$id[i]
    title <- substr(all$title[i], 1, 35)
    abst  <- get_abstract_text(all$abstract[i])

    cat(sprintf("  [%d/%d] %s... ", i, nrow(all), title))

    if (nchar(abst) >= 50) {
      cat(sprintf("✓ 搜索结果已有摘要 (%d字)\n", nchar(abst)))
      next
    }

    # 第2层：MCP fetchContent
    res2  <- fetch_content_mcp(src, pid)
    abst2 <- extract_abstract_from_content_res(res2, src)
    if (nchar(abst2) >= 50) {
      all$abstract[i] <- abst2
      cat(sprintf("✓ MCP fetchContent (%d字)\n", nchar(abst2)))
      Sys.sleep(1); next
    }

    # 第3层：直接调用学术 API（最可靠兜底）
    abst3 <- fetch_abstract_fallback(src, pid)
    if (nchar(abst3) >= 50) {
      all$abstract[i] <- abst3
      cat(sprintf("✓ 直接 API (%d字)\n", nchar(abst3)))
    } else {
      cat("⚠ 该论文无可用摘要\n")
    }

    Sys.sleep(1)
  }
  cat("\n")

  # ── 下载 PDF ──
  log_msg("开始下载 PDF...")
  all$pdf_ok      <- FALSE
  all$pdf_file    <- NA_character_
  all$pdf_mb      <- NA_real_
  all$pdf_blocked <- FALSE

  for (i in seq_len(nrow(all))) {
    p <- all[i, ]
    cat(sprintf("\n[%d/%d] %s\n", i, nrow(all), substr(p$title, 1, 55)))
    cat(sprintf("    来源: %s | 日期: %s (%d天前)\n", p$source, p$date, p$days_ago))

    abst_prev <- get_abstract_text(all$abstract[i])
    if (nchar(abst_prev) > 0) {
      cat(sprintf("    摘要: %s\n", substr(abst_prev, 1, 100)))
    } else {
      cat("    摘要: (无)\n")
    }

    if (!is.na(p$pdf_url) && p$pdf_url != "") {
      fn <- sprintf("%s_%s_%s.pdf", p$source, safe_name(p$title, 20), substr(p$id, 1, 15))
      r  <- download_pdf(p$pdf_url, fn, dirs$pdf)
      if (r$ok) {
        all$pdf_ok[i]   <- TRUE
        all$pdf_file[i] <- fn
        all$pdf_mb[i]   <- r$mb
      } else {
        all$pdf_blocked[i] <- isTRUE(r$blocked)
        if (all$pdf_blocked[i]) cat(sprintf("  💡 请手动下载: %s\n", p$pdf_url))
      }
    } else {
      cat("  ⚠ 无 PDF 链接\n")
    }
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  # ── 保存结果 ──
  cat("\n")
  ts <- format(Sys.time(), "%Y%m%d_%H%M%S")

  all$abstract <- sapply(all$abstract, get_abstract_text)

  save_cols <- c("id", "title", "authors", "date", "days_ago",
                 "abstract", "pdf_url", "source",
                 "pdf_ok", "pdf_blocked", "pdf_file", "pdf_mb")
  for (col in save_cols) if (!col %in% names(all)) all[[col]] <- NA

  write.csv(all[, save_cols],
            file.path(dirs$base, sprintf("papers_%s.csv", ts)),
            row.names = FALSE, fileEncoding = "UTF-8")
  write_json(all, file.path(dirs$base, sprintf("papers_%s.json", ts)), pretty = TRUE)
  log_msg("CSV / JSON 已保存")

  has_abstract <- sum(nchar(all$abstract) > 10)
  log_msg(sprintf("摘要统计: %d / %d 篇有摘要", has_abstract, nrow(all)))

  # ── 文本报告 ──
  rp  <- file.path(dirs$base, sprintf("report_%s.txt", ts))
  con <- file(rp, "w", encoding = "UTF-8")
  writeLines(c(
    "最新文献搜索报告", "==================", "",
    sprintf("关键词: %s", kw),
    sprintf("时间范围: 最近 %d 天 (%s 至 %s)", days, Sys.Date() - days, Sys.Date()),
    sprintf("总论文: %d | 有摘要: %d | PDF下载: %d (%.1f MB)",
            nrow(all), has_abstract,
            sum(all$pdf_ok), sum(all$pdf_mb, na.rm = TRUE)),
    "", strrep("=", 60), ""
  ), con)

  for (i in seq_len(nrow(all))) {
    p    <- all[i, ]
    abst <- ifelse(nchar(p$abstract) > 0, substr(p$abstract, 1, 300), "无摘要")
    pdf_status <- if (p$pdf_ok) {
      sprintf("已下载: %s (%.1f MB)", p$pdf_file, p$pdf_mb)
    } else if (isTRUE(p$pdf_blocked)) {
      "被保护阻止（请浏览器手动下载）"
    } else if (!is.na(p$pdf_url) && p$pdf_url != "") {
      "下载失败"
    } else {
      "无PDF链接"
    }
    writeLines(c(
      sprintf("\n[%d] %s", i, p$title),
      sprintf("  来源: %s | 日期: %s | PDF: %s", p$source, p$date, pdf_status),
      sprintf("  摘要: %s", abst),
      strrep("-", 50)
    ), con)
  }
  close(con)
  log_msg("文本报告已保存")

  # ── 完成 ──
  cat("\n✅ 完成!\n")
  cat(sprintf("  论文: %d篇 | 有摘要: %d篇 | PDF: %d个\n",
              nrow(all), has_abstract, sum(all$pdf_ok)))
  cat(sprintf("  输出: %s\n\n", dirs$base))
}

unlink(list.files(".", "^\\.temp_.*\\.mjs$", full.names = TRUE))
main()