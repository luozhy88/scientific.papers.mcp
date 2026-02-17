# Scientific Papers MCP - 调用的 API 文档

本文档详细列出 Scientific Papers MCP 项目调用的所有外部 API。

## 📊 API 概览

| 数据源 | API 地址 | 类型 | 限流 |
|--------|----------|------|------|
| **CORE** | api.core.ac.uk | REST API | 10 req/min |
| **arXiv** | export.arxiv.org | Atom Feed | 5 req/min |
| **OpenAlex** | api.openalex.org | REST API | 10 req/min |
| **Europe PMC** | ebi.ac.uk/europepmc | REST API | 10 req/min |
| **PMC** | eutils.ncbi.nlm.nih.gov | E-utilities | 3 req/sec |
| **bioRxiv** | api.biorxiv.org | REST API | 5 req/min |
| **medRxiv** | api.medrxiv.org | REST API | 5 req/min |

---

## 1️⃣ CORE API

**基础地址**: `https://api.core.ac.uk/v3`

**官方文档**: https://core.ac.uk/services/api/

### 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/search/works` | POST | 搜索论文 |
| `/works/{id}` | GET | 获取论文详情 |

### 请求示例
```bash
# 搜索论文
curl -X POST https://api.core.ac.uk/v3/search/works \
  -H "Content-Type: application/json" \
  -d '{
    "query": "machine learning",
    "limit": 10,
    "sort": "relevance"
  }'

# 获取论文详情
curl https://api.core.ac.uk/v3/works/{id}
```

### 限流
- 免费版: 10 请求/分钟
- 需要 API Key 以提高限制

---

## 2️⃣ arXiv API

**基础地址**: `https://export.arxiv.org/api/query`

**官方文档**: https://info.arxiv.org/help/api/

### 协议
- 基于 Atom feed 格式 (XML)

### 请求示例
```bash
# 搜索论文
curl "https://export.arxiv.org/api/query?search_query=all:machine+learning&start=0&max_results=10"

# 获取特定分类的最新论文
curl "https://export.arxiv.org/api/query?search_query=cat:cs.AI&sortBy=submittedDate&sortOrder=descending&max_results=10"
```

### 常用分类
- `cs.AI` - 人工智能
- `cs.CV` - 计算机视觉
- `cs.LG` - 机器学习
- `cs.CL` - 计算语言学

### 限流
- 5 请求/分钟
- 建议使用导出接口而非主站

---

## 3️⃣ OpenAlex API

**基础地址**: `https://api.openalex.org`

**官方文档**: https://docs.openalex.org/

### 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/works` | GET | 搜索论文 |
| `/works/{id}` | GET | 获取论文详情 |
| `/concepts` | GET | 获取概念/分类 |

### 请求示例
```bash
# 搜索论文
curl "https://api.openalex.org/works?search=machine+learning&per-page=10"

# 获取论文详情
curl "https://api.openalex.org/works/W2741809807"

# 获取概念列表
curl "https://api.openalex.org/concepts"
```

### 限流
- 10 请求/分钟（保守限制）
- 无认证也可使用

---

## 4️⃣ Europe PMC API

**基础地址**: `https://www.ebi.ac.uk/europepmc/webservices/rest`

**官方文档**: https://europepmc.org/RestfulWebService

### 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/search` | GET | 搜索论文 |
| `/PMCID/{id}/fullText` | GET | 获取全文 |

### 请求示例
```bash
# 搜索论文
curl "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=diabetes&resultType=core&pageSize=10"

# 获取全文
curl "https://www.ebi.ac.uk/europepmc/webservices/rest/PMCID/PMC1234567/fullText"
```

### 限流
- 10 请求/分钟

---

## 5️⃣ PMC (PubMed Central) API

**基础地址**: `https://eutils.ncbi.nlm.nih.gov/entrez/eutils`

**官方文档**: https://www.ncbi.nlm.nih.gov/pmc/tools/developers/

### 端点 (E-utilities)

| 端点 | 说明 |
|------|------|
| `esearch.fcgi` | 搜索论文 |
| `efetch.fcgi` | 获取论文详情 |
| `elink.fcgi` | 获取相关链接 |

### 请求示例
```bash
# 搜索论文
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pmc&term=COVID-19&retmode=json&retmax=10"

# 获取论文详情
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pmc&id=12345&retmode=xml"
```

### 限流
- 3 请求/秒
- 建议注册获取 API Key

---

## 6️⃣ bioRxiv API

**基础地址**: `https://api.biorxiv.org`

**官方文档**: https://api.biorxiv.org/

### 端点

| 端点 | 说明 |
|------|------|
| `/details/biorxiv/{from_date}/{to_date}` | 获取日期范围内的论文 |

### 请求示例
```bash
# 获取指定日期范围的论文
curl "https://api.biorxiv.org/details/biorxiv/2024-01-01/2024-01-31"
```

### 限流
- 5 请求/分钟

---

## 7️⃣ medRxiv API

**基础地址**: `https://api.medrxiv.org`

**官方文档**: https://api.biorxiv.org/ (与 bioRxiv 相同)

### 端点

| 端点 | 说明 |
|------|------|
| `/details/medrxiv/{from_date}/{to_date}` | 获取日期范围内的论文 |

### 请求示例
```bash
# 获取指定日期范围的论文
curl "https://api.medrxiv.org/details/medrxiv/2024-01-01/2024-01-31"
```

---

## 🔧 辅助服务

### 1. ar5iv (arXiv HTML 版本)

**地址**: `https://ar5iv.labs.arxiv.org/html/{id}`

用于获取 arXiv 论文的 HTML 格式，便于文本提取。

### 2. arXiv HTML

**地址**: `https://arxiv.org/html/{id}`

arXiv 官方 HTML 版本。

### 3. DOI 解析服务

- **Unpaywall**: https://api.unpaywall.org/
- **Crossref**: https://api.crossref.org/
- **Semantic Scholar**: https://api.semanticscholar.org/

### 4. PDF 下载

- **CORE**: https://core.ac.uk/download/{id}.pdf
- **arXiv**: https://arxiv.org/pdf/{id}.pdf

---

## ⚠️ 注意事项

### API 限流总结

| 数据源 | 限流 | 备注 |
|--------|------|------|
| CORE | 10 req/min | 需要 API Key 提高限制 |
| arXiv | 5 req/min | 使用 export 接口 |
| OpenAlex | 10 req/min | 相对宽松 |
| Europe PMC | 10 req/min | - |
| PMC | 3 req/sec | 建议注册 API Key |
| bioRxiv | 5 req/min | - |

### 认证要求

大多数 API 不需要认证即可使用，但建议：
1. **CORE**: 注册获取 API Key 以提高限流
2. **PMC**: 注册获取 API Key
3. **Crossref**: 使用邮件地址作为标识

### 错误处理

项目中已内置的错误处理：
- 限流自动重试
- 超时处理
- 降级策略（HTML 提取 → PDF 提取 → 仅摘要）

---

## 📚 参考资料

- CORE API: https://core.ac.uk/services/api/
- arXiv API: https://info.arxiv.org/help/api/
- OpenAlex API: https://docs.openalex.org/
- Europe PMC API: https://europepmc.org/RestfulWebService
- PMC E-utilities: https://www.ncbi.nlm.nih.gov/books/NBK25501/
- bioRxiv API: https://api.biorxiv.org/
