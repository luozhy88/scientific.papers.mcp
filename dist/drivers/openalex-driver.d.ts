import { BaseDriver } from "./base-driver.js";
import { Category, PaperMetadata } from "../types/papers.js";
import { RateLimiter } from "../core/rate-limiter.js";
export declare class OpenAlexDriver extends BaseDriver {
    private textExtractor;
    private doiResolver;
    private readonly politePoolEmail;
    constructor(rateLimiter: RateLimiter);
    /**
     * Get common request headers for OpenAlex API with polite pool access
     */
    private getRequestHeaders;
    /**
     * Get common request parameters for OpenAlex API with polite pool access
     */
    private getRequestParams;
    /**
     * List OpenAlex concepts (categories)
     * Fetches top-level concepts with highest paper counts
     */
    listCategories(): Promise<Category[]>;
    /**
     * Fetch latest papers from OpenAlex for a given concept/category
     */
    fetchLatest(category: string, count: number): Promise<PaperMetadata[]>;
    /**
     * Fetch top cited papers from OpenAlex for a given concept since a date
     */
    fetchTopCited(concept: string, since: string, count: number): Promise<PaperMetadata[]>;
    /**
     * Fetch content for a specific OpenAlex work by ID
     */
    fetchContent(id: string): Promise<PaperMetadata>;
    /**
     * Resolve the best full-text URL for a work using location hierarchy
     * Implements improved location resolution as per Week 1 & 2 requirements
     * Now includes DOI resolver fallback chain
     */
    private resolveFullText;
    /**
     * Convert OpenAlex Work to PaperMetadata format
     * Enhanced with improved full-text resolution
     */
    private convertWorkToPaper;
    /**
     * Build concept filter for OpenAlex API
     * Updated to handle OpenAlex API filtering requirements properly
     */
    private buildConceptFilter;
    /**
     * Search for papers with query and field-specific options
     */
    searchPapers(query: string, field: string, count: number, sortBy: string): Promise<PaperMetadata[]>;
    /**
     * Extract concept ID from OpenAlex URL format
     * e.g., "https://openalex.org/C41008148" -> "C41008148"
     */
    private extractConceptId;
    /**
     * Extract work ID from OpenAlex URL format
     * e.g., "https://openalex.org/W2741809807" -> "W2741809807"
     */
    private extractWorkId;
    /**
     * Clean OpenAlex ID (normalize format)
     */
    private cleanOpenAlexId;
}
