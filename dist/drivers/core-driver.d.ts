/**
 * CORE Driver - Week 4 Implementation
 *
 * Provides access to CORE's collection of open access academic papers
 * Uses CORE API v3 with authentication and scroll API for large datasets
 */
import { BaseDriver } from "./base-driver.js";
import { Category, PaperMetadata } from "../types/papers.js";
import { RateLimiter } from "../core/rate-limiter.js";
export declare class CoreDriver extends BaseDriver {
    private textExtractor;
    private readonly apiBase;
    private readonly apiKey?;
    private readonly coreCategories;
    constructor(rateLimiter: RateLimiter);
    /**
     * List CORE categories
     */
    listCategories(): Promise<Category[]>;
    /**
     * Fetch latest papers from CORE for a given category
     */
    fetchLatest(category: string, count: number): Promise<PaperMetadata[]>;
    /**
     * Fetch content for a specific CORE paper by ID
     */
    fetchContent(id: string): Promise<PaperMetadata>;
    /**
     * Convert CORE paper to PaperMetadata format
     */
    private convertPaperToMetadata;
    /**
     * Search for papers with query and field-specific options
     */
    searchPapers(query: string, field: string, count: number, sortBy: string): Promise<PaperMetadata[]>;
    /**
     * Build search query for CORE based on category
     */
    private buildSearchQuery;
}
