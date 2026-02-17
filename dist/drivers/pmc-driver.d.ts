/**
 * PubMed Central (PMC) Driver - Week 3 Implementation
 *
 * Provides access to PMC's collection of open-access biomedical papers
 * Uses E-utilities API for metadata and full-text retrieval
 */
import { BaseDriver } from "./base-driver.js";
import { Category, PaperMetadata } from "../types/papers.js";
import { RateLimiter } from "../core/rate-limiter.js";
export declare class PMCDriver extends BaseDriver {
    private textExtractor;
    private readonly eUtilsBase;
    private readonly pmcBase;
    private readonly pmcCategories;
    constructor(rateLimiter: RateLimiter);
    /**
     * List PMC categories
     */
    listCategories(): Promise<Category[]>;
    /**
     * Fetch latest papers from PMC for a given category
     */
    fetchLatest(category: string, count: number): Promise<PaperMetadata[]>;
    /**
     * Fetch content for a specific PMC paper by ID
     */
    fetchContent(id: string): Promise<PaperMetadata>;
    /**
     * Convert PMC summary to PaperMetadata format
     */
    private convertSummaryToPaper;
    /**
     * Search for papers with query and field-specific options
     * Note: PMC E-utilities API has limited search capabilities
     */
    searchPapers(query: string, field: string, count: number, sortBy: string): Promise<PaperMetadata[]>;
    /**
     * Build search query for PMC based on category
     */
    private buildSearchQuery;
    /**
     * Clean PMC ID (remove PMC prefix if present)
     */
    private cleanPMCId;
    /**
     * Format date from PMC format to ISO format
     */
    private formatDate;
}
