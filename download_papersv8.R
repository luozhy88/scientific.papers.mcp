#!/usr/bin/env Rscript
# =============================================================================
# 学术文献搜索与 PDF 下载工具（多源 PDF 增强版 2.5）
# 更新说明: 
# v2.5: 搜索源优先 Europe PMC；修复 CSV 输出时的换行符导致乱行问题
# v2.4: 新增 Europe PMC 直接搜索源
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
  DEFAULT_COUNT   = 5,
  DEFAULT_DAYS    = 10,
  OUTPUT_DIR      = "output",
  # 优先搜索 europepmc
  SOURCES         = c("europepmc", "arxiv", "openalex"),
  DELAY_SEC       = 2,
  UNPAYWALL_EMAIL = "479321347@qq.com"
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

# 清理文本，去除换行符，防止 CSV 乱行
clean_text_for_csv <- function(x) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) return("")
  x <- as.character(x)
  # 将换行符、回车符替换为空格
  x <- gsub("[\r\n]+", " ", x)
  # 将连续的多个空格替换为单个空格
  x <- gsub("\\s+", " ", x)
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

# ─── 摘要工具 ───────────────────────────────────────────────────────────────

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

fetch_abstract_fallback <- function(src, paper_id) {
  if (src == "arxiv")    return(fetch_abstract_arxiv(paper_id))
  if (src == "openalex") return(fetch_abstract_openalex(paper_id))
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

  # 2. 原始 (Europe PMC 的 pdf_url 会在这里被优先使用)
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

  # 5. Europe PMC (查询补充)
  candidates[["europepmc"]] <- list(type = "pmc", doi = doi, title = title)

  # 6. OpenAlex OA
  if (src == "openalex") {
    oa_id <- gsub(".*/", "", paper_id)
    candidates[["openalex_oa"]] <- list(type = "openalex_oa", id = oa_id)
  }

  candidates
}

