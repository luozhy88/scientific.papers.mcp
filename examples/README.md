# 示例脚本

本目录包含一些使用示例脚本。

## 脚本说明

### example_search.sh
Bash 脚本示例，展示如何搜索论文并保存结果。

使用方法：
```bash
cd /Users/apple/Desktop/kimi/test3/Scientific-Papers-MCP
./examples/example_search.sh
```

### example_fulltext.mjs
Node.js 脚本示例，展示如何搜索并获取论文全文。

使用方法：
```bash
cd /Users/apple/Desktop/kimi/test3/Scientific-Papers-MCP
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
node examples/example_fulltext.mjs
```

## 自定义脚本

你可以基于这些示例创建自己的脚本：

1. 复制示例文件
2. 修改搜索关键词和参数
3. 添加自己的处理逻辑
4. 运行脚本

## 更多示例

查看项目根目录的 `test_fulltext.mjs` 和 `test_download_pdf.mjs` 获取更多示例。
