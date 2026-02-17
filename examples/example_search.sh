#!/bin/bash
# 示例：搜索论文并保存结果

cd "$(dirname "$0")/.."

echo "🔍 示例1: 搜索 COVID-19 相关论文"
./run.sh search --source=core --query="COVID-19" --count=3 > ~/Desktop/covid_papers.txt
echo "✅ 结果保存到 ~/Desktop/covid_papers.txt"

echo ""
echo "🔍 示例2: 搜索机器学习论文"
./run.sh search --source=core --query="machine learning" --count=3 > ~/Desktop/ml_papers.txt
echo "✅ 结果保存到 ~/Desktop/ml_papers.txt"

echo ""
echo "🔍 示例3: 获取最新 AI 论文"
./run.sh latest --source=arxiv --category=cs.AI --count=3 > ~/Desktop/ai_latest.txt
echo "✅ 结果保存到 ~/Desktop/ai_latest.txt"

echo ""
echo "全部完成！"
