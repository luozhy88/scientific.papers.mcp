import { fetchContent } from './dist/tools/fetch-content.js';
import { RateLimiter } from './dist/core/rate-limiter.js';
const rateLimiter = new RateLimiter();

const result = await fetchContent({
  source: 'openalex',
  id: 'W7128925295'
}, rateLimiter);

console.log('RESULT:' + JSON.stringify(result, null, 2));
