#!/usr/bin/env Rscript
# =============================================================================
# Google API 连通性测试工具
# 用途: 检查本地终端是否可以直接访问 Google API，或者测试代理是否生效
# =============================================================================

# --- 配置区域 ---
# 如果你有本地代理（VPN），请在这里填入，例如: "http://127.0.0.1:7890"
# 如果想测试直连，保持为空 ""
PROXY_URL <- "" 

# Google API 基础地址 (Custom Search API)
TEST_URL <- "https://www.googleapis.com/customsearch/v1"

check_connection <- function(url, proxy = "") {
  cat(sprintf("正在尝试连接: %s\n", url))
  
  # 构建 curl 命令
  cmd_prefix <- "curl -I -s -w \"%{http_code}\" -o /dev/null --max-time 5"
  
  if (nchar(proxy) > 0) {
    cat(sprintf("使用代理: %s\n", proxy))
    cmd <- sprintf("%s -x '%s' '%s'", cmd_prefix, proxy, url)
  } else {
    cat("模式: 直连 (无代理)\n")
    cmd <- sprintf("%s '%s'", cmd_prefix, url)
  }
  
  # 执行系统命令
  # 注意: 如果是 Windows，确保终端能运行 curl
  status_code <- tryCatch(
    system(cmd, intern = TRUE),
    warning = function(w) "TIMEOUT",
    error = function(e) "ERROR"
  )
  
  return(as.character(status_code))
}

cat("--------------------------------------------------\n")
cat("   Google API 连通性测试\n")
cat("--------------------------------------------------\n")

code <- check_connection(TEST_URL, PROXY_URL)

cat("\n测试结果: ")
if (code == "400") {
  cat("✅ 连接成功! (返回 400 是正常的，因为我们没带 API Key)\n")
  cat("说明: 你的网络可以直接访问 Google API。\n")
} else if (code == "200") {
  cat("✅ 连接成功! (返回 200 OK)\n")
} else if (code == "000" || code == "TIMEOUT") {
  cat("❌ 连接超时/失败 (Code: 000)\n")
  cat("说明: 无法连接 Google。如果在中国大陆，这是预期的。\n")
  cat("建议: 请在主程序的 CONFIG 中配置 'GOOGLE_PROXY' (例如 http://127.0.0.1:7890)\n")
} else if (code == "403") {
  cat("⚠ 连接通了，但被拒绝 (403)。\n")
  cat("说明: 网络是通的，但可能 API Key 有问题或 IP 受限。\n")
} else {
  cat(sprintf("❓ 未知状态码: %s\n", code))
  cat("说明: 至少服务器有响应，网络可能是通的。\n")
}
cat("--------------------------------------------------\n")