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
  
  if (url.includes('arxiv.org/abs/')) {
    return url.replace('/abs/', '/pdf/') + '.pdf';
  }
  
  if (url.includes('arxiv.org/pdf/') && !url.endsWith('.pdf')) {
    return url + '.pdf';
  }
  
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
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
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
    const textPreview = paper.text.substring(0, 15000);
    output += `【全文内容 - 前15000字符】
${textPreview}${paper.text.length > 15000 ? '\n\n... (内容已截断, 总长度: ' + paper.text.length + ' 字符)' : ''}

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

// 通用测试函数
async function runTest(testName, source, queryOrCategory, isLatest = false, count = 2) {
  console.log(`\n📋 ${testName}...`);
  
  try {
    let papers;
    if (isLatest) {
      const result = await fetchLatest({ source, category: queryOrCategory, count }, rateLimiter);
      papers = result.content || [];
    } else {
      const result = await searchPapers({ 
        source, 
        query: queryOrCategory, 
        field: 'all', 
        count, 
        sortBy: 'relevance' 
      }, rateLimiter);
      papers = result.content || [];
    }
    
    console.log(`   找到 ${papers.length} 篇论文`);
    
    let fullOutput = `${testName}\n找到 ${papers.length} 篇论文\nPDF保存目录: ${PDF_DIR}\n\n`;
    const jsonResults = [];
    
    for (let i = 0; i < papers.length; i++) {
      const paper = papers[i];
      console.log(`\n  [${i+1}/${papers.length}] ${paper.title?.substring(0, 55)}...`);
      
      // 获取全文
      try {
        console.log(`    🔍 获取全文...`);
        const contentResult = await fetchContent({ source, id: paper.id }, rateLimiter);
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
        const safeTitle = (paper.title || 'paper').replace(/[^a-zA-Z0-9]/g, '_').substring(0, 35);
        const filename = `${source}_${safeTitle}_${paper.id}.pdf`;
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
      
      await new Promise(r => setTimeout(r, 1500));
    }
    
    const safeName = testName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
    saveToFile(`${safeName}.txt`, fullOutput);
    saveJSON(`${safeName}.json`, jsonResults);
    
    return { test: testName, source, papers: papers.length, success: true };
    
  } catch (error) {
    console.error(`❌ 测试失败:`, error.message);
    const safeName = testName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
    saveToFile(`${safeName}.txt`, `错误: ${error.message}`);
    return { test: testName, source, papers: 0, success: false, error: error.message };
  }
}

async function generateReport(allResults) {
  console.log('\n📊 生成最终报告...');
  
  const report = {
    timestamp: new Date().toISOString(),
    output_dir: OUTPUT_DIR,
    pdf_dir: PDF_DIR,
    results: allResults,
    summary: {
      total_tests: allResults.length,
      successful_tests: allResults.filter(r => r.success).length,
      total_papers: allResults.reduce((sum, r) => sum + r.papers, 0),
      total_pdfs_downloaded: 0
    }
  };
  
  // 检查PDF文件
  if (fs.existsSync(PDF_DIR)) {
    const pdfFiles = fs.readdirSync(PDF_DIR).filter(f => f.endsWith('.pdf') && fs.statSync(path.join(PDF_DIR, f)).size > 0);
    report.files = {
      pdf: pdfFiles.map(f => {
        const stats = fs.statSync(path.join(PDF_DIR, f));
        return { name: f, size_kb: parseFloat((stats.size / 1024).toFixed(1)) };
      }),
      txt: fs.readdirSync(OUTPUT_DIR).filter(f => f.endsWith('.txt')).map(f => {
        const stats = fs.statSync(path.join(OUTPUT_DIR, f));
        return { name: f, size_kb: parseFloat((stats.size / 1024).toFixed(1)) };
      }),
      json: fs.readdirSync(OUTPUT_DIR).filter(f => f.endsWith('.json') && f !== 'final_report.json').map(f => {
        const stats = fs.statSync(path.join(OUTPUT_DIR, f));
        return { name: f, size_kb: parseFloat((stats.size / 1024).toFixed(1)) };
      })
    };
    report.summary.total_pdfs_downloaded = pdfFiles.length;
  }
  
  saveJSON('final_report.json', report);
  
  console.log('\n' + '='.repeat(80));
  console.log('✅ 全文获取 + PDF下载测试完成！');
  console.log('='.repeat(80));
  console.log(`\n📊 测试结果摘要:`);
  console.log(`   总测试数: ${report.summary.total_tests}`);
  console.log(`   成功测试: ${report.summary.successful_tests}`);
  console.log(`   获取论文: ${report.summary.total_papers} 篇`);
  console.log(`   下载PDF: ${report.summary.total_pdfs_downloaded} 个`);
  console.log(`\n📂 输出目录: ${OUTPUT_DIR}`);
  console.log(`📂 PDF目录: ${PDF_DIR}`);
  
  if (report.files) {
    console.log(`\n📄 文本文件 (${report.files.txt.length}个):`);
    report.files.txt.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
    console.log(`\n📄 JSON文件 (${report.files.json.length}个):`);
    report.files.json.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
    console.log(`\n📕 PDF文件 (${report.files.pdf.length}个):`);
    report.files.pdf.forEach(f => console.log(`   - ${f.name} (${f.size_kb} KB)`));
  }
  
  console.log('\n📊 详细报告: output/final_report.json');
}

async function runAllTests() {
  console.log('🚀 开始综合测试 - 获取全文 + 下载PDF');
  console.log(`📁 输出目录: ${OUTPUT_DIR}`);
  console.log(`📁 PDF目录: ${PDF_DIR}`);
  console.log('');
  
  const results = [];
  
  // Test 1: arXiv Machine Learning
  results.push(await runTest('arXiv - Machine Learning Search', 'arxiv', 'machine learning', false, 2));
  
  // Test 2: arXiv Latest AI (with delay for rate limit)
  await new Promise(r => setTimeout(r, 5000));
  results.push(await runTest('arXiv - Latest AI Papers', 'arxiv', 'cs.AI', true, 2));
  
  // Test 3: arXiv Physics
  await new Promise(r => setTimeout(r, 3000));
  results.push(await runTest('arXiv - Quantum Computing Search', 'arxiv', 'quantum computing', false, 2));
  
  // Test 4: Europe PMC
  await new Promise(r => setTimeout(r, 3000));
  results.push(await runTest('EuropePMC - Cancer Research', 'europepmc', 'cancer', false, 2));
  
  // Test 5: OpenAlex
  await new Promise(r => setTimeout(r, 3000));
  results.push(await runTest('OpenAlex - Artificial Intelligence', 'openalex', 'artificial intelligence', false, 2));
  
  await generateReport(results);
}

runAllTests().catch(console.error);
