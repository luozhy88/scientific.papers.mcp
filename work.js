
// ====================================================================
// Cloudflare 文献抓取 SaaS 平台 (全栈整合版)
// 版本: v5.0.0-SaaS-Pro (主页与管理员页面分离)
// ====================================================================

const SCRIPT_VERSION = "v5.0.0-SaaS-Pro";

const SYSTEM_CONFIG = {
  // 🔴 你的 Google Apps Script Webhook URL (核心转发引擎)
  googleScriptUrl: "https://script.google.com/macros/s/AKfycbwG7DsrfDCvRQ9uTHAmpx1u_yrcwvUUtTO0D7M-X-46WYDuxmmosp1l6QPGTYuY3vvk/exec",
  adminEmail: "479321347@qq.com",
  semanticScholarApiKey: ""
};

// ── 工具函数 ───────────────────────────────────────────────────────────
function sanitizeRaw(str) {
  if (!str || typeof str !== 'string') return '';
  let cleanStr = str.replace(/<[^>]+>/g, '').replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').replace(/&amp;/gi, '&').replace(/&quot;/gi, '"').replace(/&#39;/gi, "'").replace(/&apos;/gi, "'");
  return cleanStr.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '').trim();
}

function escHtml(str) {
  if (!str) return '';
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function getFullAbstract(str) {
  if (!str || str.trim() === '') return '暂无摘要 (No abstract available).';
  return str;
}

async function requestAPI(url, customHeaders = {}) {
  const response = await fetch(url, {
    headers: { 'User-Agent': 'CloudflareWorker/1.0 SaaS-Platform', 'Accept': 'application/json', ...customHeaders }
  });
  if (!response.ok) throw new Error(`API HTTP Error: ${response.status}`);
  return response.json();
}

function getBeijingTimeString() {
  const now = new Date();
  return new Date(now.getTime() + 8 * 60 * 60 * 1000).toISOString().replace('T', ' ').substring(0, 19);
}

// ── 文献抓取逻辑 ──────────────────────────────────────────────────────
async function fetchAllPapers(userConfig) {
  const advanced = userConfig.advanced_settings ? JSON.parse(userConfig.advanced_settings) : {};
  const lookbackDays = advanced.lookbackDays || 30;
  const strictFilter = advanced.strictFilter !== false; 
  
  const getDaysAgo = (days) => {
    const d = new Date();
    d.setDate(d.getDate() - days);
    return d.toISOString().split('T')[0];
  };

  const dateFrom = getDaysAgo(lookbackDays);
  const query = userConfig.query_keywords;
  const countPerSource = (userConfig.count_per_source || 10) * (strictFilter ? 2 : 1); 

  async function fetchEuropePMC() {
    try {
      const q = `${query} AND (FIRST_PDATE:[${dateFrom} TO ${new Date().toISOString().split('T')[0]}])`;
      const url = `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=${encodeURIComponent(q)}&format=json&resultType=core&pageSize=${countPerSource}&sort=P_PDATE_D desc`;
      const data = await requestAPI(url);
      return (data.resultList?.result || []).map(item => ({
        id: item.doi ? `https://doi.org/${item.doi}` : `https://europepmc.org/article/MED/${item.pmcid}`,
        title: sanitizeRaw(item.title),
        authors: sanitizeRaw(item.authorString),
        date: item.firstPublicationDate,
        abstract: sanitizeRaw(item.abstractText),
        source: 'EuropePMC'
      }));
    } catch (e) { return []; }
  }

  async function fetchSS() {
    try {
      const url = `https://api.semanticscholar.org/graph/v1/paper/search?query=${encodeURIComponent(query)}&limit=${countPerSource}&fields=title,abstract,tldr,authors,publicationDate,externalIds,url`;
      const data = await requestAPI(url);
      return (data.data || []).map(item => ({
        id: item.externalIds?.DOI ? `https://doi.org/${item.externalIds.DOI}` : item.url,
        title: sanitizeRaw(item.title),
        authors: (item.authors || []).map(a => a.name).join(', '),
        date: item.publicationDate,
        abstract: sanitizeRaw(item.abstract || item.tldr?.text),
        source: 'SemanticScholar'
      }));
    } catch (e) { return []; }
  }

  const results = await Promise.all([fetchEuropePMC(), fetchSS()]);
  const all = results.flat();
  const seen = new Set();
  
  let final = all.filter(p => {
    if(!p.title || seen.has(p.title.toLowerCase())) return false;
    seen.add(p.title.toLowerCase());
    return true;
  });

  if (strictFilter) {
    const exactMatches = (query.match(/"([^"]+)"/g) || []).map(m => m.replace(/"/g, '').toLowerCase());
    const otherWords = query.replace(/"([^"]+)"/g, '')
                            .replace(/\b(AND|OR|NOT)\b/ig, ' ')
                            .replace(/[\(\)]/g, ' ')
                            .split(/\s+/)
                            .filter(w => w.trim().length > 2)
                            .map(w => w.toLowerCase());
                            
    const checkTerms = [...exactMatches, ...otherWords];

    if (checkTerms.length > 0) {
      final = final.filter(p => {
        const contentToSearch = (p.title + ' ' + p.abstract).toLowerCase();
        return checkTerms.some(term => contentToSearch.includes(term));
      });
    }
  }

  final = final.sort((a, b) => new Date(b.date) - new Date(a.date))
               .slice(0, userConfig.count_per_source || 10);

  return final;
}

