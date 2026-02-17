#!/usr/bin/env Rscript
# =============================================================================
# 学术文献搜索与 PDF 下载工具 v2.3
# 新增: HTML 全文抓取 → headless Chrome/wkhtmltopdf 转 PDF
#       多源 PDF 候选（arXiv / Unpaywall / S2 / PMC / OpenAlex OA）
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
  SOURCES         = c("arxiv", "openalex"),
  DELAY_SEC       = 2,
  UNPAYWALL_EMAIL = "your@email.com"   # ← 改成你的邮箱
)

`%||%` <- function(a, b) {
  if (!is.null(a) && length(a) > 0 && !is.na(a[1]) && nchar(as.character(a[1])) > 0) a else b
}

log_msg <- function(msg, type = "INFO") {
  sym <- switch(type, "ERROR" = "✖", "SUCCESS" = "✔", "WARN" = "⚠", "ℹ")
  cat(sprintf("[%s] %s %s\n", format(Sys.time(), "%H:%M:%S"), sym, msg))
}

safe_name <- function(text, max = 25) {
  text <- iconv(as.character(text), to = "ASCII//TRANSLIT", sub = "_")
  text <- tolower(gsub("[\\s_]+", "_", gsub("[^a-zA-Z0-9\\s_-]", "_", text)))
  text <- gsub("^_+|_+$", "", text)
  if (nchar(text) > max) text <- substr(text, 1, max)
  if (text == "") "paper" else text
}

create_dirs <- function(kw) {
  name <- safe_name(kw)
  base <- file.path(CONFIG$OUTPUT_DIR, paste0(name, "_papers"))
  pdf  <- file.path(CONFIG$OUTPUT_DIR, paste0(name, "_pdfs"))
  if (!dir.exists(base)) dir.create(base, recursive = TRUE)
  if (!dir.exists(pdf))  dir.create(pdf,  recursive = TRUE)
  list(base = base, pdf = pdf, name = name)
}

days_since <- function(d) {
  if (is.na(d) || d == "") return(Inf)
  tryCatch(as.numeric(Sys.Date() - as.Date(d)), error = function(e) Inf)
}

curl_get <- function(url, max_time = 20) {
  tryCatch(
    paste(system(sprintf(
      "curl -sL --max-time %d -H 'User-Agent: Mozilla/5.0' '%s'",
      max_time, url), intern = TRUE), collapse = "\n"),
    error = function(e) ""
  )
}

# ─── 摘要工具 ────────────────────────────────────────────────────────────────

get_abstract_text <- function(x) {
  if (is.null(x) || length(x) == 0) return("")
  if (is.character(x)) return(trimws(paste(x, collapse = " ")))
  if (is.list(x))      return(trimws(paste(unlist(x), collapse = " ")))
  trimws(as.character(x))
}

reconstruct_openalex_abstract <- function(inv) {
  if (is.null(inv) || length(inv) == 0) return("")
  tryCatch({
    pairs <- lapply(names(inv), function(w)
      data.frame(word = w, pos = as.integer(unlist(inv[[w]])), stringsAsFactors = FALSE))
    df <- do.call(rbind, pairs)
    paste(df[order(df$pos), "word"], collapse = " ")
  }, error = function(e) "")
}

extract_abstract_from_text <- function(text) {
  if (is.null(text) || nchar(text) == 0) return("")
  m <- regmatches(text, regexpr(
    "(?i)Abstract[:\\s]*\\n?([\\s\\S]+?)(?=\\n[A-Z][a-zA-Z ]{2,}\\n|\\n\\d\\.\\s|$)",
    text, perl = TRUE))
  if (length(m) > 0) {
    a <- trimws(gsub("\\s+", " ", sub("(?i)^Abstract[:\\s]*\\n?", "", m[1], perl = TRUE)))
    if (nchar(a) > 30) return(a)
  }
  ""
}

