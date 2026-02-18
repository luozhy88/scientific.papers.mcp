#!/usr/bin/env Rscript
# 邮件功能测试脚本（Python smtplib 方式）

py_script <- file.path(getwd(), "send_email.py")
auth_code  <- Sys.getenv("QQ_AUTH_CODE", "utdwpcjamkewcbbd")
recipient  <- Sys.getenv("RECIPIENT_EMAIL", "479321347@qq.com")

cat("=== 邮件发送功能测试 ===\n\n")

# 检查 Python 脚本是否存在
if (!file.exists(py_script)) {
  cat("❌ 未找到 send_email.py，请确认脚本在当前目录\n")
  quit(status = 1)
}
cat(sprintf("✓ Python 脚本: %s\n", py_script))

# 检查 Python
py_version <- system("python3 --version 2>&1", intern = TRUE)
cat(sprintf("✓ Python: %s\n", py_version))
cat(sprintf("✓ 授权码: %s****\n", substr(auth_code, 1, 4)))
cat(sprintf("✓ 收件人: %s\n\n", recipient))

# 写测试邮件正文
test_body <- paste(
  "文献搜索报告 - 测试\n",
  "搜索日期:", format(Sys.Date(), "%Y-%m-%d"),
  "\n\n============================================================\n\n",
  "[1] Deep Learning for NLP\n",
  "来源: SEMANTICSCHOLAR | 日期: 2026-02-15\n",
  "摘要: 测试摘要内容...\n",
  "PDF: ✓ 已下载 (3.5 MB)\n",
  "链接: https://example.com\n\n",
  "------------------------------------------------------------\n\n",
  "此邮件由文献搜索脚本自动发送 - 测试\n",
  sep = ""
)

tmp <- tempfile(fileext = ".txt")
writeLines(test_body, tmp, useBytes = TRUE)

subject <- sprintf("文献搜索报告 - 测试邮件 (%s)", format(Sys.Date(), "%Y-%m-%d"))
Sys.setenv(QQ_AUTH_CODE = auth_code, RECIPIENT_EMAIL = recipient)

cmd    <- sprintf("python3 '%s' '%s' '%s' '%s' 2>&1", py_script, subject, tmp, recipient)
result <- system(cmd, intern = TRUE)
unlink(tmp)

cat("📨 发送结果:", paste(result, collapse = " "), "\n\n")

if (any(grepl("^SUCCESS$", result))) {
  cat("✅ 邮件发送成功！请检查邮箱：", recipient, "\n")
} else {
  cat("❌ 邮件发送失败\n")
  cat("   错误:", paste(grep("ERROR", result, value = TRUE), collapse = "\n"), "\n")
}
