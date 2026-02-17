/**
 * DOI Resolver Module - Week 2 Implementation
 *
 * Provides a fallback chain: Unpaywall → Crossref → Semantic Scholar Academic Graph (S2AG)
 * Implements 24h LRU cache and rate limiting for external APIs
 */
export interface DOIResolutionResult {
    doi: string;
    fullTextUrl?: string;
    pdfUrl?: string;
    landingPageUrl?: string;
    source: "unpaywall" | "crossref" | "s2ag" | "none";
    isOpenAccess: boolean;
    license?: string;
    resolverPath: string;
    cached: boolean;
}
export declare class DOIResolver {
    private cache;
    private requestCounts;
    private readonly UNPAYWALL_RATE_LIMIT;
    private readonly CROSSREF_RATE_LIMIT;
    private readonly S2AG_RATE_LIMIT;
    constructor(cacheSize?: number, cacheTtlHours?: number);
    /**
     * Main DOI resolution method with fallback chain
     */
    resolveDOI(doi: string): Promise<DOIResolutionResult>;
    /**
     * Resolve DOI using Unpaywall API
     */
    private resolveWithUnpaywall;
    /**
     * Resolve DOI using Crossref API
     */
    private resolveWithCrossref;
    /**
     * Resolve DOI using Semantic Scholar Academic Graph (S2AG)
     */
    private resolveWithS2AG;
    /**
     * Normalize DOI format
     */
    private normalizeDOI;
    /**
     * Simple rate limiting check
     */
    private checkRateLimit;
    /**
     * Increment request count for rate limiting
     */
    private incrementRequestCount;
    /**
     * Get cache statistics
     */
    getCacheStats(): {
        size: number;
        capacity: number;
    };
    /**
     * Clear the cache
     */
    clearCache(): void;
}
