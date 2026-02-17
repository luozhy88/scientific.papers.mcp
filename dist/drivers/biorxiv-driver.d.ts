/**
 * bioRxiv/medRxiv Driver - Week 4 Implementation
 *
 * Provides access to bioRxiv and medRxiv preprint servers
 * Uses JSON API with date-based querying and incremental harvest
 */
import { BaseDriver } from "./base-driver.js";
import { Category, PaperMetadata } from "../types/papers.js";
import { RateLimiter } from "../core/rate-limiter.js";
export declare class BioRxivDriver extends BaseDriver {
    private textExtractor;
    private readonly bioRxivApiBase;
    private readonly medRxivApiBase;
    private readonly bioRxivCategories;
    private readonly medRxivCategories;
    constructor(rateLimiter: RateLimiter);
    /**
     * List bioRxiv/medRxiv categories
     */
    listCategories(): Promise<Category[]>;
    /**
     * Fetch latest papers from bioRxiv/medRxiv for a given category
     */
    fetchLatest(category: string, count: number): Promise<PaperMetadata[]>;
    /**
     * Fetch content for a specific bioRxiv/medRxiv paper by DOI
     */
    fetchContent(id: string): Promise<PaperMetadata>;
    /**
     * Search for papers with query and field-specific options
     * Note: bioRxiv/medRxiv API has limited search capabilities
     */
    searchPapers(query: string, field: string, count: number, sortBy: string): Promise<PaperMetadata[]>;
    /**
     * Convert bioRxiv/medRxiv paper to PaperMetadata format
     */
    private convertPaperToMetadata;
    /**
     * Parse category string to determine server and subject
     */
    private parseCategory;
    /**
     * Determine which servers to try based on DOI pattern
     */
    private getServersForDOI;
}
