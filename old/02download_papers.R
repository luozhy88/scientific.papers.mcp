#!/usr/bin/env Rscript
#
# 纯 R 语言学术文献下载工具 (ArXiv & BioRxiv/EuropePMC)
# 修复了无 PDF 链接的问题，增强了 PDF 提取逻辑
# 新增: 支持在无 PDF 时下载 HTML 全文
#
# 作者: Optimized for User
# 用法: Rscript download_papers.R <关键词> [数量] [天数]

# --- 1. 环境检查与包加载 ---
required_packages <- c("httr", "jsonlite", "xml2", "stringr", "dplyr")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) {
  cat("首次运行，正在安装依赖包...\n")
  install.packages(new_packages, repos = "https://cloud.r-project.org/")
}

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(xml2)
  library(stringr)
  library(dplyr)
})

# --- 2. 配置 ---
CONFIG <- list(
  TIMEOUT = 60,
  USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) R_Research_Tool/1.0",
  OUTPUT_DIR = "output"
)

# --- 3. 辅助函数 ---

# 安全文件名
safe_name <- function(text, max_len = 30) {
  text <- str_replace_all(text, "[^a-zA-Z0-9]", "_")
  text <- str_replace_all(text, "_+", "_")
  text <- str_sub(text, 1, max_len)
  return(tolower(text))
}

# 检查日期是否在范围内
is_recent <- function(date_str, days) {
  if (is.na(date_str) || date_str == "") return(FALSE)
  # 尝试多种日期格式
  d <- tryCatch(as.Date(date_str), error = function(e) NA)
  if (is.na(d)) return(FALSE)
  
  diff <- as.numeric(Sys.Date() - d)
  return(diff >= 0 && diff <= days)
}

# --- 4. 数据源搜索函数 ---

# >>> ArXiv 搜索 (XML API) <<<
search_arxiv <- function(query, limit, days) {
  cat(sprintf("🔎 [ArXiv] 正在搜索: %s ...\n", query))
  
  q_encoded <- URLencode(query)
  # 请求多一点数据，以便按日期过滤
  api_url <- sprintf(
    "http://export.arxiv.org/api/query?search_query=all:%s&start=0&max_results=%d&sortBy=submittedDate&sortOrder=descending", 
    q_encoded, limit * 3
  )
  
  resp <- tryCatch(GET(api_url, timeout(CONFIG$TIMEOUT)), error = function(e) NULL)
  if (is.null(resp) || status_code(resp) != 200) {
    cat("❌ [ArXiv] 连接失败\n")
    return(NULL)
  }
  
  doc <- read_xml(content(resp, "text", encoding = "UTF-8"))
  entries <- xml_find_all(doc, "//d1:entry", ns = xml_ns(doc))
  
  results <- list()
  
  if (length(entries) > 0) {
    for (node in entries) {
      pub_date <- xml_text(xml_find_first(node, "d1:published", ns = xml_ns(doc)))
      pub_date <- str_sub(pub_date, 1, 10) 
      
      if (is_recent(pub_date, days)) {
        title <- str_trim(str_replace_all(xml_text(xml_find_first(node, "d1:title", ns = xml_ns(doc))), "\n", " "))
        summary <- str_trim(str_replace_all(xml_text(xml_find_first(node, "d1:summary", ns = xml_ns(doc))), "\n", " "))
        id_url <- xml_text(xml_find_first(node, "d1:id", ns = xml_ns(doc)))
        
        pdf_url <- str_replace(id_url, "/abs/", "/pdf/")
        pdf_url <- paste0(pdf_url, ".pdf")
        
        authors <- paste(xml_text(xml_find_all(node, "d1:author/d1:name", ns = xml_ns(doc))), collapse = ", ")
        
        results[[length(results) + 1]] <- list(
          source = "ArXiv",
          id = basename(id_url),
          title = title,
          date = pub_date,
          authors = authors,
          abstract = summary,
          download_url = pdf_url, # 改名以统一
          file_type = "pdf"       # 明确类型
        )
      }
    }
  }
  
  if (length(results) > limit) results <- results[1:limit]
  return(results)
}

