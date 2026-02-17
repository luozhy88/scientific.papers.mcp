#!/usr/bin/env node
import { searchPapers } from '../dist/tools/search-papers.js';
import { fetchLatest } from '../dist/tools/fetch-latest.js';
import { fetchContent } from '../dist/tools/fetch-content.js';
import { RateLimiter } from '../dist/core/rate-limiter.js';
import fs from 'fs';
import path from 'path';
import axios from 'axios';

const rateLimiter = new RateLimiter();
const OUTPUT_DIR = path.resolve('./output');
const PDF_DIR = path.join(OUTPUT_DIR, 'pdfs');

// 确保输出目录存在
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}
if (!fs.existsSync(PDF_DIR)) {
  fs.mkdirSync(PDF_DIR, { recursive: true });
}

// 转换URL为直接PDF链接
function getDirectPDFUrl(url) {
  if (!url) return null;
  
  // arXiv: 将 /abs/ 转为 /pdf/
  if (url.includes('arxiv.org/abs/')) {
    return url.replace('/abs/', '/pdf/') + '.pdf';
  }
  
  // arXiv: 如果已经是 /pdf/ 但没有 .pdf 后缀
  if (url.includes('arxiv.org/pdf/') && !url.endsWith('.pdf')) {
    return url + '.pdf';
  }
  
  // 修复 http 到 https (arXiv 现在需要 https)
  if (url.startsWith('http://arxiv.org/')) {
    return url.replace('http://', 'https://');
  }
  
  return url;
}

