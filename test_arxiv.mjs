import { fetchContent } from './dist/tools/fetch-content.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rateLimiter = new RateLimiter();

const result = await fetchContent({
  source: 'arxiv',
  id: '2602.12538'
}, rateLimiter);

console.log('RESULT:' + JSON.stringify(result, null, 2));
