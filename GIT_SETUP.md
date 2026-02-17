# 🎯 Git 仓库初始化指南

## 📦 当前状态
你的项目目录尚未初始化为 Git 仓库。

## 🚀 快速设置步骤

### 第 1 步: 初始化 Git 仓库
```bash
git init
```

### 第 2 步: 配置 Git 用户信息（如果还没配置）
```bash
# 配置全局用户信息（适用于所有项目）
git config --global user.name "你的名字"
git config --global user.email "your.email@example.com"

# 或者只为当前项目配置
git config user.name "你的名字"
git config user.email "your.email@example.com"
```

### 第 3 步: 创建 .gitignore 文件
```bash
# 创建 .gitignore 文件，避免提交不必要的文件
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# macOS
.DS_Store

# 日志文件
*.log

# 临时文件
*.tmp
*.bak

# 敏感信息
.env
*.key
*.pem
credentials.json

# 大文件（如果有）
*.zip
*.tar.gz
*.rar
EOF
```

### 第 4 步: 首次提交
```bash
git add .
git commit -m "Initial commit: 项目初始化"
```

### 第 5 步: 在 GitHub 创建远程仓库

1. 访问 https://github.com/new
2. 填写仓库名称（例如：scientific-papers-mcp）
3. 选择公开（Public）或私有（Private）
4. **不要**勾选 "Initialize this repository with a README"
5. 点击 "Create repository"

### 第 6 步: 关联远程仓库
```bash
# 方式 1: HTTPS (简单，但每次需要输入密码或 token)
git remote add origin https://github.com/你的用户名/仓库名.git

# 方式 2: SSH (推荐，需要配置 SSH 密钥)
git remote add origin git@github.com:你的用户名/仓库名.git
```

### 第 7 步: 首次推送
```bash
# 推送到远程仓库（设置 main 为默认分支）
git branch -M main
git push -u origin main
```

## 🔐 配置 SSH 密钥（推荐）

如果选择 SSH 方式，需要配置 SSH 密钥：

### 1. 生成 SSH 密钥
```bash
# 生成新的 SSH 密钥
ssh-keygen -t ed25519 -C "your.email@example.com"

# 如果系统不支持 ed25519，使用 RSA
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# 按提示操作，建议使用默认路径
# 可以设置密码保护（推荐）或直接回车
```

### 2. 添加 SSH 密钥到 ssh-agent
```bash
# 启动 ssh-agent
eval "$(ssh-agent -s)"

# 添加密钥到 ssh-agent
ssh-add ~/.ssh/id_ed25519
# 或 ssh-add ~/.ssh/id_rsa
```

### 3. 复制公钥
```bash
# macOS
pbcopy < ~/.ssh/id_ed25519.pub

# Linux
cat ~/.ssh/id_ed25519.pub
# 然后手动复制输出
```

### 4. 添加到 GitHub
1. 访问 https://github.com/settings/keys
2. 点击 "New SSH key"
3. 输入标题（例如：MacBook Pro）
4. 粘贴公钥内容
5. 点击 "Add SSH key"

### 5. 测试连接
```bash
ssh -T git@github.com
# 成功会显示：Hi username! You've successfully authenticated...
```

## 📱 使用同步脚本

完成上述设置后，就可以使用 `sync-to-github.sh` 脚本了：

```bash
# 添加执行权限
chmod +x sync-to-github.sh

# 同步代码
./sync-to-github.sh "更新说明"
```

## 🔄 日常工作流程

### 开始工作
```bash
# 拉取最新代码
git pull origin main --rebase
```

### 保存工作
```bash
# 方式 1: 使用同步脚本（推荐）
./sync-to-github.sh "描述你的修改"

# 方式 2: 手动操作
git add .
git commit -m "描述你的修改"
git push origin main
```

### 查看状态
```bash
# 查看当前状态
git status

# 查看提交历史
git log --oneline -10

# 查看文件变更
git diff
```

## 🛡️ 安全检查清单

在首次推送前，请确保：

- [ ] `.gitignore` 文件已创建并配置正确
- [ ] 没有包含敏感信息（密码、API 密钥、token 等）
- [ ] 没有包含大文件（> 50MB）
- [ ] 如果有配置文件，创建了 `.env.example` 示例文件
- [ ] 已检查 `git status` 确认要提交的文件

## 🔍 检查敏感文件
```bash
# 在提交前，检查是否有敏感文件
git diff --cached --name-only | grep -E '\.(env|key|pem|credentials)$'

# 如果发现敏感文件，取消暂存
git reset HEAD 敏感文件名
```

## 💡 提示

1. **首次设置可能比较复杂**，但只需要做一次
2. **SSH 方式比 HTTPS 更方便**，推荐使用
3. **定期备份重要数据**，Git 不是万能的
4. **小步提交，频繁推送**，避免丢失工作

## 🆘 常见问题

### Q: 忘记了 GitHub 用户名？
```bash
# 查看 GitHub 账号
git config user.name
# 或访问 https://github.com/settings/profile
```

### Q: 推送时要求输入密码？
**原因**: 使用了 HTTPS 方式，但没有配置 token

**解决方案**:
1. 切换到 SSH 方式（推荐）
2. 或配置 Personal Access Token
   - 访问 https://github.com/settings/tokens
   - 生成新的 token
   - 使用 token 作为密码

### Q: 推送被拒绝（rejected）？
**原因**: 远程仓库有新的提交

**解决**:
```bash
# 先拉取更新
git pull origin main --rebase

# 再推送
git push origin main
```

---

**需要帮助?** 如果遇到问题，可以查看：
- [GitHub 官方文档](https://docs.github.com)
- [Git 官方文档](https://git-scm.com/doc)
