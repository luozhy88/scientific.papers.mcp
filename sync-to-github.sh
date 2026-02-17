#!/bin/bash

# =============================================================================
# 🌍 通用 GitHub 自动同步脚本 (Universal Git Sync)
#
# 功能:
# 1. 自动检测当前分支
# 2. 智能处理提交（如果没有文件变化，自动跳过提交步骤）
# 3. 拉取远程更新 (Rebase 模式) 并更新子模块
# 4. 推送到远程仓库（支持自动重试）
# 5. 网络连接检测和大文件检查
#
# 用法:
#   chmod +x sync-to-github.sh
#   ./sync-to-github.sh [可选的提交信息]
# =============================================================================

# --- 配置区域 ---
# 遇到错误是否立即退出 (true/false)
EXIT_ON_ERROR=true

# 推送失败后的重试次数
MAX_RETRY=3

# 重试间隔（秒）
RETRY_DELAY=5

# 大文件警告阈值（MB）
MAX_FILE_SIZE=50

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- 辅助函数: 错误处理 ---
handle_error() {
    echo -e "${RED}❌ $1${NC}"
    if [ "$EXIT_ON_ERROR" = true ]; then
        exit 1
    fi
}

# --- 辅助函数: 网络连接检测 ---
check_network() {
    echo -e "${BLUE}🌐 检查网络连接...${NC}"

    # 尝试 ping GitHub
    if ping -c 1 github.com > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 网络连接正常${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  无法连接到 github.com，检查备用连接...${NC}"

        # 尝试备用检测
        if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  网络正常但无法访问 GitHub（可能需要代理）${NC}"
            return 0
        else
            echo -e "${RED}❌ 网络连接失败${NC}"
            return 1
        fi
    fi
}

# --- 辅助函数: 检查大文件 ---
check_large_files() {
    echo -e "${BLUE}📏 检查大文件...${NC}"

    # 查找所有暂存的文件
    local large_files=$(git diff --cached --name-only | while read file; do
        if [ -f "$file" ]; then
            size=$(ls -l "$file" | awk '{print $5}')
            size_mb=$((size / 1024 / 1024))
            if [ $size_mb -gt $MAX_FILE_SIZE ]; then
                echo "$file (${size_mb}MB)"
            fi
        fi
    done)

    if [ -n "$large_files" ]; then
        echo -e "${YELLOW}⚠️  检测到大文件:${NC}"
        echo "$large_files"
        echo -e "${YELLOW}   建议使用 Git LFS 管理大文件${NC}"
        read -p "是否继续提交? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            handle_error "取消提交"
        fi
    fi
}

# --- 辅助函数: 推送重试机制 ---
push_with_retry() {
    local remote=$1
    local branch=$2
    local attempt=1

    while [ $attempt -le $MAX_RETRY ]; do
        echo -e "${BLUE}⬆️  推送尝试 $attempt/$MAX_RETRY ...${NC}"

        if git push "$remote" "$branch"; then
            echo -e "${GREEN}✅ 推送成功!${NC}"
            return 0
        else
            if [ $attempt -lt $MAX_RETRY ]; then
                echo -e "${YELLOW}⚠️  推送失败，${RETRY_DELAY}秒后重试...${NC}"
                sleep $RETRY_DELAY
            else
                echo -e "${RED}❌ 推送失败，已达到最大重试次数${NC}"
                return 1
            fi
        fi

        ((attempt++))
    done

    return 1
}

# --- 1. 初始化检查 ---
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  🚀 开始同步流程${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查是否在 git 仓库中
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    handle_error "错误: 当前目录不是 Git 仓库"
fi

# 获取当前分支
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    handle_error "无法检测到当前分支（可能处于 detached HEAD 状态）"
fi

# 获取远程仓库名称 (通常是 origin，但也可能是 upstream)
REMOTE_NAME=$(git remote | head -n 1)
if [ -z "$REMOTE_NAME" ]; then
    echo -e "${YELLOW}⚠️  警告: 没有检测到远程仓库，只能进行本地提交。${NC}"
    REMOTE_NAME=""
else
    REMOTE_URL=$(git remote get-url "$REMOTE_NAME")

    # 检查远程分支是否存在
    echo -e "${BLUE}🔍 检查远程分支...${NC}"
    git fetch "$REMOTE_NAME" --quiet 2>/dev/null || echo -e "${YELLOW}⚠️  无法获取远程信息${NC}"

    # 检查远程分支是否存在
    if git ls-remote --heads "$REMOTE_NAME" "$CURRENT_BRANCH" | grep -q "$CURRENT_BRANCH"; then
        echo -e "${GREEN}✅ 远程分支 $REMOTE_NAME/$CURRENT_BRANCH 存在${NC}"
        REMOTE_BRANCH_EXISTS=true
    else
        echo -e "${YELLOW}⚠️  远程分支 $REMOTE_NAME/$CURRENT_BRANCH 不存在，将创建新分支${NC}"
        REMOTE_BRANCH_EXISTS=false
    fi
fi

# 准备提交信息
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
DEFAULT_MESSAGE="update: $TIMESTAMP"
COMMIT_MESSAGE="${1:-$DEFAULT_MESSAGE}"

echo -e "${CYAN}📂 项目位置: $(pwd)${NC}"
echo -e "${CYAN}🌿 当前分支: $CURRENT_BRANCH${NC}"
if [ -n "$REMOTE_NAME" ]; then
    echo -e "${CYAN}🔗 远程仓库: $REMOTE_NAME ($REMOTE_URL)${NC}"
fi
echo ""

# --- 2. 提交变更 (Commit) ---
echo -e "${BLUE}🔍 检查本地变更...${NC}"

# 尝试添加所有变更
# 注意：如果是嵌套的 dirty submodule，git add -A 不会将其添加到暂存区
git add -A

# 关键修复：检查暂存区(Staged)是否有内容
# git diff --cached --quiet 如果返回 0 表示没有变更，返回 1 表示有变更
if git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  没有检测到可提交的变更 (Working tree clean)${NC}"
    echo -e "${YELLOW}   (如果是 Submodule 修改，请先进入子目录提交)${NC}"
    echo -e "${GREEN}✅ 跳过提交步骤...${NC}"
    HAS_NEW_COMMIT=false
else
    # 检查大文件
    check_large_files

    echo -e "${BLUE}💾 正在提交变更...${NC}"
    echo -e "   信息: $COMMIT_MESSAGE"

    if git commit -m "$COMMIT_MESSAGE"; then
        echo -e "${GREEN}✅ 本地提交成功${NC}"
        HAS_NEW_COMMIT=true
    else
        handle_error "提交失败"
    fi
fi
echo ""

# 如果没有远程仓库，到此结束
if [ -z "$REMOTE_NAME" ]; then
    echo -e "${GREEN}✅ 完成 (仅本地模式)${NC}"
    exit 0
fi

# --- 3. 拉取更新 (Pull) ---
if [ "$REMOTE_BRANCH_EXISTS" = true ]; then
    echo -e "${BLUE}⬇️  正在从 $REMOTE_NAME 拉取更新 (Rebase)...${NC}"

    # 检查是否有未提交的修改
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}⚠️  检测到未提交的修改，先保存到 stash...${NC}"
        git stash push -m "Auto-stash before sync at $(date)"
        STASHED=true
    else
        STASHED=false
    fi

    # 使用 --rebase 保持提交历史整洁
    if git pull "$REMOTE_NAME" "$CURRENT_BRANCH" --rebase; then
        echo -e "${GREEN}✅ 拉取成功${NC}"

        # 如果之前保存了修改，恢复它们
        if [ "$STASHED" = true ]; then
            echo -e "${BLUE}📦 恢复之前保存的修改...${NC}"
            if git stash pop; then
                echo -e "${GREEN}✅ 修改已恢复${NC}"
            else
                echo -e "${RED}❌ 恢复修改失败，请手动处理: git stash list${NC}"
            fi
        fi

        # 额外步骤：检查并更新子模块 (Submodules)
        # 很多通用项目可能包含子模块，拉取后需要同步
        if [ -f ".gitmodules" ]; then
            echo -e "${BLUE}📦 检测到子模块，正在更新...${NC}"
            git submodule update --init --recursive
        fi
    else
        echo -e "${RED}❌ 拉取失败，可能存在合并冲突${NC}"
        echo -e "${YELLOW}💡 提示:${NC}"
        echo -e "${YELLOW}   1. 查看状态: git status${NC}"
        echo -e "${YELLOW}   2. 解决冲突后: git rebase --continue${NC}"
        echo -e "${YELLOW}   3. 或者放弃 rebase: git rebase --abort${NC}"
        if [ "$STASHED" = true ]; then
            echo -e "${YELLOW}   4. 查看保存的修改: git stash list${NC}"
        fi
        exit 1
    fi
    echo ""
else
    echo -e "${YELLOW}⚠️  跳过拉取步骤（远程分支不存在）${NC}"
    echo ""
fi

# --- 4. 推送到远程 (Push) ---
# 检查是否有未推送的提交
if [ "$REMOTE_BRANCH_EXISTS" = true ]; then
    # 获取本地和远程的提交差异
    LOCAL_COMMITS=$(git rev-list --count "$REMOTE_NAME/$CURRENT_BRANCH".."$CURRENT_BRANCH" 2>/dev/null || echo "0")
else
    LOCAL_COMMITS="1"  # 新分支，需要推送
fi

# 如果没有新提交且本地没有领先远程，跳过推送
if [ "$HAS_NEW_COMMIT" = false ] && [ "$LOCAL_COMMITS" = "0" ]; then
    echo -e "${GREEN}✅ 没有新提交需要推送，已与远程同步!${NC}"
else
    if [ "$LOCAL_COMMITS" != "0" ]; then
        echo -e "${CYAN}📊 检测到 $LOCAL_COMMITS 个本地提交待推送${NC}"
    fi
    # 检查网络连接
    if ! check_network; then
        handle_error "网络连接失败，无法推送"
    fi
    echo ""

    echo -e "${BLUE}⬆️  正在推送到 $REMOTE_NAME/$CURRENT_BRANCH ...${NC}"

    # 如果是新分支，需要设置上游分支
    if [ "$REMOTE_BRANCH_EXISTS" = false ]; then
        if git push "$REMOTE_NAME" "$CURRENT_BRANCH" --set-upstream; then
            echo -e "${GREEN}✅ 新分支已创建并推送!${NC}"
        else
            # 推送失败，尝试重试
            if push_with_retry "$REMOTE_NAME" "$CURRENT_BRANCH"; then
                echo -e "${GREEN}✅ 新分支已创建并推送!${NC}"
            else
                handle_error "推送新分支失败 (可能没有权限或网络问题)"
            fi
        fi
    else
        if ! git push "$REMOTE_NAME" "$CURRENT_BRANCH"; then
            # 推送失败，尝试重试
            if ! push_with_retry "$REMOTE_NAME" "$CURRENT_BRANCH"; then
                handle_error "推送失败 (可能没有权限或网络问题)"
            fi
        else
            echo -e "${GREEN}✅ 推送完成!${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  🎉 同步完成!${NC}"
echo -e "${GREEN}========================================${NC}"