// 下载PDF文件
async function downloadPDF(url, filename) {
  const directUrl = getDirectPDFUrl(url);
  console.log(`    📥 下载PDF: ${directUrl}`);
  
  const filepath = path.join(PDF_DIR, filename);
  
  try {
    const response = await axios({
      method: 'GET',
      url: directUrl,
      responseType: 'stream',
      timeout: 120000,
      maxRedirects: 10,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/pdf,application/octet-stream,*/*'
      }
    });
    
    const writer = fs.createWriteStream(filepath);
    response.data.pipe(writer);
    
    return new Promise((resolve, reject) => {
      writer.on('finish', () => {
        writer.close();
        const stats = fs.statSync(filepath);
        console.log(`    ✅ 下载完成: ${filename} (${(stats.size / 1024).toFixed(1)} KB)`);
        resolve(filepath);
      });
      writer.on('error', (err) => {
        writer.close();
        fs.unlink(filepath, () => {});
        reject(err);
      });
    });
  } catch (error) {
    throw new Error(`下载失败: ${error.message}`);
  }
}

function saveToFile(filename, content) {
  const filepath = path.join(OUTPUT_DIR, filename);
  fs.writeFileSync(filepath, content, 'utf-8');
  console.log(`💾 已保存: ${filepath}`);
  return filepath;
}

function saveJSON(filename, data) {
  const filepath = path.join(OUTPUT_DIR, filename);
  fs.writeFileSync(filepath, JSON.stringify(data, null, 2), 'utf-8');
  console.log(`💾 已保存JSON: ${filepath}`);
  return filepath;
}

function formatPaper(paper, includeFullText = false) {
  let output = `
================================================================================
标题: ${paper.title || 'N/A'}
================================================================================

ID: ${paper.id || 'N/A'}
作者: ${paper.authors ? paper.authors.join(', ') : 'N/A'}
日期: ${paper.date || 'N/A'}
PDF链接: ${paper.pdf_url || 'N/A'}
DOI: ${paper.doi || 'N/A'}

【摘要】
${paper.abstract || '无摘要'}

`;

  if (includeFullText && paper.text) {
    const textPreview = paper.text.substring(0, 10000);
    output += `【全文内容 - 前10000字符】
${textPreview}${paper.text.length > 10000 ? '\n\n... (内容已截断, 总长度: ' + paper.text.length + ' 字符)' : ''}

`;
  }
  
  if (paper.pdf_downloaded) {
    output += `【PDF文件】
已下载: ${paper.pdf_filename}
路径: ${paper.pdf_path}

`;
  }

  output += `================================================================================`;
  return output;
}

async function testArxivML() {
  console.log('\n📋 测试: arXiv 搜索 Machine Learning (获取全文+PDF)...');
  
  try {
    const result = await searchPapers({
      source: 'arxiv',
      query: 'machine learning',
      field: 'all',
      count: 2,
      sortBy: 'relevance'
    }, rateLimiter);
    
    const papers = result.content || [];
    let fullOutput = `arXiv 搜索: machine learning\n找到 ${papers.length} 篇论文\nPDF保存目录: ${PDF_DIR}\n\n`;
    const jsonResults = [];
    
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i];
      console.log(`\n  [${i+1}/${papers.length}] ${paper.title?.substring(0, 60)}...`);
      
      // 获取全文
      try {
        console.log(`    🔍 获取全文...`);
        const contentResult = await fetchContent({
          source: 'arxiv',
          id: paper.id
        }, rateLimiter);
        
        const fullPaper = contentResult.content;
        if (fullPaper && fullPaper.text) {
          paper.text = fullPaper.text;
          paper.abstract = fullPaper.abstract || paper.abstract;
          console.log(`    ✅ 全文获取成功: ${fullPaper.text.length} 字符`);
        } else {
          console.log(`    ⚠️ 无全文内容`);
        }
      } catch (e) {
        console.log(`    ❌ 获取全文失败: ${e.message}`);
      }
      
      // 下载PDF
      if (paper.pdf_url) {
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 40);
        const filename = `arxiv_${safeTitle}_${paper.id}.pdf`;
        try {
          await downloadPDF(paper.pdf_url, filename);
          paper.pdf_downloaded = true;
          paper.pdf_filename = filename;
          paper.pdf_path = path.join(PDF_DIR, filename);
        } catch (e) {
          console.log(`    ❌ PDF下载失败: ${e.message}`);
        }
      } else {
        console.log(`    ⚠️ 无PDF链接`);
      }
      
      fullOutput += formatPaper(paper, true);
      jsonResults.push({
        id: paper.id,
        title: paper.title,
        authors: paper.authors,
        date: paper.date,
        pdf_url: paper.pdf_url,
        doi: paper.doi,
        abstract: paper.abstract,
        text_length: paper.text?.length || 0,
        pdf_downloaded: paper.pdf_downloaded || false,
        pdf_filename: paper.pdf_filename || null
      });
      
      // 延迟避免请求过快
      await new Promise(r => setTimeout(r, 1000));
    }
    
    saveToFile('arxiv_ml_results.txt', fullOutput);
    saveJSON('arxiv_ml_results.json', jsonResults);
    
    return { test: 'arxiv_ml', papers: papers.length, success: true };
    
  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    saveToFile('arxiv_ml_results.txt', `错误: ${error.message}`);
    return { test: 'arxiv_ml', papers: 0, success: false, error: error.message };
  }
}

async function testArxivLatestAI() {
  console.log('\n📋 测试: arXiv 最新 AI 论文 (获取全文+PDF)...');
  
  try {
    const result = await fetchLatest({
      source: 'arxiv',
      category: 'cs.AI',
      count: 2
    }, rateLimiter);
    
    const papers = result.content || [];
    let fullOutput = `arXiv 最新论文: cs.AI\n找到 ${papers.length} 篇论文\nPDF保存目录: ${PDF_DIR}\n\n`;
    const jsonResults = [];
    
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i];
      console.log(`\n  [${i+1}/${papers.length}] ${paper.title?.substring(0, 60)}...`);
      
      // 获取全文
      try {
        console.log(`    🔍 获取全文...`);
        const contentResult = await fetchContent({
          source: 'arxiv',
          id: paper.id
        }, rateLimiter);
        
        const fullPaper = contentResult.content;
        if (fullPaper && fullPaper.text) {
          paper.text = fullPaper.text;
          paper.abstract = fullPaper.abstract || paper.abstract;
          console.log(`    ✅ 全文获取成功: ${fullPaper.text.length} 字符`);
        } else {
          console.log(`    ⚠️ 无全文内容`);
        }
      } catch (e) {
        console.log(`    ❌ 获取全文失败: ${e.message}`);
      }
      
      // 下载PDF
      if (paper.pdf_url) {
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 40);
        const filename = `arxiv_ai_${safeTitle}_${paper.id}.pdf`;
        try {
          await downloadPDF(paper.pdf_url, filename);
          paper.pdf_downloaded = true;
          paper.pdf_filename = filename;
          paper.pdf_path = path.join(PDF_DIR, filename);
        } catch (e) {
          console.log(`    ❌ PDF下载失败: ${e.message}`);
        }
      } else {
        console.log(`    ⚠️ 无PDF链接`);
      }
      
      fullOutput += formatPaper(paper, true);
      jsonResults.push({
        id: paper.id,
        title: paper.title,
        authors: paper.authors,
        date: paper.date,
        pdf_url: paper.pdf_url,
        doi: paper.doi,
        abstract: paper.abstract,
        text_length: paper.text?.length || 0,
        pdf_downloaded: paper.pdf_downloaded || false,
        pdf_filename: paper.pdf_filename || null
      });
      
      await new Promise(r => setTimeout(r, 1000));
    }
    
    saveToFile('arxiv_latest_ai_results.txt', fullOutput);
    saveJSON('arxiv_latest_ai_results.json', jsonResults);
    
    return { test: 'arxiv_latest_ai', papers: papers.length, success: true };
    
  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    saveToFile('arxiv_latest_ai_results.txt', `错误: ${error.message}`);
    return { test: 'arxiv_latest_ai', papers: 0, success: false, error: error.message };
  }
}

async function generateReport(results) {
  console.log('\n📊 生成测试报告...');
  
  const report = {
    timestamp: new Date().toISOString(),
    output_dir: OUTPUT_DIR,
    pdf_dir: PDF_DIR,
    tests: results,
    files: {}
  };
  
  // 检查所有输出文件
  const files = fs.readdirSync(OUTPUT_DIR);
  report.files.text = files.filter(f => f.endsWith('.txt') && !f.includes('test_report')).map(f => {
    const stats = fs.statSync(path.join(OUTPUT_DIR, f));
    return { name: f, size_kb: parseFloat((stats.size / 1024).toFixed(1)) };
  });
  report.files.json = files.filter(f => f.endsWith('.json') && f !== 'test_report.json').map(f => {
    const stats = fs.statSync(path.join(OUTPUT_DIR, f));
    return { name: f, size_kb: parseFloat((stats.size / 1024).toFixed(1)) };
  });
  
  // 检查PDF文件
  if (fs.existsSync(PDF_DIR)) {
    const pdfFiles = fs.readdirSync(PDF_DIR).filter(f => f.endsWith('.pdf'));
    report.files.pdf = pdfFiles.map(f => {
      const stats = fs.statSync(path.join(PDF_DIR, f));
      return { name: f, size_kb: parseFloat((stats.size / 1024).toFixed(1)) };
    });
    report.total_pdfs = pdfFiles.length;
  } else {
    report.files.pdf = [];
    report.total_pdfs = 0;
  }
  
  saveJSON('test_report.json', report);
  
  console.log('\n' + '='.repeat(80));
  console.log('✅ 所有测试完成！');
  console.log('='.repeat(80));
  console.log(`\n📂 输出目录: ${OUTPUT_DIR}`);
  console.log(`📂 PDF目录: ${PDF_DIR}`);
  console.log(`\n📄 文本报告 (${report.files.text.length}个):`);
  report.files.text.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  console.log(`\n📄 JSON数据 (${report.files.json.length}个):`);
  report.files.json.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  console.log(`\n📕 PDF文件 (${report.total_pdfs}个):`);
  report.files.pdf.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  console.log('\n📊 详细报告: output/test_report.json');
}

async function runAllTests() {
  console.log('🚀 开始全文获取 + PDF下载测试...');
  console.log(`📁 输出目录: ${OUTPUT_DIR}`);
  console.log(`📁 PDF目录: ${PDF_DIR}`);
  
  const results = [];
  results.push(await testArxivML());
  results.push(await testArxivLatestAI());
  await generateReport(results);
}

runAllTests().catch(console.error);