fetch_abstract_arxiv <- function(pid) {
  id  <- gsub(".*/abs/|v\\d+$", "", pid)
  txt <- curl_get(sprintf("https://export.arxiv.org/api/query?id_list=%s", id))
  m   <- regmatches(txt, regexpr("(?s)<summary>(.+?)</summary>", txt, perl = TRUE))
  if (length(m) == 0) return("")
  trimws(gsub("\\s+", " ", gsub("</?summary>", "", m[1])))
}

fetch_abstract_openalex <- function(pid) {
  id <- pid
  if (grepl("openalex.org/W", id)) id <- gsub(".*/", "", id)
  else if (grepl("doi.org", id))   id <- paste0("doi:", gsub(".*doi.org/", "", id))
  tryCatch({
    p <- fromJSON(curl_get(sprintf(
      "https://api.openalex.org/works/%s?select=abstract_inverted_index", id)))
    reconstruct_openalex_abstract(p$abstract_inverted_index)
  }, error = function(e) "")
}

fetch_abstract_fallback <- function(src, pid) {
  if (src == "arxiv")    return(fetch_abstract_arxiv(pid))
  if (src == "openalex") return(fetch_abstract_openalex(pid))
  ""
}

# ─── HTML 转 PDF ──────────────────────────────────────────────────────────────

# 检测可用的 HTML→PDF 工具，返回第一个可用的
detect_html2pdf_tool <- function() {
  tools <- list(
    chromium = list(
      bins = c("chromium", "chromium-browser", "google-chrome", "google-chrome-stable",
                "/usr/bin/chromium-browser", "/usr/bin/google-chrome",
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
      type = "chrome"
    ),
    wkhtmltopdf = list(
      bins = c("wkhtmltopdf", "/usr/local/bin/wkhtmltopdf", "/usr/bin/wkhtmltopdf"),
      type = "wkhtmltopdf"
    ),
    pandoc = list(
      bins = c("pandoc"),
      type = "pandoc"
    )
  )
  for (tool in tools) {
    for (bin in tool$bins) {
      found <- tryCatch(
        nchar(system(sprintf("which '%s' 2>/dev/null || command -v '%s' 2>/dev/null",
                             bin, bin), intern = TRUE)[1]) > 0,
        error = function(e) FALSE
      )
      if (isTRUE(found)) return(list(bin = bin, type = tool$type))
    }
  }
  NULL
}

HTML2PDF_TOOL <- NULL  # 懒加载，首次使用时检测

get_html2pdf_tool <- function() {
  if (is.null(HTML2PDF_TOOL)) {
    t <- detect_html2pdf_tool()
    if (!is.null(t)) {
      log_msg(sprintf("HTML→PDF 工具: %s (%s)", t$bin, t$type))
    } else {
      log_msg("未检测到 HTML→PDF 工具（chromium/wkhtmltopdf/pandoc），将保存 HTML 文件", "WARN")
    }
    HTML2PDF_TOOL <<- t %||% list(bin = NULL, type = "none")
  }
  HTML2PDF_TOOL
}

# 将 URL 指向的 HTML 页面转换为 PDF，返回 list(ok, mb, method)
html_url_to_pdf <- function(url, out_path) {
  tool <- get_html2pdf_tool()

  if (tool$type == "chrome") {
    cmd <- sprintf(
      "'%s' --headless=new --disable-gpu --no-sandbox \
       --disable-extensions --disable-sync --disable-background-networking \
       --disable-default-apps --disable-translate --no-first-run \
       --disable-gcm --disable-push-messaging \
       --metrics-recording-only \
       --timeout=30000 \
       --print-to-pdf='%s' \
       --print-to-pdf-no-header \
       --run-all-compositor-stages-before-draw \
       '%s' 2>/dev/null",
      tool$bin, out_path, url)
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE, timeout = 45)

  } else if (tool$type == "wkhtmltopdf") {
    cmd <- sprintf(
      "wkhtmltopdf --quiet --javascript-delay 3000 --no-stop-slow-scripts \
       --enable-javascript '%s' '%s' 2>/dev/null",
      url, out_path)
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)

  } else if (tool$type == "pandoc") {
    # pandoc 需要先 curl 下 HTML 再转换
    html_tmp <- paste0(out_path, ".html")
    system(sprintf("curl -sL --max-time 60 -o '%s' '%s'", html_tmp, url),
           ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (file.exists(html_tmp)) {
      system(sprintf("pandoc '%s' -o '%s' 2>/dev/null", html_tmp, out_path),
             ignore.stdout = TRUE, ignore.stderr = TRUE)
      unlink(html_tmp)
    }

  } else {
    return(list(ok = FALSE, mb = 0, method = "none"))
  }

  if (file.exists(out_path) && file.size(out_path) > 10000) {
    return(list(ok = TRUE, mb = round(file.size(out_path) / 1048576, 2), method = tool$type))
  }
  if (file.exists(out_path)) unlink(out_path)
  list(ok = FALSE, mb = 0, method = tool$type)
}