// ── 邮件发送逻辑 ──────────────────────────────────────────────────────
async function sendEmail(env, papers, userConfig) {
  const displayTopic = userConfig.topic_name || "文献追踪报告";
  const displayQuery = userConfig.query_keywords || "未指定关键词";
  const count = papers.length;
  const sendTime = getBeijingTimeString();
  
  const advanced = userConfig.advanced_settings ? JSON.parse(userConfig.advanced_settings) : {};
  const lookbackDays = advanced.lookbackDays || 30;
  const intervalDisplay = userConfig.interval_days === '单次' ? '单次执行 (未订阅)' : `每隔 ${userConfig.interval_days} 天`;

  let html = `
    <div style="font-family:sans-serif; max-width:650px; border:1px solid #eee; border-radius:10px; overflow:hidden; margin: 0 auto;">
      <div style="background:#4f46e5; color:white; padding:20px;">
        <h2 style="margin:0;">文献追踪报告: ${displayTopic}</h2>
        <p style="margin:8px 0 0; opacity:0.9; font-size:13px;"><strong>检索关键词:</strong> ${displayQuery}</p>
        <p style="margin:5px 0 0; opacity:0.8; font-size:12px;">推送频率: ${intervalDisplay} | 检索范围: 过去 ${lookbackDays} 天 | 找到 ${count} 篇</p>
        <p style="margin:5px 0 0; opacity:0.8; font-size:12px;">发送时间: ${sendTime} (北京时间) | 版本: ${SCRIPT_VERSION}</p>
      </div>
      <div style="padding:20px; background:#fcfcfc;">
  `;

  if (count === 0) {
    html += `<p style="color:#666;">本周期内暂未发现符合条件的最新相关文献 (已开启深度摘要过滤)。</p>`;
  } else {
    html += papers.map((p, i) => `
      <div style="margin-bottom:25px; padding-bottom:20px; border-bottom:1px solid #e2e8f0;">
        <div style="font-weight:bold; color:#1e293b; font-size:15px; margin-bottom:5px;">[${i+1}] ${p.title}</div>
        <div style="font-size:12px; color:#64748b; margin:6px 0;"><strong>Date:</strong> ${p.date} &nbsp;|&nbsp; <strong>Source:</strong> ${p.source} &nbsp;|&nbsp; <strong>Authors:</strong> ${p.authors}</div>
        <div style="font-size:13px; color:#334155; line-height:1.6; margin:10px 0; background-color:#f1f5f9; padding:12px; border-radius:6px; border-left: 4px solid #cbd5e1;">
          <strong>Abstract:</strong><br>
          ${getFullAbstract(p.abstract)}
        </div>
        <a href="${p.id}" target="_blank" style="display:inline-block; background:#eff6ff; color:#2563eb; font-size:13px; font-weight:bold; padding:6px 12px; border-radius:4px; text-decoration:none; margin-top:5px;">🔗 查看原文 (Read Paper)</a>
      </div>
    `).join('');
  }

  html += `</div><div style="background:#f1f5f9; padding:15px; text-align:center; font-size:11px; color:#94a3b8;">
    此邮件由科研追踪助手自动发出。<br>
    当前执行版本: ${SCRIPT_VERSION}
  </div></div>`;

  const payload = {
    to: userConfig.client_email,
    fromName: "科研追踪助手",
    subject: `[文献报告] ${displayTopic} (${count}篇) - ${new Date().toLocaleDateString()}`,
    html: html
  };

  const res = await fetch(SYSTEM_CONFIG.googleScriptUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  
  if (!res.ok) throw new Error("Google Webhook 响应异常");
  const result = await res.json();
  if (!result.success) throw new Error(result.error);
}

// ── 核心扫描引擎 ──────────────────────────────────────────────────────
async function executeScheduledTask(env) {
  let logOutput = `[${getBeijingTimeString()}] 🚀 启动任务扫描...\n`;
  try {
    const query = `SELECT * FROM subscriptions WHERE status = 'active' AND (last_sent_date IS NULL OR julianday('now') - julianday(last_sent_date) >= interval_days)`;
    const { results } = await env.DB.prepare(query).all();
    
    logOutput += `找到 ${results.length} 条待处理任务。\n`;

    for (const user of results) {
      logOutput += `> 正在处理: ${user.client_email}... `;
      try {
        const papers = await fetchAllPapers(user);
        await sendEmail(env, papers, user);
        
        try {
          await env.DB.prepare(`
            UPDATE subscriptions 
            SET last_sent_date = datetime('now'), 
                send_count = IFNULL(send_count, 0) + 1 
            WHERE id = ?
          `).bind(user.id).run();
          logOutput += `✅ 成功发送\n`;
        } catch (dbErr) {
          await env.DB.prepare(`UPDATE subscriptions SET last_sent_date = datetime('now') WHERE id = ?`).bind(user.id).run();
          logOutput += `✅ 成功发送 (但计数失败，请点击网页上的"修复数据库")\n`;
        }
      } catch (e) {
        await env.DB.prepare(`UPDATE subscriptions SET last_sent_date = datetime('now') WHERE id = ?`).bind(user.id).run();
        logOutput += `❌ 失败: ${e.message}\n`;
      }
    }
    return logOutput + `扫描结束。`;
  } catch (error) { 
    return logOutput + `⚠️ 全局错误: ${error.message}`;
  }
}

// ── HTML 模板渲染函数 ─────────────────────────────────────────────────
function renderHTML(isAdmin) {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>${isAdmin ? '【管理后台】' : ''}文献追踪系统 Pro v5.0.0</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 p-4 md:p-10 font-sans text-sm">
  <div class="max-w-6xl mx-auto space-y-6">
    
    <!-- 头部工具栏 -->
    <div class="flex justify-between items-center bg-white p-4 rounded-2xl shadow-sm border border-orange-100">
      <div class="flex items-center gap-3">
        <span class="text-orange-500 font-bold">⚠️ 数据库同步状态:</span>
        <span class="text-gray-600 text-xs">自动抓取引擎运行中...</span>
      </div>
      ${isAdmin ? `<button onclick="repairDB()" class="bg-orange-500 text-white px-4 py-2 rounded-xl text-xs font-bold hover:bg-orange-600 transition shadow-md shadow-orange-100">🔧 一键修复数据库</button>` : `<span class="text-gray-400 text-xs font-bold bg-gray-100 px-3 py-1 rounded">普通用户模式</span>`}
    </div>

    <!-- 🌟 关键词搜索指南与技巧面板 🌟 -->
    <div class="bg-blue-50 rounded-2xl p-5 border border-blue-100 text-blue-900 shadow-sm">
      <h3 class="font-bold text-lg mb-2 flex items-center gap-2">
        <span>💡</span> 高效检索指南 (Search Tips)
      </h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
        <div>
          <p class="mb-1"><span class="font-bold bg-blue-200 px-1 rounded">精准匹配:</span> 使用双引号包含词组。</p>
          <code class="bg-white px-2 py-1 rounded text-blue-700 block mb-2">"Gut microbiota"</code>
          <p class="mb-1"><span class="font-bold bg-blue-200 px-1 rounded">组合条件:</span> 使用 AND (与) / OR (或) 连接。</p>
          <code class="bg-white px-2 py-1 rounded text-blue-700 block">"Lung Cancer" AND (biomarker OR therapy)</code>
        </div>
        <div class="bg-white p-3 rounded-xl shadow-sm border border-blue-100">
          <p class="font-bold text-red-500 mb-1">⚠️ 关于中文关键词输入</p>
          <p class="text-gray-600 mb-2">国际数据库 (EuropePMC/SemanticScholar) 均为英文文献。直接输入中文通常会搜不到结果。请尽量输入英文关键词。</p>
          <p class="text-gray-600">您可以在下方输入中文，然后点击 <b>"中译英"</b> 按钮进行一键转换！</p>
        </div>
      </div>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border p-6 border-indigo-100">
      <h2 class="text-xl font-bold text-gray-800 mb-4 flex items-center gap-2">🚀 文献追踪任务建立</h2>
      
      <form id="f" class="grid grid-cols-1 md:grid-cols-12 gap-4 items-start">
        <div class="flex flex-col gap-1 md:col-span-3">
          <label class="text-xs font-bold text-gray-500 pl-1">接收邮箱</label>
          <input type="email" id="e" required value="479321347@qq.com" class="p-3 border rounded-xl bg-gray-50 focus:bg-white outline-none ring-indigo-500 focus:ring-2 transition-all">
        </div>
        
        <div class="flex flex-col gap-1 md:col-span-3">
          <label class="text-xs font-bold text-gray-500 pl-1">主题名称</label>
          <input type="text" id="t" required value="科研前沿追踪" class="p-3 border rounded-xl bg-gray-50 focus:bg-white outline-none ring-indigo-500 focus:ring-2">
        </div>
        
        <div class="flex flex-col gap-1 md:col-span-6">
          <label class="text-xs font-bold text-gray-500 pl-1">检索关键词 (英文更准)</label>
          <div class="flex gap-2">
            <input type="text" id="q" placeholder='例如: "Deep Learning" AND healthcare' required value='"Gut microbiota"' class="p-3 border rounded-xl bg-gray-50 focus:bg-white outline-none ring-indigo-500 focus:ring-2 flex-1">
            <button type="button" onclick="translateToEnglish()" class="bg-blue-100 text-blue-700 px-4 rounded-xl font-bold hover:bg-blue-200 transition whitespace-nowrap" id="transBtn">🌐 中译英</button>
          </div>
        </div>

        <div class="flex flex-col gap-1 md:col-span-3">
          <label class="text-xs font-bold text-gray-500 pl-1">推送频率</label>
          <select id="fr" class="p-3 border rounded-xl bg-gray-50 outline-none ring-indigo-500 focus:ring-2">
            <option value="0" class="font-bold text-indigo-600">⚡ 仅执行一次 (即刻发送,不订阅)</option>
            <option value="0.00347">每隔 5 分钟 (仅供测试)</option>
            <option value="0.04167">每隔 1 小时 (仅供测试)</option>
            <option value="1" selected>每隔 1 天</option>
            <option value="3">每隔 3 天</option>
            <option value="7">每隔 7 天</option>
          </select>
        </div>

        <div class="flex flex-col gap-1 md:col-span-3">
          <label class="text-xs font-bold text-gray-500 pl-1">检索范围 (天数)</label>
          <select id="l" class="p-3 border rounded-xl bg-gray-50 outline-none ring-indigo-500 focus:ring-2">
            <option value="10">过去 10 天</option>
            <option value="30" selected>过去 30 天</option>
            <option value="100">过去 100 天</option>
            <option value="360">过去 360 天</option>
            <option value="800">过去 800 天</option>
          </select>
        </div>

        <div class="flex flex-col gap-1 md:col-span-2">
          <label class="text-xs font-bold text-gray-500 pl-1">单次展示篇数</label>
          <input type="number" id="c" value="10" min="1" max="50" class="p-3 border rounded-xl bg-gray-50 outline-none ring-indigo-500 focus:ring-2">
        </div>

        <div class="flex flex-col gap-1 md:col-span-4 justify-end h-full">
          <div class="flex items-center gap-2 mb-2 pl-1">
            <input type="checkbox" id="strictFilter" checked class="w-4 h-4 text-indigo-600 rounded cursor-pointer">
            <label for="strictFilter" class="text-[11px] text-indigo-600 font-bold cursor-pointer leading-tight">开启深度过滤 (标题或摘要须含检索词)</label>
          </div>
          <button type="submit" class="bg-indigo-600 text-white font-bold p-3 rounded-xl hover:bg-indigo-700 transition shadow-lg shadow-indigo-100 w-full mt-auto">✚ 建立 / 执行任务</button>
        </div>
      </form>
    </div>

    <!-- 监控面板 -->
    <div class="bg-slate-900 rounded-2xl shadow-2xl p-6 text-white overflow-hidden border border-slate-800">
      <div class="flex justify-between items-center mb-6">
        <div>
          <h3 class="text-indigo-400 font-bold text-lg">${isAdmin ? '系统监控面板 (管理员)' : '公开订阅列表'}</h3>
          <p class="text-slate-500 text-[10px]">所有时间均显示为 <b>北京时间 (Beijing Time)</b></p>
        </div>
        <div class="flex gap-2">
          <button onclick="load()" class="text-[10px] bg-slate-800 px-4 py-2 rounded-lg hover:bg-slate-700 border border-slate-700 transition">🔄 刷新列表</button>
          ${isAdmin ? `<button onclick="test()" class="text-[10px] bg-emerald-600 px-4 py-2 rounded-lg hover:bg-emerald-500 transition">⚡ 扫描全部长期订阅</button>` : ''}
        </div>
      </div>

      <div id="log" class="bg-black/40 p-3 rounded-xl mb-6 text-[10px] font-mono text-emerald-500 max-h-32 overflow-y-auto whitespace-pre border border-slate-800">就绪...</div>

      <div class="overflow-x-auto">
        <table class="w-full text-left text-[11px] font-mono">
          <thead class="text-slate-500 bg-slate-800/50">
            <tr>
              <th class="p-3">主题 / 邮箱</th>
              <th class="p-3">检索关键词</th>
              <th class="p-3 text-center">成功次数</th>
              <th class="p-3 text-center">频率</th>
              <th class="p-3">上次执行 (北京)</th>
              <th class="p-3">预计下次执行</th>
              ${isAdmin ? `<th class="p-3 text-center">操作</th>` : ''}
            </tr>
          </thead>
          <tbody id="tb" class="divide-y divide-slate-800"></tbody>
        </table>
      </div>
    </div>
  </div>

  <script>
    // 智能中译英函数
    async function translateToEnglish() {
      const input = document.getElementById('q');
      const btn = document.getElementById('transBtn');
      const text = input.value.trim();
      
      if (!text) return alert("请先输入关键词！");
      
      if (!/[\\u4e00-\\u9fa5]/.test(text)) {
        return alert("您输入的已经是英文或不包含中文，无需翻译。");
      }

      const originalBtnText = btn.innerText;
      btn.innerText = "翻译中...";
      btn.disabled = true;

      try {
        const res = await fetch(\`https://api.mymemory.translated.net/get?q=\${encodeURIComponent(text)}&langpair=zh|en\`);
        const data = await res.json();
        
        if (data && data.responseData && data.responseData.translatedText) {
          input.value = data.responseData.translatedText;
          input.classList.add('ring-4', 'ring-green-400');
          setTimeout(() => input.classList.remove('ring-4', 'ring-green-400'), 1000);
        } else {
          alert("翻译接口异常，请手动修改为英文。");
        }
      } catch (err) {
        alert("翻译请求失败，请手动输入英文。");
      } finally {
        btn.innerText = originalBtnText;
        btn.disabled = false;
      }
    }

    const fmt = (s) => {
      if(!s) return '从未执行';
      const date = new Date(s.replace(' ', 'T') + 'Z'); 
      return date.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false });
    };

    const calcNext = (last, freq) => {
      if(!last) return '立即执行';
      const lastDate = new Date(last.replace(' ', 'T') + 'Z');
      const nextDate = new Date(lastDate.getTime() + freq * 86400000);
      return nextDate <= new Date() ? '🚀 即将推送' : nextDate.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false });
    };

    async function load() {
      const res = await fetch('/api/users?_t=' + Date.now());
      const data = await res.json();
      document.getElementById('tb').innerHTML = data.map(u => {
        const actionBtnStr = ${isAdmin} ? \`<td class="p-3 text-center"><button onclick="del(\${u.id})" class="bg-red-900/20 text-red-500 px-2 py-1 rounded hover:bg-red-900/40 transition">删除</button></td>\` : '';
        return \`
          <tr class="hover:bg-indigo-500/5 transition">
            <td class="p-3">
              <div class="text-indigo-400 font-bold text-sm">#\${u.id} \${u.topic_name}</div>
              <div class="text-slate-500 text-[9px] font-sans">\${u.client_email}</div>
            </td>
            <td class="p-3">
              <div class="text-slate-400 max-w-[180px] break-words" title='\${u.query_keywords}'>\${u.query_keywords}</div>
            </td>
            <td class="p-3 text-emerald-400 font-bold text-center text-sm">\${u.send_count || 0}</td>
            <td class="p-3 text-slate-400 text-center">\${u.interval_days}天</td>
            <td class="p-3 text-slate-300">\${fmt(u.last_sent_date)}</td>
            <td class="p-3 text-indigo-300 font-bold">\${calcNext(u.last_sent_date, u.interval_days)}</td>
            \${actionBtnStr}
          </tr>
        \`;
      }).join('');
    }

    // 这些函数仅在前端被点击时触发，普通用户页面因为没有入口按钮所以不会调用
    async function repairDB() {
      const res = await fetch('/api/setup');
      alert(await res.text());
      load();
    }

    async function test() {
      const l = document.getElementById('log');
      l.innerText = '正在执行全库扫描与文献推送...';
      const res = await fetch('/debug-cron?_t=' + Date.now());
      l.innerText = await res.text();
      load();
    }

    async function del(id) {
      if(!confirm('确定永久删除该追踪任务吗？')) return;
      await fetch('/api/delete?id=' + id);
      load();
    }

    document.getElementById('f').onsubmit = async (e) => {
      e.preventDefault();
      
      const q = document.getElementById('q').value;
      if (/[\\u4e00-\\u9fa5]/.test(q)) {
        if (!confirm("⚠️ 您的关键词中包含中文，这可能导致抓取不到国际文献数据。\\n\\n建议点击【取消】，使用【中译英】功能将其转换为英文后再提交。\\n\\n是否无视警告强制提交？")) {
           return;
        }
      }

      const frequencyDays = parseFloat(document.getElementById('fr').value);
      const isRunOnce = frequencyDays === 0;

      const submitBtn = e.target.querySelector('button[type="submit"]');
      submitBtn.innerText = isRunOnce ? "⚡ 正在抓取并发送邮件..." : "提交保存中...";
      submitBtn.disabled = true;

      try {
        const res = await fetch('/api/subscribe', {
          method: 'POST',
          body: JSON.stringify({
            clientEmail: document.getElementById('e').value,
            topicName: document.getElementById('t').value,
            query: document.getElementById('q').value,
            countPerSource: parseInt(document.getElementById('c').value),
            frequencyDays: frequencyDays,
            lookbackDays: parseInt(document.getElementById('l').value),
            strictFilter: document.getElementById('strictFilter').checked
          })
        });
        
        const data = await res.json();
        if (!res.ok || data.error) throw new Error(data.error || '请求异常');

        if (isRunOnce) {
            alert("⚡ 单次抓取已完成，您的报告已发送至邮箱，请查收！(未写入数据库)");
        } else {
            alert("✅ 长期订阅任务建立成功！");
            document.getElementById('q').value = ''; 
        }
        
        load();
      } catch (err) {
        alert("执行失败：" + err.message);
      } finally {
        submitBtn.innerText = "✚ 建立 / 执行任务";
        submitBtn.disabled = false;
      }
    };

    load();
  </script>
</body>
</html>`;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Cache-Control": "no-cache, no-store, must-revalidate"
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

    // 🛡️ 提取鉴权逻辑：验证是否为管理员 (账号: sanshu, 密码: sanshu123456)
    const checkAdminAuth = () => {
      const authHeader = request.headers.get('Authorization');
      return authHeader === 'Basic ' + btoa('sanshu:sanshu123456');
    };

    if (request.method === 'POST' && url.pathname === '/api/subscribe') {
      try {
        const data = await request.json();
        const advanced = JSON.stringify({ ...data.advancedSettings, lookbackDays: data.lookbackDays, strictFilter: data.strictFilter });
        
        // 🌟 核心处理：单次执行模式拦截 🌟
        if (data.frequencyDays === 0) {
          const mockConfig = {
            client_email: data.clientEmail,
            topic_name: data.topicName,
            query_keywords: data.query,
            count_per_source: data.countPerSource,
            interval_days: '单次',
            advanced_settings: advanced
          };
          
          try {
            const papers = await fetchAllPapers(mockConfig);
            await sendEmail(env, papers, mockConfig);
            return new Response(JSON.stringify({ success: true, isRunOnce: true }), { headers: corsHeaders });
          } catch (err) {
            return new Response(JSON.stringify({ error: "单次抓取/发送失败: " + err.message }), { status: 500, headers: corsHeaders });
          }
        }

        // 常规的长期订阅保存逻辑
        try {
           await env.DB.prepare(`
            INSERT INTO subscriptions (client_email, topic_name, query_keywords, count_per_source, interval_days, advanced_settings, send_count)
            VALUES (?, ?, ?, ?, ?, ?, 0)
          `).bind(data.clientEmail, data.topicName, data.query, data.countPerSource, data.frequencyDays, advanced).run();
        } catch (e) {
           await env.DB.prepare(`
            INSERT INTO subscriptions (client_email, topic_name, query_keywords, count_per_source, interval_days, advanced_settings)
            VALUES (?, ?, ?, ?, ?, ?)
          `).bind(data.clientEmail, data.topicName, data.query, data.countPerSource, data.frequencyDays, advanced).run();
        }
        return new Response(JSON.stringify({ success: true, isRunOnce: false }), { headers: corsHeaders });
      } catch (error) { return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders }); }
    }

    if (url.pathname === '/api/users') {
      const { results } = await env.DB.prepare("SELECT * FROM subscriptions ORDER BY id DESC").all();
      return new Response(JSON.stringify(results), { headers: corsHeaders });
    }

    if (url.pathname === '/api/delete') {
      if (!checkAdminAuth()) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: corsHeaders });
      const id = url.searchParams.get('id');
      await env.DB.prepare("DELETE FROM subscriptions WHERE id = ?").bind(id).run();
      return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
    }

    if (url.pathname === '/api/setup') {
      if (!checkAdminAuth()) return new Response("Unauthorized", { status: 401, headers: corsHeaders });
      try {
        await env.DB.prepare("ALTER TABLE subscriptions ADD COLUMN send_count INTEGER DEFAULT 0;").run();
        return new Response("数据库升级成功！send_count 列已添加。", { headers: corsHeaders });
      } catch (e) {
        return new Response("升级失败或列已存在: " + e.message, { headers: corsHeaders });
      }
    }

    if (url.pathname === '/debug-cron') {
      if (!checkAdminAuth()) return new Response("Unauthorized", { status: 401, headers: corsHeaders });
      const msg = await executeScheduledTask(env);
      return new Response(msg, { headers: corsHeaders });
    }

    // 🔴 路由页面分离与鉴权 🔴
    // 如果访问 /admin 路径，则要求输入账号密码，验证通过才渲染管理员页面
    if (url.pathname === '/admin') {
      if (!checkAdminAuth()) {
        return new Response('需要管理员账号和密码才能访问', {
          status: 401,
          headers: {
            'WWW-Authenticate': 'Basic realm="Admin Login Area"',
            'Content-Type': 'text/plain;charset=UTF-8'
          }
        });
      }
      return new Response(renderHTML(true), { headers: { 'Content-Type': 'text/html;charset=UTF-8' } });
    }

    // 默认主页 / ，渲染无删除权限的纯净页面
    return new Response(renderHTML(false), { headers: { 'Content-Type': 'text/html;charset=UTF-8' } });
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(executeScheduledTask(env));
  }
};