# >>> BioRxiv/EuropePMC 搜索 (JSON API) <<<
search_biorxiv <- function(query, limit, days) {
  cat(sprintf("🔎 [EuropePMC] 正在搜索: %s ...\n", query))
  
  api_url <- "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
  
  # 关键修改：增加 HAS_FT:y (Full Text) 条件，涵盖 PDF 和 HTML
  date_string <- sprintf("FIRST_PDATE:[%s TO %s]", Sys.Date() - days, Sys.Date())
  query_full <- sprintf("%s AND %s AND (HAS_PDF:y OR HAS_FT:y OR SRC:PPR OR OPEN_ACCESS:y)", query, date_string)
  
  params <- list(
    query = query_full,
    format = "json",
    pageSize = limit,
    resultType = "core"
  )
  
  resp <- tryCatch(GET(api_url, query = params, timeout(CONFIG$TIMEOUT)), error = function(e) NULL)
  
  if (is.null(resp) || status_code(resp) != 200) return(NULL)
  
  content_text <- content(resp, "text", encoding = "UTF-8")
  data <- tryCatch(fromJSON(content_text), error = function(e) NULL)
  
  results <- list()
  
  if (!is.null(data) && !is.null(data$resultList$result)) {
    items <- data$resultList$result
    if (length(items) > 0) {
      for (i in 1:nrow(items)) {
        item <- items[i,]
        
        download_link <- NA
        file_ext <- NA
        
        if (!is.null(item$fullTextUrlList) && !is.na(item$fullTextUrlList[1])) {
          ft_data <- item$fullTextUrlList$fullTextUrl
          
          if (is.list(ft_data) && length(ft_data) > 0) {
            ft_df <- tryCatch(as.data.frame(ft_data[[1]]), error = function(e) NULL)
            
            if (!is.null(ft_df) && "documentStyle" %in% names(ft_df)) {
              # 1. 优先找 PDF
              targets_pdf <- ft_df[toupper(ft_df$documentStyle) == "PDF", ]
              # 2. 其次找 HTML
              targets_html <- ft_df[toupper(ft_df$documentStyle) == "HTML", ]
              
              if (nrow(targets_pdf) > 0) {
                download_link <- targets_pdf$url[1]
                file_ext <- "pdf"
              } else if (nrow(targets_html) > 0) {
                download_link <- targets_html$url[1]
                file_ext <- "html"
              }
            }
          }
        }
        
        results[[length(results) + 1]] <- list(
          source = "EuropePMC",
          id = item$id,
          title = item$title,
          date = item$firstPublicationDate,
          authors = item$authorString,
          abstract = ifelse(is.null(item$abstractText), "无摘要", item$abstractText),
          download_url = download_link,
          file_type = file_ext
        )
      }
    }
  }
  
  return(results)
}

# --- 5. 下载逻辑 ---

download_files <- function(papers, output_dir) {
  # 统一放在 files 文件夹，因为不全是 pdf 了
  files_dir <- file.path(output_dir, "files")
  if (!dir.exists(files_dir)) dir.create(files_dir, recursive = TRUE)
  
  cat("\n🚀 开始下载文件 (PDF/HTML)...\n")
  
  # 为 dataframe 添加新列
  papers$downloaded_file <- NA
  papers$file_size_mb <- 0
  
  for (i in 1:nrow(papers)) {
    p <- papers[i, ]
    
    if (is.na(p$download_url) || p$download_url == "") {
      cat(sprintf("[%d/%d] ⚠️  无下载链接: %s\n", i, nrow(papers), str_trunc(p$title, 40)))
      next
    }
    
    # 根据文件类型确定后缀
    ext <- ifelse(is.na(p$file_type), "pdf", p$file_type)
    filename <- sprintf("%s_%s.%s", p$source, safe_name(p$title), ext)
    filepath <- file.path(files_dir, filename)
    
    type_label <- toupper(ext)
    cat(sprintf("[%d/%d] 📥 下载 [%s]: %s\n", i, nrow(papers), type_label, str_trunc(p$title, 35)))
    
    tryCatch({
      download.file(p$download_url, filepath, mode = "wb", quiet = TRUE, 
                   headers = c("User-Agent" = CONFIG$USER_AGENT))
      
      # 检查文件大小 (HTML可能较小，设为1KB门槛)
      min_size <- ifelse(ext == "html", 1000, 5000) 
      
      if (file.exists(filepath) && file.size(filepath) > min_size) { 
        sz <- round(file.size(filepath) / 1024 / 1024, 2)
        cat(sprintf("       ✅ 成功 (%.2f MB)\n", sz))
        papers$downloaded_file[i] <- filename
        papers$file_size_mb[i] <- sz
      } else {
        if (file.exists(filepath)) unlink(filepath)
        cat("       ❌ 失败 (文件无效)\n")
      }
    }, error = function(e) {
      cat(sprintf("       ❌ 错误: %s\n", e$message))
    })
    
    Sys.sleep(1) # 礼貌延时
  }
  
  return(papers)
}