# 将 HTML 页面保存为 .html 文件（转 PDF 失败时的保底）
save_html_file <- function(url, out_path_html) {
  cmd <- sprintf(
    "curl -sL --max-time 60 -H 'User-Agent: Mozilla/5.0' -o '%s' '%s'",
    out_path_html, url)
  system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
  if (file.exists(out_path_html) && file.size(out_path_html) > 5000) {
    sz <- round(file.size(out_path_html) / 1024, 1)
    cat(sprintf("    💾 HTML 已保存 %.1f KB\n", sz))
    return(list(ok = TRUE, kb = sz))
  }
  list(ok = FALSE)
}

# ─── ID / DOI 提取 ───────────────────────────────────────────────────────────

extract_arxiv_id <- function(x) {
  if (is.null(x) || is.na(x) || x == "") return(NULL)
  m <- regmatches(x, regexpr("(\\d{4}\\.\\d{4,5})(v\\d+)?", x, perl = TRUE))
  if (length(m) > 0) return(gsub("v\\d+$", "", m[1]))
  NULL
}

extract_doi <- function(...) {
  for (x in list(...)) {
    if (is.null(x) || is.na(x) || x == "") next
    m <- regmatches(x, regexpr("10\\.\\d{4,}/[^\\s\"'<>\\)]+", x, perl = TRUE))
    if (length(m) > 0) return(gsub("[.,;]$", "", m[1]))
  }
  NULL
}

# ─── 多源 PDF/HTML URL 候选 ──────────────────────────────────────────────────

get_unpaywall_urls <- function(doi, email = CONFIG$UNPAYWALL_EMAIL) {
  if (is.null(doi)) return(list())
  tryCatch({
    p <- fromJSON(curl_get(sprintf(
      "https://api.unpaywall.org/v2/%s?email=%s",
      utils::URLencode(doi, reserved = TRUE), email)))

    urls <- list()
    # best_oa_location 优先
    best <- p$best_oa_location
    if (!is.null(best$url_for_pdf) && grepl("^https?://", best$url_for_pdf %||% ""))
      urls[["unpaywall_best_pdf"]] <- list(url = best$url_for_pdf, type = "pdf")
    if (!is.null(best$url) && grepl("^https?://", best$url %||% ""))
      urls[["unpaywall_best_url"]] <- list(url = best$url, type = "html")

    # 遍历所有 oa_locations
    locs <- p$oa_locations
    if (!is.null(locs) && is.data.frame(locs)) {
      for (i in seq_len(min(nrow(locs), 5))) {
        u_pdf  <- locs$url_for_pdf[i] %||% ""
        u_land <- locs$url[i] %||% ""
        key    <- sprintf("unpaywall_loc%d", i)
        if (grepl("^https?://", u_pdf))
          urls[[paste0(key, "_pdf")]] <- list(url = u_pdf, type = "pdf")
        else if (grepl("^https?://", u_land))
          urls[[paste0(key, "_html")]] <- list(url = u_land, type = "html")
      }
    }
    urls
  }, error = function(e) list())
}

