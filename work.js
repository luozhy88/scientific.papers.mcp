
var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// worker.js
var SCRIPT_VERSION = "v5.9.0-Secure";
var SYSTEM_CONFIG = {
  // 🔴 你的 Google Apps Script Webhook URL
  googleScriptUrl: "https://script.google.com/macros/s/AKfycbwG7DsrfDCvRQ9uTHAmpx1u_yrcwvUUtTO0D7M-X-46WYDuxmmosp1l6QPGTYuY3vvk/exec",
  adminEmail: "479321347@qq.com",
  // 🔴 你的 Gemini API Key (填在这里安全隔离，不会暴露给前端网页)
  geminiApiKey: "AIzaSyCAU5UZimWuy3ZX-a9G7au8ZtXUB84WeDs"
};
function sanitizeRaw(str) {
  if (!str || typeof str !== "string") return "";
  let cleanStr = str.replace(/<[^>]+>/g, "").replace(/&lt;/gi, "<").replace(/&gt;/gi, ">").replace(/&amp;/gi, "&").replace(/&quot;/gi, '"').replace(/&#39;/gi, "'").replace(/&apos;/gi, "'");
  return cleanStr.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "").trim();
}
__name(sanitizeRaw, "sanitizeRaw");
function getFullAbstract(str) {
  return !str || str.trim() === "" ? "\u6682\u65E0\u6458\u8981 (No abstract available)." : str;
}
__name(getFullAbstract, "getFullAbstract");
async function requestAPI(url, customHeaders = {}) {
  const response = await fetch(url, {
    headers: { "User-Agent": "CloudflareWorker/1.0 SaaS-Platform", "Accept": "application/json", ...customHeaders }
  });
  if (!response.ok) throw new Error(`API HTTP Error: ${response.status}`);
  return response.json();
}
__name(requestAPI, "requestAPI");
function getBeijingTimeString() {
  const now = /* @__PURE__ */ new Date();
  return new Date(now.getTime() + 8 * 60 * 60 * 1e3).toISOString().replace("T", " ").substring(0, 19);
}
__name(getBeijingTimeString, "getBeijingTimeString");
async function translateBatchZH(texts) {
  if (!texts || texts.length === 0) return [];
  const DELIMITER = "\n\n9988776655\n\n";
  const results = [];
  const CHUNK_SIZE = 10;
  for (let i = 0; i < texts.length; i += CHUNK_SIZE) {
    const chunk = texts.slice(i, i + CHUNK_SIZE);
    const combinedText = chunk.join(DELIMITER);
    try {
      const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-CN&dt=t`;
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ q: combinedText }).toString()
      });
      const data = await response.json();
      const translatedCombined = data[0].map((item) => item[0]).join("");
      const translatedChunk = translatedCombined.split(/9988776655/).map((s) => s.trim());
      if (translatedChunk.length >= chunk.length) {
        results.push(...translatedChunk.slice(0, chunk.length));
      } else {
        results.push(...chunk.map(() => "\u26A0\uFE0F \u7FFB\u8BD1\u89E3\u6790\u5F02\u5E38"));
      }
    } catch (e) {
      results.push(...chunk.map(() => "\u26A0\uFE0F \u7FFB\u8BD1\u670D\u52A1\u4E0D\u53EF\u7528"));
    }
  }
  return results;
}
__name(translateBatchZH, "translateBatchZH");
async function fetchAllPapers(userConfig) {
  const advanced = userConfig.advanced_settings ? JSON.parse(userConfig.advanced_settings) : {};
  const lookbackDays = advanced.lookbackDays || 30;
  const strictFilter = advanced.strictFilter !== false;
  const enableTranslate = advanced.enableTranslate !== false;
  const dateFrom = lookbackDays >= 9999 ? "1900-01-01" : new Date(Date.now() - lookbackDays * 864e5).toISOString().split("T")[0];
  const query = userConfig.query_keywords;
  const fetchLimit = strictFilter ? Math.max(150, (userConfig.count_per_source || 10) * 5) : userConfig.count_per_source || 10;
  async function fetchEuropePMC() {
    try {
      let q = query;
      let sortParam = lookbackDays < 9999 ? "&sort=P_PDATE_D desc" : "";
      if (lookbackDays < 9999) q = `(${query}) AND (FIRST_PDATE:[${dateFrom} TO ${(/* @__PURE__ */ new Date()).toISOString().split("T")[0]}])`;
      const url = `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=${encodeURIComponent(q)}&format=json&resultType=core&pageSize=${fetchLimit}${sortParam}`;
      const data = await requestAPI(url);
      return (data.resultList?.result || []).map((item) => ({
        id: item.doi ? `https://doi.org/${item.doi}` : `https://europepmc.org/article/MED/${item.pmcid}`,
        title: sanitizeRaw(item.title),
        authors: sanitizeRaw(item.authorString),
        date: item.firstPublicationDate,
        abstract: sanitizeRaw(item.abstractText),
        source: "EuropePMC"
      }));
    } catch (e) {
      return [];
    }
  }
  __name(fetchEuropePMC, "fetchEuropePMC");
  async function fetchSS() {
    try {
      let safeQuery = query.replace(/[()]/g, " ").replace(/\b(OR|AND|NOT)\b/gi, " ").replace(/\s+/g, " ").trim();
      if (!safeQuery || safeQuery.length < 3) safeQuery = "Camellia sinensis";
      const url = `https://api.semanticscholar.org/graph/v1/paper/search?query=${encodeURIComponent(safeQuery)}&limit=${fetchLimit}&fields=title,abstract,tldr,authors,publicationDate,externalIds,url`;
      const data = await requestAPI(url);
      return (data.data || []).map((item) => ({
        id: item.externalIds?.DOI ? `https://doi.org/${item.externalIds.DOI}` : item.url,
        title: sanitizeRaw(item.title),
        authors: (item.authors || []).map((a) => a.name).join(", "),
        date: item.publicationDate || "Unknown",
        abstract: sanitizeRaw(item.abstract || item.tldr?.text),
        source: "SemanticScholar"
      }));
    } catch (e) {
      return [];
    }
  }
  __name(fetchSS, "fetchSS");
  const results = await Promise.all([fetchEuropePMC(), fetchSS()]);
  let final = results.flat().filter((p, i, self) => p.title && i === self.findIndex((t) => t.title.toLowerCase() === p.title.toLowerCase()));
  if (strictFilter) {
    final = final.filter((p) => {
      const content = (p.title + " " + p.abstract).toLowerCase();
      let qStr = query;
      let orGroups = [], exactGroups = [];
      qStr = qStr.replace(/\(([^)]+)\)/g, (m, i) => {
        orGroups.push(i);
        return " _OR_ ";
      });
      qStr = qStr.replace(/"([^"]+)"/g, (m, i) => {
        exactGroups.push(i);
        return " _EX_ ";
      });
      let reqWords = qStr.replace(/\b(AND|NOT|the|in|of|for|with|on|at|to)\b/ig, " ").split(/\s+/).filter((w) => w.length > 2 && w !== "_OR_" && w !== "_EX_");
      if (!exactGroups.every((eg) => content.includes(eg.toLowerCase()))) return false;
      if (!reqWords.every((rw) => content.includes(rw.toLowerCase()))) return false;
      for (let og of orGroups) {
        let terms = og.split(/\bOR\b/i).map((t) => t.trim().replace(/"/g, "").toLowerCase()).filter((t) => t.length > 0);
        if (terms.length > 0 && !terms.some((t) => content.includes(t))) return false;
      }
      return true;
    });
  }
  final = final.sort((a, b) => (b.date === "Unknown" ? /* @__PURE__ */ new Date("1900") : new Date(b.date)) - (a.date === "Unknown" ? /* @__PURE__ */ new Date("1900") : new Date(a.date))).slice(0, userConfig.count_per_source || 10);
  if (enableTranslate) {
    const textsToTranslate = final.flatMap((p) => [p.title, p.abstract]);
    const translatedTexts = await translateBatchZH(textsToTranslate);
    final.forEach((p, i) => {
      p.titleZh = translatedTexts[i * 2] || "\u26A0\uFE0F \u7FFB\u8BD1\u5F02\u5E38";
      p.abstractZh = translatedTexts[i * 2 + 1] || "\u26A0\uFE0F \u7FFB\u8BD1\u5F02\u5E38";
    });
  }
  return final;
}
__name(fetchAllPapers, "fetchAllPapers");
async function sendEmail(env, papers, userConfig) {
  const displayTopic = userConfig.topic_name || "\u6587\u732E\u8FFD\u8E2A\u62A5\u544A";
  const displayQuery = userConfig.query_keywords || "\u672A\u6307\u5B9A\u5173\u952E\u8BCD";
  const count = papers.length;
  const advanced = userConfig.advanced_settings ? JSON.parse(userConfig.advanced_settings) : {};
  const lookbackStr = advanced.lookbackDays >= 9999 ? "\u5168\u5E93\u4E0D\u9650\u65F6" : `\u8FC7\u53BB ${advanced.lookbackDays || 30} \u5929`;
  const expandAbstract = advanced.expandAbstract === true;
  const enableTranslate = advanced.enableTranslate !== false;
  let html = `
    <div style="font-family:sans-serif; max-width:650px; border:1px solid #eee; border-radius:10px; margin: 0 auto;">
      <div style="background:#4f46e5; color:white; padding:20px;">
        <h2 style="margin:0;">\u6587\u732E\u8FFD\u8E2A\u62A5\u544A: ${displayTopic}</h2>
        <p style="margin:8px 0 0; opacity:0.9; font-size:13px;"><strong>\u68C0\u7D22\u5173\u952E\u8BCD:</strong> ${displayQuery}</p>
        <p style="margin:5px 0 0; opacity:0.8; font-size:12px;">\u8303\u56F4: ${lookbackStr} | \u627E\u5230 ${count} \u7BC7 | ${getBeijingTimeString()}</p>
      </div>
      <div id="top" style="padding:20px; background:#fcfcfc;">
  `;
  if (count === 0) {
    html += `<p style="color:#666;">\u672C\u5468\u671F\u5185\u6682\u672A\u53D1\u73B0\u7B26\u5408\u6761\u4EF6\u7684\u6700\u65B0\u76F8\u5173\u6587\u732E (\u5DF2\u5F00\u542F\u6DF1\u5EA6\u6458\u8981\u8FC7\u6EE4)\u3002</p>`;
  } else {
    html += `<div style="margin-bottom:25px; padding:15px; background:#e0e7ff; border-radius:8px; border:1px solid #c7d2fe;">
      <h3 style="margin-top:0; margin-bottom:10px; color:#3730a3; font-size:15px;">\u{1F4D1} \u672C\u671F\u6587\u732E\u5FEB\u901F\u5BFC\u822A</h3>
      <ul style="margin:0; padding-left:20px; font-size:13px; line-height:1.6;">`;
    papers.forEach((p, i) => {
      const displayTitle = enableTranslate && p.titleZh && !p.titleZh.includes("\u26A0\uFE0F") ? p.titleZh : p.title;
      html += `<li><a href="#paper-${i}" style="color:#4f46e5; text-decoration:none;">[${i + 1}] ${displayTitle}</a></li>`;
    });
    html += `</ul></div>`;
    html += papers.map((p, i) => `
      <div id="paper-${i}" style="margin-bottom:25px; padding-bottom:20px; border-bottom:1px solid #e2e8f0;">
        <div style="font-weight:bold; color:#1e293b; font-size:16px; margin-bottom:4px;">[${i + 1}] ${p.title}</div>
        ${enableTranslate && p.titleZh ? `<div style="font-weight:bold; color:#0369a1; font-size:14px; margin-bottom:8px;">${p.titleZh}</div>` : ""}
        <div style="font-size:12px; color:#64748b; margin:6px 0;"><strong>Date:</strong> ${p.date} &nbsp;|&nbsp; <strong>Source:</strong> ${p.source}</div>
        <div style="font-size:13px; color:#334155; line-height:1.6; margin:10px 0; background:#f1f5f9; padding:12px; border-radius:6px; border-left:4px solid #cbd5e1;">
          <details ${expandAbstract ? "open" : ""}>
            <summary style="cursor:pointer; color:#4338ca; font-weight:bold; outline:none;">\u{1F4D1} \u70B9\u51FB\u5C55\u5F00 / \u6298\u53E0\u6458\u8981 (Abstract)</summary>
            <div style="margin-top:12px; border-top:1px dashed #cbd5e1; padding-top:12px;">
              <strong style="color:#0f172a;">EN:</strong><div style="margin-bottom:12px;">${getFullAbstract(p.abstract)}</div>
              ${enableTranslate ? `<strong style="color:#0f172a;">ZH:</strong><div>${p.abstractZh || "\u65E0\u7FFB\u8BD1"}</div>` : ""}
            </div>
          </details>
        </div>
        <div style="margin-top:8px;">
          <a href="${p.id}" target="_blank" style="background:#eff6ff; color:#2563eb; font-size:13px; font-weight:bold; padding:6px 12px; border-radius:4px; text-decoration:none;">\u{1F517} \u67E5\u770B\u539F\u6587</a>
          <a href="#top" style="color:#94a3b8; font-size:12px; text-decoration:none; margin-left:15px;">\u2B06\uFE0F \u56DE\u5230\u9876\u90E8</a>
        </div>
      </div>`).join("");
  }
  html += `</div><div style="background:#f1f5f9; padding:15px; text-align:center; font-size:11px; color:#94a3b8;">\u6267\u884C\u7248\u672C: ${SCRIPT_VERSION}</div></div>`;
  const payload = { to: userConfig.client_email, fromName: "\u79D1\u7814\u8FFD\u8E2A\u52A9\u624B", subject: `[\u6587\u732E\u62A5\u544A] ${displayTopic} (${count}\u7BC7)`, html };
  const res = await fetch(SYSTEM_CONFIG.googleScriptUrl, { method: "POST", body: JSON.stringify(payload) });
  if (!res.ok) throw new Error("Webhook \u54CD\u5E94\u5F02\u5E38");
}
__name(sendEmail, "sendEmail");
async function executeScheduledTask(env) {
  let log = `[${getBeijingTimeString()}] \u{1F680} \u542F\u52A8\u626B\u63CF...
`;
  try {
    const { results } = await env.DB.prepare(`SELECT * FROM subscriptions WHERE status = 'active' AND (last_sent_date IS NULL OR julianday('now') - julianday(last_sent_date) >= interval_days)`).all();
    for (const u of results) {
      log += `> \u5904\u7406 ${u.client_email}... `;
      try {
        const papers = await fetchAllPapers(u);
        await sendEmail(env, papers, u);
        await env.DB.prepare(`UPDATE subscriptions SET last_sent_date = datetime('now'), send_count = IFNULL(send_count, 0) + 1 WHERE id = ?`).bind(u.id).run();
        log += `\u2705 \u53D1\u9001\u6210\u529F
`;
      } catch (e) {
        await env.DB.prepare(`UPDATE subscriptions SET last_sent_date = datetime('now') WHERE id = ?`).bind(u.id).run();
        log += `\u274C \u5931\u8D25: ${e.message}
`;
      }
    }
    return log + "\u626B\u63CF\u7ED3\u675F\u3002";
  } catch (err) {
    return log + "\u5168\u5C40\u9519\u8BEF: " + err.message;
  }
}
__name(executeScheduledTask, "executeScheduledTask");
function renderHTML(isAdmin) {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"><title>${isAdmin ? "\u3010\u7BA1\u7406\u540E\u53F0\u3011" : ""}\u6587\u732E\u8FFD\u8E2A\u7CFB\u7EDF Pro</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
</head>
<body class="bg-gray-100 p-4 md:p-10 font-sans text-sm">
  <div class="max-w-6xl mx-auto space-y-6">
    <div class="flex justify-between items-center bg-white p-4 rounded-2xl shadow-sm border border-indigo-100">
      <div class="flex items-center gap-3"><span class="text-indigo-600 font-bold">\u2728 AI \u540E\u7AEF\u5316\u5B89\u5168\u7248:</span><span class="text-gray-500 text-xs">\u81EA\u52A8\u6293\u53D6\u5F15\u64CE\u8FD0\u884C\u4E2D (\u9632\u622A\u65AD\u91CD\u6784)</span></div>
      ${isAdmin ? `<button onclick="repairDB()" class="bg-orange-500 text-white px-4 py-2 rounded-xl text-xs font-bold hover:bg-orange-600">\u{1F527} \u4FEE\u590D\u6570\u636E\u5E93</button>` : `<span class="bg-gray-100 px-3 py-1 rounded text-xs font-bold text-gray-400">\u7528\u6237\u6A21\u5F0F</span>`}
    </div>

    <div class="bg-white rounded-2xl shadow-sm border p-6 border-indigo-100">
      <h2 class="text-xl font-bold text-gray-800 mb-4">\u{1F680} \u6587\u732E\u8FFD\u8E2A\u4EFB\u52A1\u5EFA\u7ACB</h2>
      <form id="f" class="grid grid-cols-1 md:grid-cols-12 gap-4 items-start">
        <div class="flex flex-col gap-1 md:col-span-3"><label class="text-xs font-bold text-gray-500 pl-1">\u63A5\u6536\u90AE\u7BB1</label><input type="email" id="e" required value="479321347@qq.com" class="p-3 border rounded-xl bg-gray-50 focus:bg-white focus:ring-2 ring-indigo-500 outline-none"></div>
        <div class="flex flex-col gap-1 md:col-span-3"><label class="text-xs font-bold text-gray-500 pl-1">\u4E3B\u9898\u540D\u79F0</label><input type="text" id="t" required value="\u8336\u6811\u6839\u4E0E\u5FC3\u8840\u7BA1\u7814\u7A76" class="p-3 border rounded-xl bg-gray-50 focus:bg-white focus:ring-2 ring-indigo-500 outline-none"></div>
        <div class="flex flex-col gap-1 md:col-span-6">
          <label class="text-xs font-bold text-gray-500 pl-1">\u68C0\u7D22\u5173\u952E\u8BCD (\u76F4\u63A5\u8F93\u5165\u4E2D\u6587\u8BA9 AI \u7FFB\u8BD1)</label>
          <div class="flex gap-2">
            <input type="text" id="q" placeholder='\u4F8B\u5982: \u8336\u6811\u6839\u4E0E\u5FC3\u810F\u6CBB\u7597' required value='\u8336\u6811\u6839\u4E0E\u5FC3\u810F\u6CBB\u7597' class="p-3 border rounded-xl bg-gray-50 focus:bg-white focus:ring-2 ring-indigo-500 outline-none flex-1">
            <button type="button" onclick="translateToEnglish()" class="bg-purple-100 text-purple-700 px-4 rounded-xl font-bold hover:bg-purple-200" id="transBtn">\u{1F9E0} AI \u667A\u80FD\u8F6C\u8BD1</button>
          </div>
        </div>
        <div class="flex flex-col gap-1 md:col-span-3">
          <label class="text-xs font-bold text-gray-500 pl-1">\u63A8\u9001\u9891\u7387</label>
          <select id="fr" class="p-3 border rounded-xl bg-gray-50 focus:ring-2 ring-indigo-500 outline-none">
            <option value="0" class="font-bold text-indigo-600">\u26A1 \u4EC5\u6267\u884C\u4E00\u6B21 (\u5373\u523B\u53D1\u9001,\u4E0D\u8BA2\u9605)</option>
            <option value="0.00347222">\u6BCF 5 \u5206\u949F (\u6D4B\u8BD5\u7EA7)</option>
            <option value="1">\u6BCF\u9694 1 \u5929</option>
            <option value="2">\u6BCF\u9694 2 \u5929</option>
            <option value="3">\u6BCF\u9694 3 \u5929</option>
            <option value="4">\u6BCF\u9694 4 \u5929</option>
            <option value="5">\u6BCF\u9694 5 \u5929</option>
            <option value="7">\u6BCF\u9694 7 \u5929</option>
            <option value="17">\u6BCF\u9694 17 \u5929</option>
            <option value="30">\u6BCF\u9694 30 \u5929</option>
            <option value="60">\u6BCF\u9694 60 \u5929</option>
          </select>
        </div>
        <div class="flex flex-col gap-1 md:col-span-3">
          <label class="text-xs font-bold text-gray-500 pl-1">\u68C0\u7D22\u8303\u56F4</label>
          <select id="l" class="p-3 border rounded-xl bg-gray-50 focus:ring-2 ring-indigo-500 outline-none">
            <option value="1">\u8FC7\u53BB 1 \u5929</option>
            <option value="2">\u8FC7\u53BB 2 \u5929</option>
            <option value="3">\u8FC7\u53BB 3 \u5929</option>
            <option value="4">\u8FC7\u53BB 4 \u5929</option>
            <option value="5">\u8FC7\u53BB 5 \u5929</option>
            <option value="6">\u8FC7\u53BB 6 \u5929</option>
            <option value="7">\u8FC7\u53BB 7 \u5929</option>
            <option value="14">\u8FC7\u53BB 14 \u5929</option>
            <option value="28">\u8FC7\u53BB 28 \u5929</option>
            <option value="30">\u8FC7\u53BB 30 \u5929</option>
            <option value="60">\u8FC7\u53BB 60 \u5929 (2\u4E2A\u6708)</option>
            <option value="90">\u8FC7\u53BB 3 \u4E2A\u6708</option>
            <option value="180">\u8FC7\u53BB\u534A\u5E74 (180\u5929)</option>
            <option value="360">\u8FC7\u53BB 1 \u5E74</option>
            <option value="9999" class="font-bold text-red-600" selected>\u{1F525} \u4E0D\u9650\u65F6\u95F4 (\u5168\u5E93\u68C0\u7D22)</option>
          </select>
        </div>
        <div class="flex flex-col gap-1 md:col-span-2"><label class="text-xs font-bold text-gray-500 pl-1">\u5C55\u793A\u7BC7\u6570</label><input type="number" id="c" value="10" class="p-3 border rounded-xl bg-gray-50 focus:ring-2 ring-indigo-500 outline-none"></div>
        <div class="flex flex-col gap-2 md:col-span-4 justify-end h-full">
          <div class="flex flex-col gap-1.5 bg-indigo-50/50 p-2 rounded-xl border border-indigo-100 text-[11px] text-indigo-700 font-bold">
            <label class="flex items-center gap-2 cursor-pointer"><input type="checkbox" id="enableTranslate" checked class="w-4 h-4 rounded"><span>\u5F00\u542F\u4E2D\u82F1\u53CC\u8BED\u7FFB\u8BD1</span></label>
            <label class="flex items-center gap-2 cursor-pointer"><input type="checkbox" id="expandAbstract" class="w-4 h-4 rounded"><span>\u90AE\u4EF6\u6458\u8981\u5168\u90E8\u5C55\u5F00</span></label>
            <label class="flex items-center gap-2 cursor-pointer"><input type="checkbox" id="strictFilter" checked class="w-4 h-4 rounded"><span>\u4E25\u683C\u5E03\u5C14\u5339\u914D (\u81EA\u52A8\u6269\u5927\u68C0\u7D22\u6C60\u9632\u6F0F\u62A5)</span></label>
          </div>
          <button type="submit" class="bg-indigo-600 text-white font-bold p-3 rounded-xl hover:bg-indigo-700 w-full mt-auto">\u271A \u5EFA\u7ACB / \u6267\u884C\u4EFB\u52A1</button>
        </div>
      </form>
    </div>

    <div class="bg-slate-900 rounded-2xl shadow-xl p-6 text-white overflow-hidden border border-slate-800">
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-indigo-400 font-bold text-lg">\u7CFB\u7EDF\u76D1\u63A7\u9762\u677F</h3>
        <button onclick="load()" class="text-[10px] bg-slate-800 px-4 py-2 rounded-lg hover:bg-slate-700">\u{1F504} \u5237\u65B0\u5217\u8868</button>
      </div>
      <div id="log" class="bg-black/40 p-3 rounded-xl mb-6 text-[10px] font-mono text-emerald-500 max-h-32 overflow-y-auto whitespace-pre">\u5C31\u7EEA...</div>
      <div class="overflow-x-auto">
        <table class="w-full text-left text-[11px] font-mono">
          <thead class="text-slate-500 bg-slate-800/50">
            <tr><th class="p-3">\u4E3B\u9898 / \u90AE\u7BB1</th><th class="p-3">\u5173\u952E\u8BCD</th><th class="p-3">\u9891\u6B21/\u6210\u529F</th><th class="p-3">\u4E0A\u6B21\u6267\u884C</th><th class="p-3">\u9884\u8BA1\u4E0B\u6B21\u6267\u884C</th>${isAdmin ? "<th>\u64CD\u4F5C</th>" : ""}</tr>
          </thead>
          <tbody id="tb" class="divide-y divide-slate-800"></tbody>
        </table>
      </div>
    </div>
  </div>

  <script>
    async function translateToEnglish() {
      const input = document.getElementById('q');
      const btn = document.getElementById('transBtn');
      const text = input.value.trim();
      if (!text) return alert("\u8BF7\u5148\u8F93\u5165\u5173\u952E\u8BCD\uFF01");
      if (!/[\\u4e00-\\u9fa5]/.test(text)) return alert("\u65E0\u9700\u8F6C\u8BD1\u3002");

      const originalBtnText = btn.innerText;
      btn.innerText = "\u23F3 AI \u540E\u7AEF\u5904\u7406\u4E2D...";
      btn.disabled = true;

      try {
        const res = await fetch('/api/translate', { method: 'POST', body: JSON.stringify({ text }) });
        const data = await res.json();
        
        if (data.query) {
          input.value = data.query;
          input.classList.add('ring-4', 'ring-purple-400');
          setTimeout(() => input.classList.remove('ring-4', 'ring-purple-400'), 1000);
          if(data.fallback) alert("\u26A0\uFE0F \u672A\u914D\u7F6E AI Key\uFF0C\u5DF2\u4F7F\u7528\u4F20\u7EDF\u673A\u7FFB\u66FF\u4EE3\u3002");
        } else {
          throw new Error("\u8F6C\u8BD1\u5931\u8D25");
        }
      } catch (err) { alert("\u670D\u52A1\u4E0D\u53EF\u7528\uFF0C\u8BF7\u624B\u52A8\u8F93\u5165\u82F1\u6587\u3002"); } 
      finally { btn.innerText = originalBtnText; btn.disabled = false; }
    }

    const fmt = (s) => s ? new Date(s.replace(' ', 'T') + 'Z').toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false }) : '\u4ECE\u672A\u6267\u884C';
    const calcNext = (last, f) => {
      if(!last) return '\u7ACB\u5373\u6267\u884C';
      const n = new Date(new Date(last.replace(' ', 'T') + 'Z').getTime() + f * 86400000);
      return n <= new Date() ? '\u{1F680} \u5373\u5C06\u63A8\u9001' : n.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai', hour12: false });
    };

    async function load() {
      const data = await (await fetch('/api/users?_t=' + Date.now())).json();
      document.getElementById('tb').innerHTML = data.map(u => {
        // \u9488\u5BF95\u5206\u949F\u6D4B\u8BD5\u6216\u5C0F\u4E8E1\u5929\u7684\u9891\u7387\uFF0C\u4F18\u5316\u663E\u793A\u4E3A\u201C\u5206\u949F\u201D\uFF0C\u5176\u5B83\u7167\u5E38\u663E\u793A\u4E3A\u201C\u5929\u201D
        const freqText = (u.interval_days && u.interval_days < 1) ? Math.round(u.interval_days * 1440) + '\u5206\u949F' : u.interval_days + '\u5929';
        return \`
        <tr class="hover:bg-indigo-500/5">
          <td class="p-3"><div class="text-indigo-400 font-bold text-sm">#\${u.id} \${u.topic_name}</div><div class="text-slate-500 text-[9px]">\${u.client_email}</div></td>
          <td class="p-3"><div class="text-slate-400 max-w-[150px] break-words">\${u.query_keywords}</div></td>
          <td class="p-3 text-slate-400">\${freqText} | <span class="text-emerald-400 font-bold">\${u.send_count || 0}</span></td>
          <td class="p-3 text-slate-300">\${fmt(u.last_sent_date)}</td>
          <td class="p-3 text-indigo-300 font-bold">\${calcNext(u.last_sent_date, u.interval_days)}</td>
          \${${isAdmin} ? \`<td class="p-3"><button onclick="del(\${u.id})" class="text-red-500">\u5220\u9664</button></td>\` : ''}
        </tr>\`
      }).join('');
    }
    async function repairDB() { alert(await (await fetch('/api/setup')).text()); load(); }
    async function test() { document.getElementById('log').innerText = '\u6267\u884C\u5168\u5E93\u626B\u63CF...'; document.getElementById('log').innerText = await (await fetch('/debug-cron')).text(); load(); }
    async function del(id) { if(confirm('\u786E\u8BA4\u5220\u9664\uFF1F')) { await fetch('/api/delete?id=' + id); load(); } }

    document.getElementById('f').onsubmit = async (e) => {
      e.preventDefault();
      if (/[\\u4e00-\\u9fa5]/.test(document.getElementById('q').value)) {
        if (!confirm("\u26A0\uFE0F \u60A8\u7684\u5173\u952E\u8BCD\u4E2D\u5305\u542B\u4E2D\u6587\uFF0C\u53EF\u80FD\u6293\u53D6\u4E0D\u5230\u56FD\u9645\u6587\u732E\u3002\u5EFA\u8BAE\u5148\u70B9\u51FB\u3010AI \u667A\u80FD\u8F6C\u8BD1\u3011\u3002\\n\u5F3A\u5236\u63D0\u4EA4\uFF1F")) return;
      }
      const isRunOnce = parseFloat(document.getElementById('fr').value) === 0;
      const btn = e.target.querySelector('button[type="submit"]');
      btn.innerText = isRunOnce ? "\u26A1 \u5904\u7406\u4E2D..." : "\u4FDD\u5B58\u4E2D...";
      btn.disabled = true;

      try {
        const res = await fetch('/api/subscribe', {
          method: 'POST', body: JSON.stringify({
            clientEmail: document.getElementById('e').value, topicName: document.getElementById('t').value, query: document.getElementById('q').value,
            countPerSource: parseInt(document.getElementById('c').value), frequencyDays: parseFloat(document.getElementById('fr').value), lookbackDays: parseInt(document.getElementById('l').value),
            strictFilter: document.getElementById('strictFilter').checked, enableTranslate: document.getElementById('enableTranslate').checked, expandAbstract: document.getElementById('expandAbstract').checked
          })
        });
        const data = await res.json();
        if (data.error) throw new Error(data.error);
        alert(isRunOnce ? "\u26A1 \u5355\u6B21\u4EFB\u52A1\u5DF2\u5B8C\u6210\u5E76\u53D1\u9001\uFF01" : "\u2705 \u4EFB\u52A1\u5EFA\u7ACB\u6210\u529F\uFF01");
        if(!isRunOnce) document.getElementById('q').value = '';
        load();
      } catch (err) { alert("\u5931\u8D25\uFF1A" + err.message); } 
      finally { btn.innerText = "\u271A \u5EFA\u7ACB / \u6267\u884C\u4EFB\u52A1"; btn.disabled = false; }
    };
    load();
  <\/script>
</body>
</html>`;
}
__name(renderHTML, "renderHTML");
var corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type, Authorization" };
var worker_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
    const checkAdminAuth = /* @__PURE__ */ __name(() => request.headers.get("Authorization") === "Basic " + btoa("sanshu:sanshu123456"), "checkAdminAuth");
    if (request.method === "POST" && url.pathname === "/api/translate") {
      try {
        const { text } = await request.json();
        const apiKey = SYSTEM_CONFIG.geminiApiKey || env && env.GEMINI_API_KEY;
        if (!apiKey) {
          const res = await fetch(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=zh|en`);
          const data2 = await res.json();
          return new Response(JSON.stringify({ query: data2.responseData?.translatedText || "Translation Error", fallback: true }), { headers: corsHeaders });
        }
        const promptText = `You are an expert academic librarian. The user will give you a research topic in Chinese. Translate it into a highly optimized English Boolean search query for PubMed/Semantic Scholar.
Rules:
1. Keep it concise.
2. Expand key medical and scientific terms with exact academic synonyms using OR in parentheses.
3. Use AND between concepts.
4. If it's a specific species like '\u8336\u6811', use scientific name in quotes (e.g., "Camellia sinensis").
5. Output ONLY the query string, NO markdown, NO surrounding quotes.
Example Input: \u8336\u6811\u6839\u4E0E\u5FC3\u810F\u6CBB\u7597
Example Output: "Camellia sinensis" root (heart OR myocardial OR cardiovascular OR atherosclerosis)

Input: ${text}`;
        const response = await fetch("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + apiKey, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ contents: [{ parts: [{ text: promptText }] }] })
        });
        const data = await response.json();
        let queryStr = data.candidates?.[0]?.content?.parts?.[0]?.text || "";
        queryStr = queryStr.replace(/^["'`]+|["'`]+$/g, "").trim();
        return new Response(JSON.stringify({ query: queryStr }), { headers: corsHeaders });
      } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: corsHeaders });
      }
    }
    if (request.method === "POST" && url.pathname === "/api/subscribe") {
      try {
        const data = await request.json();
        const advanced = JSON.stringify({ ...data.advancedSettings, lookbackDays: data.lookbackDays, strictFilter: data.strictFilter, enableTranslate: data.enableTranslate !== false, expandAbstract: data.expandAbstract === true });
        if (data.frequencyDays === 0) {
          const mockConfig = { client_email: data.clientEmail, topic_name: data.topicName, query_keywords: data.query, count_per_source: data.countPerSource, interval_days: "\u5355\u6B21", advanced_settings: advanced };
          try {
            const papers = await fetchAllPapers(mockConfig);
            await sendEmail(env, papers, mockConfig);
            return new Response(JSON.stringify({ success: true, isRunOnce: true }), { headers: corsHeaders });
          } catch (err) {
            return new Response(JSON.stringify({ error: "\u6267\u884C\u4E2D\u65AD: " + err.message }), { status: 500, headers: corsHeaders });
          }
        }
        try {
          await env.DB.prepare(`INSERT INTO subscriptions (client_email, topic_name, query_keywords, count_per_source, interval_days, advanced_settings, send_count) VALUES (?, ?, ?, ?, ?, ?, 0)`).bind(data.clientEmail, data.topicName, data.query, data.countPerSource, data.frequencyDays, advanced).run();
        } catch (e) {
          await env.DB.prepare(`INSERT INTO subscriptions (client_email, topic_name, query_keywords, count_per_source, interval_days, advanced_settings) VALUES (?, ?, ?, ?, ?, ?)`).bind(data.clientEmail, data.topicName, data.query, data.countPerSource, data.frequencyDays, advanced).run();
        }
        return new Response(JSON.stringify({ success: true, isRunOnce: false }), { headers: corsHeaders });
      } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: corsHeaders });
      }
    }
    if (url.pathname === "/api/users") {
      const { results } = await env.DB.prepare("SELECT * FROM subscriptions ORDER BY id DESC").all();
      return new Response(JSON.stringify(results), { headers: corsHeaders });
    }
    if (url.pathname === "/api/delete") {
      if (!checkAdminAuth()) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: corsHeaders });
      await env.DB.prepare("DELETE FROM subscriptions WHERE id = ?").bind(url.searchParams.get("id")).run();
      return new Response(JSON.stringify({ success: true }), { headers: corsHeaders });
    }
    if (url.pathname === "/api/setup") {
      if (!checkAdminAuth()) return new Response("Unauthorized", { status: 401, headers: corsHeaders });
      try {
        await env.DB.prepare("ALTER TABLE subscriptions ADD COLUMN send_count INTEGER DEFAULT 0;").run();
        return new Response("\u6570\u636E\u5E93\u5347\u7EA7\u6210\u529F\uFF01", { headers: corsHeaders });
      } catch (e) {
        return new Response("\u5347\u7EA7\u5931\u8D25\u6216\u5DF2\u5B58\u5728: " + e.message, { headers: corsHeaders });
      }
    }
    if (url.pathname === "/debug-cron") {
      if (!checkAdminAuth()) return new Response("Unauthorized", { status: 401, headers: corsHeaders });
      return new Response(await executeScheduledTask(env), { headers: corsHeaders });
    }
    if (url.pathname === "/admin") {
      if (!checkAdminAuth()) return new Response("\u9700\u8981\u7BA1\u7406\u5458\u8D26\u53F7\u548C\u5BC6\u7801", { status: 401, headers: { "WWW-Authenticate": 'Basic realm="Admin Login Area"', "Content-Type": "text/plain;charset=UTF-8" } });
      return new Response(renderHTML(true), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
    }
    return new Response(renderHTML(false), { headers: { "Content-Type": "text/html;charset=UTF-8" } });
  },
  async scheduled(event, env, ctx) {
    ctx.waitUntil(executeScheduledTask(env));
  }
};
export {
  worker_default as default
};
//# sourceMappingURL=worker.js.map
