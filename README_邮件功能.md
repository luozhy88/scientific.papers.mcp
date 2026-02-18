# 📧 文献搜索邮件功能 - 最终版本

## ✅ 已完成优化（v13.2）

### 关键改进
- ✅ **使用 Python smtplib** 发送邮件（无需 Java/mailR）
- ✅ **使用正确的 QQ 授权码**：`utdwpcjamkewcbbd`
- ✅ **测试通过**：邮件发送成功
- ✅ **自动查找**：Python 脚本自动定位
- ✅ **无额外依赖**：macOS 自带 Python 3

## 🚀 快速开始

### 1. 测试邮件功能

```bash
cd /Users/apple/Desktop/kimi/scientific.papers.mcp
Rscript test_email.R
```

**期望输出**：
```
=== 邮件发送功能测试 ===

✓ Python 脚本: /Users/apple/Desktop/kimi/scientific.papers.mcp/send_email.py
✓ Python: Python 3.14.3
✓ 授权码: utdw****
✓ 收件人: 479321347@qq.com

📨 发送结果: SUCCESS

✅ 邮件发送成功！请检查邮箱： 479321347@qq.com
```

### 2. 运行文献搜索（自动发送邮件）

```bash
# 搜索 5 篇最近 30 天的论文
Rscript download_papersv13.R "machine learning" 5 30

# 搜索 10 篇最近 7 天的论文
Rscript download_papersv13.R "CRISPR" 10 7
```

**完整输出示例**：
```
[10:15:20] ℹ 关键词: "machine learning" | 每源: 5 | 最近 30 天
[10:15:25] ✔ Semantic Scholar: 找到 5 篇
[10:15:30] ✔ Europe PMC: 找到 4 篇
...
[10:18:45] ✔ CSV / JSON 已保存
[10:18:45] ✔ 报告已保存

[10:18:46] ℹ 准备发送邮件报告...
[10:18:46] ℹ 正在生成邮件报告...
[10:18:46] ℹ 发送邮件到: 479321347@qq.com
[10:18:49] ✔ 邮件发送成功！

✅ 完成!
  论文: 9篇 | 有摘要: 9篇 | PDF: 6个
  输出: output/machine_learning_papers
```

## 📧 邮件内容示例

```
文献搜索报告

关键词: machine learning
搜索日期: 2026-02-18
总论文数: 9
PDF下载成功: 6
总下载大小: 45.67 MB

============================================================

[1] Deep Learning for Natural Language Processing
来源: SEMANTICSCHOLAR | 日期: 2026-02-15
摘要: This paper presents a comprehensive survey of deep learning
techniques applied to natural language processing tasks. We discuss
recent advances in transformer architectures...
PDF: ✓ 已下载 (5.23 MB)
链接: https://www.semanticscholar.org/paper/abc123

------------------------------------------------------------

[2] Transfer Learning in Computer Vision
来源: ARXIV | 日期: 2026-02-14
摘要: We propose a novel transfer learning approach that significantly
improves performance on image classification tasks...
PDF: ✗ 未下载
链接: https://arxiv.org/abs/2402.12345

------------------------------------------------------------

... (更多文献)

此邮件由文献搜索脚本自动发送。
```

## 📁 文件结构

```
/Users/apple/Desktop/kimi/scientific.papers.mcp/
├── download_papersv13.R       # 主脚本（已优化）
├── send_email.py              # Python 邮件发送脚本
├── test_email.R               # 邮件测试脚本
├── 快速开始.md                 # 快速入门指南
├── 邮件功能说明.md             # 详细说明
└── QQ邮箱配置指南.md          # QQ 邮箱配置
```

## 🔧 技术实现

### 邮件发送流程
1. **R 脚本生成邮件内容**（包含文献详情）
2. **写入临时文件**（UTF-8 编码）
3. **调用 Python 脚本**：`python3 send_email.py <主题> <内容文件> <收件人>`
4. **Python 使用 smtplib**：通过 QQ SMTP 服务器发送
5. **返回结果**：SUCCESS 或 ERROR