get_s2_pdf_url <- function(doi = NULL, arxiv_id = NULL, title = NULL) {
  qid <- if (!is.null(arxiv_id)) paste0("ARXIV:", arxiv_id)
         else if (!is.null(doi)) paste0("DOI:", utils::URLencode(doi, reserved = TRUE))
         else NULL
  if (!is.null(qid)) {
    tryCatch({
      p <- fromJSON(curl_get(sprintf(
        "https://api.semanticscholar.org/graph/v1/paper/%s?fields=openAccessPdf,externalIds", qid)))
      url <- p$openAccessPdf$url %||% NULL
      if (!is.null(url) && grepl("^https?://", url)) return(url)
    }, error = function(e) NULL)
  }
  if (!is.null(title) && nchar(title) > 10) {
    tryCatch({
      q <- utils::URLencode(substr(title, 1, 80), reserved = TRUE)
      p <- fromJSON(curl_get(sprintf(
        "https://api.semanticscholar.org/graph/v1/paper/search?query=%s&fields=openAccessPdf&limit=1", q)))
      if (!is.null(p$data) && length(p$data) > 0)
        return(p$data[[1]]$openAccessPdf$url %||% NULL)
    }, error = function(e) NULL)
  }
  NULL
}

get_pmc_urls <- function(doi = NULL, title = NULL) {
  query <- if (!is.null(doi)) sprintf("DOI:\"%s\"", doi)
           else if (!is.null(title)) sprintf("TITLE:\"%s\"", substr(title, 1, 60))
           else return(list())
  tryCatch({
    p  <- fromJSON(curl_get(sprintf(
      "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=%s&format=json&resulttype=core&pageSize=1",
      utils::URLencode(query, reserved = TRUE))))
    rs <- p$resultList$result
    if (is.null(rs) || length(rs) == 0) return(list())

    urls  <- list()
    pmcid <- rs[[1]]$pmcid %||% NULL
    if (!is.null(pmcid) && grepl("^PMC", pmcid)) {
      id_num <- gsub("PMC", "", pmcid)
      urls[["pmc_pdf"]]  <- list(
        url  = sprintf("https://www.ncbi.nlm.nih.gov/pmc/articles/PMC%s/pdf/", id_num),
        type = "pdf")
      urls[["pmc_html"]] <- list(
        url  = sprintf("https://www.ncbi.nlm.nih.gov/pmc/articles/PMC%s/", id_num),
        type = "html")
    }
    urls
  }, error = function(e) list())
}

get_openalex_oa_url <- function(pid) {
  id <- gsub(".*/", "", pid)
  tryCatch({
    p   <- fromJSON(curl_get(sprintf(
      "https://api.openalex.org/works/%s?select=open_access,primary_location", id)))
    pdf <- p$open_access$oa_url %||%
           p$primary_location$pdf_url %||% NULL
    if (!is.null(pdf) && grepl("^https?://", pdf)) return(pdf)
    NULL
  }, error = function(e) NULL)
}

