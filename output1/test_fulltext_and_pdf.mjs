#!/usr/bin/env node
import { searchPapers } from '../dist/tools/search-papers.js';
import { fetchLatest } from '../dist/tools/fetch-latest.js';
import { fetchContent } from '../dist/tools/fetch-content.js';
import { RateLimiter } from '../dist/core/rate-limiter.js';
import fs from 'fs';
import path from 'path';
import https from 'https';
import http from 'http';
import { URL } from 'url';

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

// 使用 axios 下载PDF (更稳定)
async function downloadPDF(url, filename) {
  const { default: axios } = await import('axios');
  const directUrl = getDirectPDFUrl(url);
  console.log(`    📥 下载PDF: ${directUrl}`);
  
  const filepath = path.join(PDF_DIR, filename);
  
  try {
    const response = await axios({
      method: 'GET',
      url: directUrl,
      responseType: 'stream',
      timeout: 60000,
      maxRedirects: 5,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/pdf,application/octet-stream,*/*'
      }
    });
    
    const writer = fs.createWriteStream(filepath);
    response.data.pipe(writer);
    
    return new Promise((resolve, reject) => {
      writer.on('finish', () => {
        const stats = fs.statSync(filepath);
        console.log(`    ✅ 下载完成: ${filename} (${(stats.size / 1024).toFixed(1)} KB)`);
        resolve(filepath);
      });
      writer.on('error', (err) => {
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
    output += `【全文内容】
${paper.text.substring(0, 50000)}${paper.text.length > 50000 ? '\n\n... (内容已截断)' : ''}

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

async function test1_arxivML() {
  console.log('\n📋 测试 1: arXiv 搜索 Machine Learning (获取全文+PDF)...');
  
  try {
    const result = await searchPapers({
      source: 'arxiv',
      query: 'machine learning',
      field: 'all',
      count: 3,
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
        const contentResult = await fetchContent({
          source: 'arxiv',
          id: paper.id
        }, rateLimiter);
        
        const fullPaper = contentResult.content;
        if (fullPaper && fullPaper.text) {
          paper.text = fullPaper.text;
          paper.abstract = fullPaper.abstract || paper.abstract;
          console.log(`    ✅ 全文: ${fullPaper.text.length} 字符`);
        } else {
          console.log(`    ⚠️ 无全文`);
        }
      } catch (e) {
        console.log(`    ❌ 获取全文失败: ${e.message}`);
      }
      
      // 下载PDF
      if (paper.pdf_url) {
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
        const filename = `test1_${safeTitle}_${paper.id}.pdf`;
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
        text_truncated: paper.text?.length > 50000,
        pdf_downloaded: paper.pdf_downloaded || false,
        pdf_filename: paper.pdf_filename || null
      });
      await new Promise(r => setTimeout(r, 2000));
    }
    
    saveToFile('test1_arxiv_ml.txt', fullOutput);
    saveJSON('test1_arxiv_ml.json', jsonResults);
    
  } catch (error) {
    console.error('❌ 测试 1 失败:', error.message);
    saveToFile('test1_arxiv_ml.txt', `错误: ${error.message}`);
  }
}

async function test2_coreCOVID() {
  console.log('\n📋 测试 2: CORE 搜索 COVID-19 (获取全文+PDF)...');
  
  try {
    const result = await searchPapers({
      source: 'core',
      query: 'COVID-19',
      field: 'all',
      count: 3,
      sortBy: 'relevance'
    }, rateLimiter);
    
    const papers = result.content || [];
    let fullOutput = `CORE 搜索: COVID-19\n找到 ${papers.length} 篇论文\nPDF保存目录: ${PDF_DIR}\n\n`;
    const jsonResults = [];
    
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i];
      console.log(`\n  [${i+1}/${papers.length}] ${paper.title?.substring(0, 60)}...`);
      
      // 获取全文
      try {
        const contentResult = await fetchContent({
          source: 'core',
          id: paper.id
        }, rateLimiter);
        
        const fullPaper = contentResult.content;
        if (fullPaper && fullPaper.text) {
          paper.text = fullPaper.text;
          console.log(`    ✅ 全文: ${fullPaper.text.length} 字符`);
        } else {
          console.log(`    ⚠️ 无全文`);
        }
      } catch (e) {
        console.log(`    ❌ 获取全文失败: ${e.message}`);
      }
      
      // 下载PDF
      if (paper.pdf_url) {
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
        const filename = `test2_${safeTitle}_${paper.id}.pdf`;
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
        text_truncated: paper.text?.length > 50000,
        pdf_downloaded: paper.pdf_downloaded || false,
        pdf_filename: paper.pdf_filename || null
      });
      await new Promise(r => setTimeout(r, 2000));
    }
    
    saveToFile('test2_core_covid19.txt', fullOutput);
    saveJSON('test2_core_covid19.json', jsonResults);
    
  } catch (error) {
    console.error('❌ 测试 2 失败:', error.message);
    saveToFile('test2_core_covid19.txt', `错误: ${error.message}`);
  }
}

async function test3_arxivLatestAI() {
  console.log('\n📋 测试 3: arXiv 最新 AI 论文 (获取全文+PDF)...');
  
  try {
    const result = await fetchLatest({
      source: 'arxiv',
      category: 'cs.AI',
      count: 3
    }, rateLimiter);
    
    const papers = result.content || [];
    let fullOutput = `arXiv 最新论文: cs.AI\n找到 ${papers.length} 篇论文\nPDF保存目录: ${PDF_DIR}\n\n`;
    const jsonResults = [];
    
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i];
      console.log(`\n  [${i+1}/${papers.length}] ${paper.title?.substring(0, 60)}...`);
      
      // 获取全文
      try {
        const contentResult = await fetchContent({
          source: 'arxiv',
          id: paper.id
        }, rateLimiter);
        
        const fullPaper = contentResult.content;
        if (fullPaper && fullPaper.text) {
          paper.text = fullPaper.text;
          paper.abstract = fullPaper.abstract || paper.abstract;
          console.log(`    ✅ 全文: ${fullPaper.text.length} 字符`);
        } else {
          console.log(`    ⚠️ 无全文`);
        }
      } catch (e) {
        console.log(`    ❌ 获取全文失败: ${e.message}`);
      }
      
      // 下载PDF
      if (paper.pdf_url) {
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
        const filename = `test3_${safeTitle}_${paper.id}.pdf`;
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
        text_truncated: paper.text?.length > 50000,
        pdf_downloaded: paper.pdf_downloaded || false,
        pdf_filename: paper.pdf_filename || null
      });
      await new Promise(r => setTimeout(r, 2000));
    }
    
    saveToFile('test3_arxiv_latest_ai.txt', fullOutput);
    saveJSON('test3_arxiv_latest_ai.json', jsonResults);
    
  } catch (error) {
    console.error('❌ 测试 3 失败:', error.message);
    saveToFile('test3_arxiv_latest_ai.txt', `错误: ${error.message}`);
  }
}

async function test4_openAlexAI() {
  console.log('\n📋 测试 4: OpenAlex 搜索 AI (获取全文)...');
  
  try {
    const result = await searchPapers({
      source: 'openalex',
      query: 'artificial intelligence',
      field: 'all',
      count: 3,
      sortBy: 'relevance'
    }, rateLimiter);
    
    const papers = result.content || [];
    let fullOutput = `OpenAlex 搜索: artificial intelligence\n找到 ${papers.length} 篇论文\n\n`;
    const jsonResults = [];
    
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i];
      console.log(`\n  [${i+1}/${papers.length}] ${paper.title?.substring(0, 60)}...`);
      
      // 获取全文
      try {
        const contentResult = await fetchContent({
          source: 'openalex',
          id: paper.id
        }, rateLimiter);
        
        const fullPaper = contentResult.content;
        if (fullPaper && fullPaper.text) {
          paper.text = fullPaper.text;
          console.log(`    ✅ 全文: ${fullPaper.text.length} 字符`);
        } else {
          console.log(`    ⚠️ 无全文`);
        }
      } catch (e) {
        console.log(`    ❌ 获取全文失败: ${e.message}`);
      }
      
      // 尝试下载PDF (如果有)
      if (paper.pdf_url) {
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
        const filename = `test4_${safeTitle}_${paper.id}.pdf`;
        try {
          await downloadPDF(paper.pdf_url, filename);
          paper.pdf_downloaded = true;
          paper.pdf_filename = filename;
          paper.pdf_path = path.join(PDF_DIR, filename);
        } catch (e) {
          console.log(`    ⚠️ PDF下载失败: ${e.message}`);
        }
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
        text_truncated: paper.text?.length > 50000,
        pdf_downloaded: paper.pdf_downloaded || false,
        pdf_filename: paper.pdf_filename || null
      });
      await new Promise(r => setTimeout(r, 2000));
    }
    
    saveToFile('test4_openalex_ai.txt', fullOutput);
    saveJSON('test4_openalex_ai.json', jsonResults);
    
  } catch (error) {
    console.error('❌ 测试 4 失败:', error.message);
    saveToFile('test4_openalex_ai.txt', `错误: ${error.message}`);
  }
}

async function generateReport() {
  console.log('\n📊 生成测试报告...');
  
  const report = {
    timestamp: new Date().toISOString(),
    output_dir: OUTPUT_DIR,
    pdf_dir: PDF_DIR,
    tests: {}
  };
  
  // 检查所有输出文件
  const files = fs.readdirSync(OUTPUT_DIR);
  report.text_files = files.filter(f => f.endsWith('.txt')).map(f => {
    const stats = fs.statSync(path.join(OUTPUT_DIR, f));
    return { name: f, size_kb: (stats.size / 1024).toFixed(1) };
  });
  report.json_files = files.filter(f => f.endsWith('.json') && f !== 'test_report.json').map(f => {
    const stats = fs.statSync(path.join(OUTPUT_DIR, f));
    return { name: f, size_kb: (stats.size / 1024).toFixed(1) };
  });
  
  // 检查PDF文件
  if (fs.existsSync(PDF_DIR)) {
    const pdfFiles = fs.readdirSync(PDF_DIR).filter(f => f.endsWith('.pdf'));
    report.pdf_files = pdfFiles.map(f => {
      const stats = fs.statSync(path.join(PDF_DIR, f));
      return { name: f, size_kb: (stats.size / 1024).toFixed(1) };
    });
    report.total_pdfs = pdfFiles.length;
  } else {
    report.pdf_files = [];
    report.total_pdfs = 0;
  }
  
  saveJSON('test_report.json', report);
  
  console.log('\n' + '='.repeat(80));
  console.log('✅ 所有测试完成！');
  console.log('='.repeat(80));
  console.log(`\n📂 输出目录: ${OUTPUT_DIR}`);
  console.log(`📂 PDF目录: ${PDF_DIR}`);
  console.log(`\n📄 文本报告 (${report.text_files.length}个):`);
  report.text_files.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  console.log(`\n📄 JSON数据 (${report.json_files.length}个):`);
  report.json_files.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  console.log(`\n📕 PDF文件 (${report.total_pdfs}个):`);
  report.pdf_files.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  console.log('\n📊 详细报告: output/test_report.json');
}

async function runAllTests() {
  console.log('🚀 开始全文获取 + PDF下载测试...');
  console.log(`📁 输出目录: ${OUTPUT_DIR}`);
  console.log(`📁 PDF目录: ${PDF_DIR}`);
  
  await test1_arxivML();
  await test2_coreCOVID();
  await test3_arxivLatestAI();
  await test4_openAlexAI();
  await generateReport();
}

runAllTests().catch(console.error);
