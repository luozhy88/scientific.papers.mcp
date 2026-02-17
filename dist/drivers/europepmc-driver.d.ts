/**
 * Europe PMC Driver - Week 3 Implementation
 *
 * Provides access to Europe PMC's collection of life science literature
 * Uses REST API with full-text filtering capabilities
 */
import { BaseDriver } from "./base-driver.js";
import { Category, PaperMetadata } from "../types/papers.js";
import { RateLimiter } from "../core/rate-limiter.js";
export declare class EuropePMCDriver extends BaseDriver {
    private textExtractor;
    private readonly apiBase;
    private readonly europePMCCategories;
    constructor(rateLimiter: RateLimiter);
    /**
     * List Europe PMC categories
     */
    listCategories(): Promise<Category[]>;
    /**
     * Fetch latest papers from Europe PMC for a given category
     */
    fetchLatest(category: string, count: number): Promise<PaperMetadata[]>;
    /**
     * Fetch content for a specific Europe PMC paper by ID
     */
    fetchContent(id: string): Promise<PaperMetadata>;
    /**
     * Convert Europe PMC result to PaperMetadata format
     */
    private convertResultToPaper;
    /**
     * Search for papers with query and field-specific options
     */
    searchPapers(query: string, field: string, count: number, sortBy: string): Promise<PaperMetadata[]>;
    /**
     * Build search query for Europe PMC based on category
     */
    private buildSearchQuery;
    /**
     * Parse ID to determine source and clean format
     */
    private parseId;
}