# 构建完整候选列表（按优先级排列）
# 每个候选: list(url=..., type="pdf"|"html", label=...)
build_all_candidates <- function(src, paper_id, pdf_url, title, doi_hint = NULL) {
  cands  <- list()
  arxid  <- extract_arxiv_id(paper_id) %||% extract_arxiv_id(pdf_url %||% "")
  doi    <- extract_doi(doi_hint, paper_id, pdf_url %||% "")

  # ── 1. arXiv 直链（成功率最高）
  if (!is.null(arxid)) {
    cands[["arxiv_pdf"]] <- list(
      url   = sprintf("https://arxiv.org/pdf/%s.pdf", arxid),
      type  = "pdf", label = "arXiv PDF")
    cands[["arxiv_html"]] <- list(
      url   = sprintf("https://ar5iv.labs.arxiv.org/html/%s", arxid),
      type  = "html", label = "ar5iv HTML")
  }

  # ── 2. 原始 pdf_url
  if (!is.null(pdf_url) && !is.na(pdf_url) && pdf_url != "") {
    u <- sub("arxiv\\.org/abs/", "arxiv.org/pdf/", pdf_url)
    if (grepl("arxiv.org/pdf/", u) && !grepl("\\.pdf$", u)) u <- paste0(u, ".pdf")
    cands[["original"]] <- list(url = u, type = "pdf", label = "原始链接")
  }

  # ── 3. Unpaywall（多个 URL，含 PDF 和 HTML）
  cat("    🔍 Unpaywall 查询...\n")
  uw <- get_unpaywall_urls(doi)
  for (k in names(uw)) cands[[k]] <- c(uw[[k]], list(label = paste("Unpaywall", k)))
  if (length(uw) > 0) Sys.sleep(0.5)

  # ── 4. Semantic Scholar
  cat("    🔍 Semantic Scholar 查询...\n")
  s2url <- get_s2_pdf_url(doi, arxid, title)
  if (!is.null(s2url)) {
    type <- if (grepl("\\.pdf(\\?|$)", s2url, ignore.case = TRUE)) "pdf" else "html"
    cands[["s2"]] <- list(url = s2url, type = type, label = "Semantic Scholar")
  }
  Sys.sleep(0.3)

  # ── 5. Europe PMC / PubMed Central
  cat("    🔍 Europe PMC 查询...\n")
  pmc <- get_pmc_urls(doi, title)
  for (k in names(pmc)) cands[[k]] <- c(pmc[[k]], list(label = paste("PMC", k)))
  if (length(pmc) > 0) Sys.sleep(0.3)

  # ── 6. OpenAlex OA URL
  if (src == "openalex") {
    cat("    🔍 OpenAlex OA 查询...\n")
    oaurl <- get_openalex_oa_url(paper_id)
    if (!is.null(oaurl)) {
      type <- if (grepl("\\.pdf(\\?|$)", oaurl, ignore.case = TRUE)) "pdf" else "html"
      cands[["openalex_oa"]] <- list(url = oaurl, type = type, label = "OpenAlex OA")
    }
  }

  cands
}

# ─── 实际下载：PDF 校验 ───────────────────────────────────────────────────────

try_download_pdf <- function(url, path) {
  cmd <- sprintf(
    "curl -sL --max-time 90 -o '%s' \
     -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) Chrome/120.0' \
     -H 'Accept: application/pdf,*/*' '%s'",
    path, url)
  tryCatch({
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    if (!file.exists(path) || file.size(path) < 500) {
      if (file.exists(path)) unlink(path)
      return(list(ok = FALSE, blocked = FALSE))
    }
    con    <- file(path, "rb")
    header <- readBin(con, "raw", n = 4); close(con)
    is_pdf <- length(header) == 4 &&
              header[1] == 0x25 && header[2] == 0x50 &&
              header[3] == 0x44 && header[4] == 0x46
    if (is_pdf && file.size(path) > 10000)
      return(list(ok = TRUE, mb = round(file.size(path) / 1048576, 2)))
    lines   <- readLines(path, warn = FALSE, n = 30)
    blocked <- any(grepl("cloudflare|captcha|challenge|checking your browser",
                         lines, ignore.case = TRUE))
    unlink(path)
    list(ok = FALSE, blocked = blocked)
  }, error = function(e) { if (file.exists(path)) unlink(path); list(ok = FALSE, blocked = FALSE) })
}

# ─── 主下载调度 ───────────────────────────────────────────────────────────────

