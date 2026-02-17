#!/usr/bin/env node
// 示例：搜索并获取论文全文

import { searchPapers } from '../dist/tools/search-papers.js';
import { fetchContent } from '../dist/tools/fetch-content.js';
import { RateLimiter } from '../dist/core/rate-limiter.js';
import fs from 'fs';

const rateLimiter = new RateLimiter();

async function main() {
  const keyword = 'COVID-19';
  console.log(`🔍 搜索: ${keyword}`);
  
  // 搜索论文
  const result = await searchPapers({
    source: 'core',
    query: keyword,
    field: 'all',
    count: 3
  }, rateLimiter);
  
  const papers = result.content || [];
  console.log(`✅ 找到 ${papers.length} 篇论文`);
  
  // 获取每篇论文的全文
  for (let i = 0; i < papers.length; i++) {
    const paper = papers[i];
    console.log(`\n[${i+1}/${papers.length}] ${paper.title}`);
    
    try {
      const contentResult = await fetchContent({
        source: 'core',
        id: paper.id
      }, rateLimiter);
      
      const fullPaper = contentResult.content;
      if (fullPaper && fullPaper.text) {
        paper.text = fullPaper.text;
        console.log(`   ✅ 全文: ${fullPaper.text.length} 字符`);
      }
    } catch (e) {
      console.log(`   ❌ 获取失败: ${e.message}`);
    }
    
    // 延迟避免限流
    await new Promise(r => setTimeout(r, 2000));
  }
  
  // 保存结果
  const output = papers.map(p => `
================================================================================
标题: ${p.title}
作者: ${p.authors?.join(', ')}
日期: ${p.date}
PDF: ${p.pdf_url}

${p.text || '无全文'}
================================================================================
`).join('\n');
  
  fs.writeFileSync('~/Desktop/fulltext_results.txt', output);
  console.log('\n💾 结果保存到 ~/Desktop/fulltext_results.txt');
}

main().catch(console.error);