# --- 6. 主程序 ---

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    cat("用法: Rscript download_papers.R <关键词> [数量] [天数]\n")
    quit(save = "no")
  }
  
  query <- args[1]
  count <- ifelse(length(args) >= 2, as.integer(args[2]), 5)
  days  <- ifelse(length(args) >= 3, as.integer(args[3]), 10)
  
  cat("\n========================================\n")
  cat(sprintf("关键词: %s\n", query))
  cat(sprintf("最近: %d 天\n", days))
  cat(sprintf("上限: %d 篇/源\n", count))
  cat("========================================\n\n")
  
  dir_name <- paste0(safe_name(query), "_results")
  full_output_dir <- file.path(CONFIG$OUTPUT_DIR, dir_name)
  if (!dir.exists(full_output_dir)) dir.create(full_output_dir, recursive = TRUE)
  
  all_results <- list()
  
  # 1. 搜 ArXiv
  res_arxiv <- search_arxiv(query, count, days)
  if (!is.null(res_arxiv)) all_results <- c(all_results, res_arxiv)
  
  # 2. 搜 BioRxiv/EuropePMC
  res_bio <- search_biorxiv(query, count, days)
  if (!is.null(res_bio)) all_results <- c(all_results, res_bio)
  
  if (length(all_results) == 0) {
    cat("\n⚠️  未找到相关论文。建议增加天数或尝试不同关键词。\n")
    quit(save = "no")
  }
  
  # 转换为 DataFrame
  df <- bind_rows(all_results)
  df <- df %>% distinct(title, .keep_all = TRUE)
  
  cat(sprintf("\n共找到 %d 篇唯一论文。\n", nrow(df)))
  
  # 下载文件
  final_df <- download_files(df, full_output_dir)
  
  # 保存 CSV
  csv_path <- file.path(full_output_dir, "papers_list.csv")
  write.csv(final_df, csv_path, row.names = FALSE, fileEncoding = "UTF-8")
  
  # 生成简报
  report_path <- file.path(full_output_dir, "report.txt")
  sink(report_path)
  cat(sprintf("搜索报告: %s\n", query))
  cat(sprintf("生成时间: %s\n", Sys.time()))
  cat("----------------------------------------\n\n")
  
  for (i in 1:nrow(final_df)) {
    p <- final_df[i, ]
    cat(sprintf("[%d] %s\n", i, p$title))
    cat(sprintf("来源: %s | 日期: %s\n", p$source, p$date))
    
    file_info <- "未下载"
    if (!is.na(p$downloaded_file)) {
      file_info <- sprintf("%s (%.2f MB)", p$downloaded_file, p$file_size_mb)
    }
    cat(sprintf("文件: %s\n", file_info))
    cat(sprintf("链接: %s\n", ifelse(is.na(p$download_url), "无", p$download_url)))
    # 截取摘要，防止太长
    abst_show <- ifelse(nchar(p$abstract) > 300, paste0(substr(p$abstract, 1, 300), "..."), p$abstract)
    cat(sprintf("摘要: %s\n", abst_show))
    cat("\n----------------------------------------\n\n")
  }
  sink() # 关闭 sink
  
  cat("\n✅ 完成！\n")
  cat(sprintf("CSV 和报告已保存至: %s\n", full_output_dir))
  cat(sprintf("下载文件在: %s/files\n", full_output_dir))
  
  # 显式退出，防止 R 抛出奇怪的 "零长度变量名" 错误
  quit(save = "no")
}

main()