download_paper <- function(src, paper_id, pdf_url, title, dirs, doi_hint = NULL) {
  base  <- sprintf("%s_%s_%s",
                   src,
                   safe_name(title, 20),
                   substr(gsub("[^a-z0-9]", "", tolower(paper_id)), 1, 12))
  cands <- build_all_candidates(src, paper_id, pdf_url, title, doi_hint)

  result <- list(ok = FALSE, blocked = FALSE, file = NA_character_,
                 mb = NA_real_, method = NA_character_, label = NA_character_)

  for (key in names(cands)) {
    cand <- cands[[key]]
    url  <- cand$url; type <- cand$type; label <- cand$label

    cat(sprintf("    ⬇ [%s] %s\n", label, substr(url, 1, 72)))

    if (type == "pdf") {
      # ── 尝试直接 PDF 下载
      path <- file.path(dirs$pdf, paste0(base, ".pdf"))
      r    <- try_download_pdf(url, path)
      if (r$ok) {
        cat(sprintf("    ✔ PDF 下载成功 %.2f MB\n", r$mb))
        return(list(ok = TRUE, blocked = FALSE, file = paste0(base, ".pdf"),
                    mb = r$mb, method = "pdf_direct", label = label))
      }
      if (r$blocked) { cat(sprintf("    ⚠ [%s] 被网站保护\n", label)); Sys.sleep(0.5); next }
      # PDF 下载失败，尝试用 HTML→PDF 工具打开同一 URL
      cat(sprintf("    🔄 [%s] PDF 直链失败，尝试 headless 渲染...\n", label))
      path2 <- file.path(dirs$pdf, paste0(base, "_rendered.pdf"))
      r2    <- html_url_to_pdf(url, path2)
      if (r2$ok) {
        cat(sprintf("    ✔ headless 渲染成功 %.2f MB (%s)\n", r2$mb, r2$method))
        return(list(ok = TRUE, blocked = FALSE, file = paste0(base, "_rendered.pdf"),
                    mb = r2$mb, method = paste0("render_", r2$method), label = label))
      }

    } else {  # type == "html"
      # ── 直接用工具将 HTML 页面转 PDF
      path <- file.path(dirs$pdf, paste0(base, "_html.pdf"))
      r    <- html_url_to_pdf(url, path)
      if (r$ok) {
        cat(sprintf("    ✔ HTML→PDF 成功 %.2f MB (%s)\n", r$mb, r$method))
        return(list(ok = TRUE, blocked = FALSE, file = paste0(base, "_html.pdf"),
                    mb = r$mb, method = paste0("html2pdf_", r$method), label = label))
      }
      # 工具转换失败：保存原始 HTML
      tool <- get_html2pdf_tool()
      if (tool$type == "none") {
        html_path <- file.path(dirs$pdf, paste0(base, ".html"))
        rh <- save_html_file(url, html_path)
        if (rh$ok) {
          return(list(ok = TRUE, blocked = FALSE, file = paste0(base, ".html"),
                      mb = round(rh$kb / 1024, 3), method = "html_saved", label = label))
        }
      }
    }

    cat(sprintf("    ✗ [%s] 失败，尝试下一源\n", label))
    Sys.sleep(0.5)
  }

  result
}

# ─── MCP 调用 ────────────────────────────────────────────────────────────────

run_mjs <- function(code, prefix = "R") {
  tmp <- sprintf(".temp_%s_%04d.mjs",
                 format(Sys.time(), "%Y%m%d%H%M%OS3"), sample(1000:9999, 1))
  cat(code, file = tmp)
  out <- tryCatch(system(sprintf("node '%s' 2>&1", tmp), intern = TRUE),
                  error = function(e) character(0))
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
  papers          <- res$content
  papers$days_ago <- sapply(papers$date, days_since)
  recent          <- papers[papers$days_ago <= days & papers$days_ago >= 0, ]
  if (nrow(recent) == 0) { log_msg(sprintf("%s: 无结果", toupper(src)), "WARN"); return(NULL) }
  log_msg(sprintf("%s: 找到 %d 篇", toupper(src), nrow(recent)))
  res$content <- recent; res
}

