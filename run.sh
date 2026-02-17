#!/bin/bash
# Scientific Papers MCP 启动脚本

# 加载 nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 运行 CLI
node paper-cli.mjs "$@"