resolve_candidate <- function(cand) {
  if (is.character(cand)) return(cand)
  if (is.list(cand)) {
    switch(cand$type,
      "unpaywall"  = get_unpaywall_pdf_url(cand$doi),
      "s2"         = get_semanticscholar_pdf_url(cand$doi, cand$arxiv_id, cand$title),
      "pmc"        = get_pmc_pdf_url(cand$doi, cand$title),
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

# ─── 实际下载（带 PDF 校验）────────────────────────────────────────────────────

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

  # 用于存储解析过程中发现的有效链接
  found_links <- list()

  for (key in names(candidates)) {
    cand <- candidates[[key]]

    # 解析动态候选
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

    # 记录已解析出的链接（只要是有效 URL）
    if (!is.null(url_try) && grepl("^https?://", url_try)) {
        found_links[[key]] <- url_try
    }

    # HTML 版本处理
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
      # 即使成功，也返回已发现的所有链接
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

# ─── MCP 调用 ───────────────────────────────────────────────────────────────

run_mjs <- function(code, prefix = "R") {
  tmp <- sprintf(".temp_%s_%04d.mjs", format(Sys.time(), "%Y%m%d%H%M%OS3"), sample(1000:9999, 1))
  cat(code, file = tmp)
  out <- tryCatch(system(sprintf("node '%s' 2>&1", tmp), intern = TRUE), error = function(e) character(0))
  unlink(tmp)
  line <- grep(paste0("^", prefix, ":"), out, value = TRUE)[1]
  if (is.na(line)) return(NULL)
  tryCatch(fromJSON(sub(paste0("^", prefix, ":"), "", line)), error = function(e) NULL)
}

# 专门针对 EuropePMC 的 R 语言原生搜索函数
search_europepmc_r <- function(q, n, days) {
  date_from <- format(Sys.Date() - days, "%Y-%m-%d")
  date_to   <- format(Sys.Date(), "%Y-%m-%d")
  # 使用 FIRST_PDATE (首次发布日期) 进行过滤，覆盖面更广
  query_str <- sprintf("%s AND (FIRST_PDATE:[%s TO %s] OR PDATE:[%s TO %s])", 
                       q, date_from, date_to, date_from, date_to)
  
  # 结果按日期倒序
  url <- sprintf("https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%s&format=json&resulttype=core&pageSize=%d&sort=P_PDATE_D desc",
                 utils::URLencode(query_str, reserved = FALSE), n * 2) 
  
  log_msg(sprintf("搜索 EUROPEPMC: '%s' (API)", q))
  
  tryCatch({
    json_txt <- paste(system(sprintf("curl -sL --max-time 20 '%s'", url), intern = TRUE), collapse = "")
    if (nchar(json_txt) < 10) return(NULL)
    
    parsed <- fromJSON(json_txt)
    results <- parsed$resultList$result
    
    if (is.null(results) || length(results) == 0) return(NULL)
    
    # 提取字段
    ids <- character(nrow(results))
    pdf_urls <- character(nrow(results))
    
    # 逐行处理 ID 和 PDF 链接
    for(i in 1:nrow(results)) {
      pmcid <- if("pmcid" %in% names(results)) results$pmcid[i] else NA
      pmid  <- if("id" %in% names(results)) results$id[i] else NA
      
      # 优先使用 PMCID，并构建直接 PDF 链接
      if (!is.null(pmcid) && !is.na(pmcid) && pmcid != "") {
        ids[i] <- pmcid
        # EuropePMC 官方 PDF 直链格式
        pdf_urls[i] <- sprintf("https://europepmc.org/articles/%s?pdf=render", pmcid)
      } else {
        ids[i] <- as.character(pmid)
        pdf_urls[i] <- NA
      }
    }
    
    df <- data.frame(
      id = ids,
      title = results$title,
      authors = results$authorString,
      date = results$firstPublicationDate,
      doi = if("doi" %in% names(results)) results$doi else NA,
      abstract = if("abstractText" %in% names(results)) results$abstractText else "",
      source = "europepmc",
      pdf_url = pdf_urls,
      stringsAsFactors = FALSE
    )
    
    # 过滤无效日期
    df <- df[!is.na(df$date), ]
    
    # 计算天数并过滤
    df$days_ago <- sapply(df$date, days_since)
    df <- df[df$days_ago <= days & df$days_ago >= 0, ]
    
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

  papers      <- res$content
  papers$days_ago <- sapply(papers$date, days_since)
  recent      <- papers[papers$days_ago <= days & papers$days_ago >= 0, ]
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
  for (cand in list(res$content$abstract, res$abstract, res$content$text)) {
    txt <- get_abstract_text(cand)
    if (nchar(txt) >= 50) {
      if (src == "arxiv" && nchar(txt) > 500) {
        ex <- extract_abstract_from_text(txt)
        if (nchar(ex) >= 50) return(ex)
      }
      return(txt)
    }
  }
  if (src == "openalex") {
    inv <- res$content$abstract_inverted_index %||% res$abstract_inverted_index
    if (!is.null(inv)) return(reconstruct_openalex_abstract(inv))
  }
  ""
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
  cat("║   学术文献搜索与 PDF 下载工具（多源 PDF 增强版 2.5）     ║\n")
  cat("╚══════════════════════════════════════════════════════════╝\n\n")
  log_msg(sprintf("关键词: \"%s\" | 每源: %d | 最近 %d 天", kw, n, days))

  dirs <- create_dirs(kw); cat("\n")

  # ── 搜索 ──
  all_papers <- list()
  for (src in CONFIG$SOURCES) {
    # 分流：EuropePMC 使用 R 原生函数，其他使用 MCP JS 工具
    if (src == "europepmc") {
      r <- search_europepmc_r(kw, n, days)
    } else {
      r <- search_papers(src, kw, n, days)
    }

    if (is.null(r) || is.null(r$content) || length(r$content) == 0) {
      Sys.sleep(CONFIG$DELAY_SEC); next
    }
    df <- r$content
    df$source <- src
    
    # 统一作者字段格式
    if ("authors" %in% names(df) && is.list(df$authors)) {
        df$authors <- sapply(df$authors, function(a) {
          if (is.null(a)) return("")
          paste(unlist(a), collapse = "; ")
        })
    } else if (!"authors" %in% names(df)) {
        df$authors <- ""
    }

    if ("abstract" %in% names(df)) {
      df$abstract <- sapply(seq_len(nrow(df)), function(i) {
        abst <- get_abstract_text(df$abstract[i])
        if (nchar(abst) < 50 && src == "openalex" && "abstract_inverted_index" %in% names(df)) {
          abst <- reconstruct_openalex_abstract(df$abstract_inverted_index[[i]])
        }
        abst
      })
    } else {
      df$abstract <- ""
    }
    if (!"doi" %in% names(df)) df$doi <- NA_character_
    if (!"pdf_url" %in% names(df)) df$pdf_url <- NA_character_
    
    all_papers[[src]] <- df
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  if (length(all_papers) == 0) {
    log_msg(sprintf("最近 %d 天内未找到论文", days), "ERROR"); quit(status = 1)
  }

  all          <- do.call(rbind, all_papers)
  rownames(all) <- NULL
  all          <- all[!duplicated(all$id), ]
  all          <- all[order(all$days_ago), ]
  max_n        <- n * length(CONFIG$SOURCES)
  if (nrow(all) > max_n) all <- all[1:max_n, ]
  if (!"abstract" %in% names(all)) all$abstract <- ""
  if (!"doi"      %in% names(all)) all$doi      <- NA_character_
  log_msg(sprintf("合并后共 %d 篇论文", nrow(all))); cat("\n")

  # ── 补充摘要 ──
  log_msg("获取摘要...")
  for (i in seq_len(nrow(all))) {
    src   <- all$source[i]; pid <- all$id[i]
    title <- substr(all$title[i], 1, 35)
    abst  <- get_abstract_text(all$abstract[i])
    cat(sprintf("  [%d/%d] %s... ", i, nrow(all), title))
    if (nchar(abst) >= 50) { cat(sprintf("✓ 已有 (%d字)\n", nchar(abst))); next }
    
    # EuropePMC 已在搜索时尝试获取摘要，这里仅对其他源或失败的进行补充
    if (src != "europepmc") {
        res2  <- fetch_content_mcp(src, pid)
        abst2 <- extract_abstract_from_content_res(res2, src)
        if (nchar(abst2) >= 50) { all$abstract[i] <- abst2; cat(sprintf("✓ MCP (%d字)\n", nchar(abst2))); Sys.sleep(1); next }
        abst3 <- fetch_abstract_fallback(src, pid)
        if (nchar(abst3) >= 50) { all$abstract[i] <- abst3; cat(sprintf("✓ API (%d字)\n", nchar(abst3))) }
        else { cat("⚠ 无摘要\n") }
        Sys.sleep(1)
    } else {
        cat("⚠ 无摘要 (PMC)\n")
    }
  }
  cat("\n")

  # ── 下载 PDF ──
  log_msg("开始下载 PDF（多源策略: arXiv > 原始 > Unpaywall > S2 > PMC > OpenAlex）...")
  all$pdf_ok      <- FALSE
  all$pdf_file    <- NA_character_
  all$pdf_mb      <- NA_real_
  all$pdf_blocked <- FALSE
  all$pdf_source  <- NA_character_
  
  # 新增列：用于存储虽然下载失败但存在的链接
  all$openalex_pdf <- NA_character_
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
    
    # 填充已发现的链接（即使 r$ok 为 FALSE）
    if (!is.null(r$links[["openalex_oa"]])) all$openalex_pdf[i] <- r$links[["openalex_oa"]]
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
  
  # 关键步骤：在写入 CSV 之前清洗所有文本字段
  all$abstract <- sapply(all$abstract, clean_text_for_csv)
  all$title    <- sapply(all$title, clean_text_for_csv)
  all$authors  <- sapply(all$authors, clean_text_for_csv)

  # 将新增的链接列加入保存列表
  save_cols <- c("id", "title", "authors", "date", "days_ago",
                 "abstract", "pdf_url", "openalex_pdf", "europepmc_pdf", "source",
                 "pdf_ok", "pdf_blocked", "pdf_file", "pdf_mb", "pdf_source")
  
  for (col in save_cols) if (!col %in% names(all)) all[[col]] <- NA

  write.csv(all[, save_cols],
            file.path(dirs$base, sprintf("papers_%s.csv", ts)),
            row.names = FALSE, fileEncoding = "UTF-8")
  write_json(all, file.path(dirs$base, sprintf("papers_%s.json", ts)), pretty = TRUE)
  log_msg("CSV / JSON 已保存")

  has_abstract <- sum(nchar(all$abstract) > 10)
  log_msg(sprintf("摘要统计: %d / %d 篇有摘要", has_abstract, nrow(all)))

  rp  <- file.path(dirs$base, sprintf("report_%s.txt", ts))
  con <- file(rp, "w", encoding = "UTF-8")
  writeLines(c(
    "最新文献搜索报告（多源 PDF 增强版 2.5）", "===========================================", "",
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
    
    # 在报告中也显示额外的链接
    extra_links_msg <- ""
    if (!is.na(p$openalex_pdf)) extra_links_msg <- paste0(extra_links_msg, sprintf("\n  [OpenAlex PDF]: %s", p$openalex_pdf))
    if (!is.na(p$europepmc_pdf)) extra_links_msg <- paste0(extra_links_msg, sprintf("\n  [PMC PDF]: %s", p$europepmc_pdf))

    writeLines(c(
      sprintf("\n[%d] %s", i, p$title),
      sprintf("  来源: %s | 日期: %s | PDF: %s", p$source, p$date, pdf_status),
      extra_links_msg,
      sprintf("  摘要: %s", abst),
      strrep("-", 50)
    ), con)
  }
  close(con)
  log_msg("报告已保存")

  cat("\n✅ 完成!\n")
  cat(sprintf("  论文: %d篇 | 有摘要: %d篇 | PDF: %d个\n",
              nrow(all), has_abstract, sum(all$pdf_ok)))
  cat(sprintf("  输出: %s\n\n", dirs$base))
}

unlink(list.files(".", "^\\.temp_.*\\.mjs$", full.names = TRUE))
main()