fetch_content_mcp <- function(src, pid) {
  code <- sprintf(
    "import { fetchContent } from './dist/tools/fetch-content.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rl = new RateLimiter();
try {
  const r = await fetchContent({source:'%s',id:'%s'}, rl);
  console.log('R:'+JSON.stringify(r));
} catch(e) { console.log('E:'+e.message); }
", src, pid)
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
    cat("用法: Rscript download_papers.R <关键词> [数量] [天数]\n"); quit(status = 0)
  }

  kw   <- args[1]
  n    <- min(20, max(1, ifelse(length(args) >= 2, as.integer(args[2]), CONFIG$DEFAULT_COUNT)))
  days <- min(365, max(1, ifelse(length(args) >= 3, as.integer(args[3]), CONFIG$DEFAULT_DAYS)))
  if (is.na(n))    n    <- CONFIG$DEFAULT_COUNT
  if (is.na(days)) days <- CONFIG$DEFAULT_DAYS

  cat("\n╔══════════════════════════════════════════════════════════╗\n")
  cat("║   学术文献搜索与 PDF 下载工具（HTML 全文增强版 2.3）     ║\n")
  cat("╚══════════════════════════════════════════════════════════╝\n\n")
  log_msg(sprintf("关键词: \"%s\" | 每源: %d | 最近 %d 天", kw, n, days))

  # 预热：检测 HTML→PDF 工具
  get_html2pdf_tool()
  dirs <- create_dirs(kw); cat("\n")

  # ── 搜索 ──
  all_papers <- list()
  for (src in CONFIG$SOURCES) {
    r <- search_papers(src, kw, n, days)
    if (is.null(r) || is.null(r$content) || length(r$content) == 0) {
      Sys.sleep(CONFIG$DELAY_SEC); next
    }
    df <- r$content
    df$source  <- src
    df$authors <- sapply(df$authors, function(a) paste(unlist(a), collapse = "; "))
    if ("abstract" %in% names(df)) {
      df$abstract <- sapply(seq_len(nrow(df)), function(i) {
        a <- get_abstract_text(df$abstract[i])
        if (nchar(a) < 50 && src == "openalex" && "abstract_inverted_index" %in% names(df))
          a <- reconstruct_openalex_abstract(df$abstract_inverted_index[[i]])
        a
      })
    } else { df$abstract <- "" }
    if (!"doi" %in% names(df)) df$doi <- NA_character_
    all_papers[[src]] <- df
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  if (length(all_papers) == 0) { log_msg("未找到论文", "ERROR"); quit(status = 1) }

  all           <- do.call(rbind, all_papers)
  rownames(all) <- NULL
  all           <- all[!duplicated(all$id), ]
  all           <- all[order(all$days_ago), ]
  max_n         <- n * length(CONFIG$SOURCES)
  if (nrow(all) > max_n) all <- all[1:max_n, ]
  if (!"abstract" %in% names(all)) all$abstract <- ""
  if (!"doi"      %in% names(all)) all$doi      <- NA_character_
  log_msg(sprintf("合并后共 %d 篇", nrow(all))); cat("\n")

  # ── 补充摘要（三层）──
  log_msg("获取摘要...")
  for (i in seq_len(nrow(all))) {
    src <- all$source[i]; pid <- all$id[i]
    cat(sprintf("  [%d/%d] %s... ", i, nrow(all), substr(all$title[i], 1, 35)))
    if (nchar(get_abstract_text(all$abstract[i])) >= 50) { cat("✓ 已有\n"); next }
    res2 <- fetch_content_mcp(src, pid)
    a2   <- extract_abstract_from_content_res(res2, src)
    if (nchar(a2) >= 50) { all$abstract[i] <- a2; cat("✓ MCP\n"); Sys.sleep(1); next }
    a3 <- fetch_abstract_fallback(src, pid)
    if (nchar(a3) >= 50) { all$abstract[i] <- a3; cat("✓ API\n") } else cat("⚠ 无\n")
    Sys.sleep(1)
  }
  cat("\n")

  # ── 下载（PDF / HTML→PDF / HTML 保存）──
  log_msg("开始获取全文（PDF 直链 > Unpaywall > S2 > PMC > HTML 转换 > HTML 保存）...")
  all$pdf_ok     <- FALSE
  all$pdf_file   <- NA_character_
  all$pdf_mb     <- NA_real_
  all$pdf_method <- NA_character_
  all$pdf_label  <- NA_character_

  for (i in seq_len(nrow(all))) {
    p <- all[i, ]
    cat(sprintf("\n[%d/%d] %s\n    来源: %s | 日期: %s\n",
                i, nrow(all), substr(p$title, 1, 60), p$source, p$date))
    abst <- get_abstract_text(all$abstract[i])
    cat(sprintf("    摘要: %s\n", if (nchar(abst) > 0) substr(abst, 1, 100) else "(无)"))

    doi_hint <- if (!is.na(p$doi %||% NA) && (p$doi %||% "") != "") p$doi else NULL
    r <- download_paper(p$source, p$id, p$pdf_url %||% "", p$title, dirs, doi_hint)

    all$pdf_ok[i]     <- r$ok
    all$pdf_file[i]   <- r$file
    all$pdf_mb[i]     <- r$mb
    all$pdf_method[i] <- r$method
    all$pdf_label[i]  <- r$label

    if (!r$ok && !is.na(p$pdf_url %||% NA) && (p$pdf_url %||% "") != "") {
      cat(sprintf("  💡 手动下载: %s\n", p$pdf_url))
    }
    Sys.sleep(CONFIG$DELAY_SEC)
  }

  # ── 保存结果 ──
  cat("\n")
  ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
  all$abstract <- sapply(all$abstract, get_abstract_text)

  save_cols <- c("id","title","authors","date","days_ago","abstract","pdf_url","source",
                 "pdf_ok","pdf_file","pdf_mb","pdf_method","pdf_label")
  for (col in save_cols) if (!col %in% names(all)) all[[col]] <- NA

  write.csv(all[, save_cols],
            file.path(dirs$base, sprintf("papers_%s.csv", ts)),
            row.names = FALSE, fileEncoding = "UTF-8")
  write_json(all, file.path(dirs$base, sprintf("papers_%s.json", ts)), pretty = TRUE)

  has_abst <- sum(nchar(all$abstract) > 10)
  n_ok     <- sum(all$pdf_ok)
  tot_mb   <- round(sum(all$pdf_mb, na.rm = TRUE), 2)
  log_msg(sprintf("摘要: %d/%d | 文件: %d/%d (%.2f MB)",
                  has_abst, nrow(all), n_ok, nrow(all), tot_mb))

  # ── 报告 ──
  rp  <- file.path(dirs$base, sprintf("report_%s.txt", ts))
  con <- file(rp, "w", encoding = "UTF-8")
  writeLines(c(
    "文献搜索报告（HTML 全文增强版 2.3）", strrep("=", 44), "",
    sprintf("关键词: %s | 时间: 最近 %d 天", kw, days),
    sprintf("共 %d 篇 | 有摘要 %d 篇 | 获取文件 %d 个 (%.2f MB)", nrow(all), has_abst, n_ok, tot_mb),
    "", strrep("=", 60), ""
  ), con)
  for (i in seq_len(nrow(all))) {
    p <- all[i, ]
    status <- if (p$pdf_ok) sprintf("✔ %s [%s, %.2f MB]", p$pdf_file, p$pdf_method %||% "?", p$pdf_mb %||% 0)
              else "✗ 未获取"
    writeLines(c(
      sprintf("\n[%d] %s", i, p$title),
      sprintf("  %s | %s | %s", p$source, p$date, status),
      sprintf("  摘要: %s", ifelse(nchar(p$abstract) > 0, substr(p$abstract, 1, 280), "无")),
      strrep("-", 50)
    ), con)
  }
  close(con)

  cat("\n✅ 完成!\n")
  cat(sprintf("  论文: %d | 有摘要: %d | 文件: %d (%.2f MB)\n", nrow(all), has_abst, n_ok, tot_mb))
  tool <- get_html2pdf_tool()
  if (tool$type == "none")
    cat("  ⚠ 提示: 安装 chromium 可将 HTML 全文自动转为 PDF\n")
  cat(sprintf("  输出: %s\n\n", dirs$base))
}

unlink(list.files(".", "^\\.temp_.*\\.mjs$", full.names = TRUE))
main()