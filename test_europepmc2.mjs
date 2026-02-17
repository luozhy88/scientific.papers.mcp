import { searchPapers } from './dist/tools/search-papers.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rateLimiter = new RateLimiter();

const result = await searchPapers({
  source: 'europepmc',
  query: 'cancer',
  field: 'all',
  count: 2,
  sortBy: 'date'
}, rateLimiter);

console.log('RESULT:' + JSON.stringify(result, null, 2));