### 关键配置

```r
CONFIG <- list(
  EMAIL_ENABLED   = TRUE,                    # 邮件开关
  SMTP_USER       = "479321347@qq.com",      # 发件人
  SMTP_AUTH_CODE  = "utdwpcjamkewcbbd",      # QQ 授权码
  RECIPIENT_EMAIL = "479321347@qq.com"       # 收件人
)
```

### Python 脚本核心代码

```python
import smtplib
from email.mime.text import MIMEText

server = smtplib.SMTP_SSL('smtp.qq.com', 465)
server.login("479321347@qq.com", "utdwpcjamkewcbbd")
server.sendmail(from_email, to_email, msg.as_string())
server.quit()
```

## ⚙️ 高级配置

### 修改收件人

```bash
# 临时修改（单次有效）
export RECIPIENT_EMAIL="目标邮箱@example.com"
Rscript download_papersv13.R "关键词" 5 10

# 或直接编辑脚本第348行
```

### 禁用邮件功能

编辑 `download_papersv13.R` 第345行：
```r
EMAIL_ENABLED = FALSE
```

### 使用其他授权码

```bash
# 临时修改
export QQ_AUTH_CODE="新的授权码"

# 或编辑脚本第347行
```

## ❓ 常见问题

### Q1: Python 版本要求？
**A**: Python 3.x 即可。macOS 自带 Python 3。

### Q2: 需要安装额外的 Python 包吗？
**A**: 不需要。`smtplib` 和 `email` 是 Python 标准库。

### Q3: 为什么不用 mailR？
**A**: mailR 需要 Java 环境。Python 方案更轻量，macOS 自带。

### Q4: send_email.py 找不到？
**A**: 确保 `send_email.py` 与 `download_papersv13.R` 在同一目录。

### Q5: 邮件发送失败？
**A**:
1. 检查授权码是否正确（`utdwpcjamkewcbbd`）
2. 运行 `Rscript test_email.R` 测试
3. 查看错误信息

### Q6: 收不到邮件？
**A**:
1. 检查垃圾邮件文件夹
2. 确认 QQ 邮箱已开启 SMTP 服务
3. 查看脚本输出是否显示"发送成功"

## 🔒 安全提示

- ✅ 授权码已配置在脚本中（仅您本地使用）
- ✅ 可通过环境变量覆盖（推荐）
- ❌ 请勿将含授权码的脚本提交到公开仓库

## 📊 性能说明

- **邮件生成时间**：< 1 秒
- **发送时间**：1-3 秒
- **总额外开销**：< 5 秒
- **对搜索影响**：无（邮件在最后发送）

## 🎯 功能对比

| 方案 | 优点 | 缺点 | 状态 |
|------|------|------|------|
| EmailJS | Web API 简单 | 不支持服务器端调用 | ❌ 已弃用 |
| curl SMTP | 系统自带工具 | 认证失败 | ❌ 已弃用 |
| mailR (Java) | R 原生包 | 需要安装 Java | ❌ 未使用 |
| **Python smtplib** | 轻量、可靠 | 需要 Python | ✅ **当前方案** |

## 📝 更新日志

**v13.2 (2026-02-18)**
- ✅ 改用 Python smtplib 发送邮件
- ✅ 配置正确的 QQ 授权码
- ✅ 测试通过并验证
- ✅ 自动查找 Python 脚本路径

**v13.1**
- ❌ 尝试 EmailJS（失败：不支持非浏览器调用）
- ❌ 尝试 curl SMTP（失败：认证问题）

**v13.0**
- 首次添加邮件功能

## 🚀 立即使用

```bash
# 1. 测试邮件
Rscript test_email.R

# 2. 运行搜索（会自动发送邮件）
Rscript download_papersv13.R "your topic" 5 30

# 3. 检查邮箱： 479321347@qq.com
```

---

**版本**: v13.2（Python smtplib 最终版）
**更新时间**: 2026-02-18 10:20
**状态**: ✅ 已测试通过
**作者**: 基于用户提供的 mailR 代码优化
