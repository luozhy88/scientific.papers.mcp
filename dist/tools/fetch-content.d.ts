import { z } from "zod";
import { RateLimiter } from "../core/rate-limiter.js";
import { PaperMetadata } from "../types/papers.js";
export declare const fetchContentSchema: z.ZodObject<{
    source: z.ZodEnum<["arxiv", "openalex", "pmc", "europepmc", "biorxiv", "core"]>;
    id: z.ZodString;
}, "strip", z.ZodTypeAny, {
    source: "arxiv" | "openalex" | "pmc" | "europepmc" | "biorxiv" | "core";
    id: string;
}, {
    source: "arxiv" | "openalex" | "pmc" | "europepmc" | "biorxiv" | "core";
    id: string;
}>;
export type FetchContentInput = z.infer<typeof fetchContentSchema>;
/**
 * MCP tool: fetch_content
 * Fetches full metadata for a specific paper by ID from arXiv or OpenAlex
 */
export declare function fetchContent(input: FetchContentInput, rateLimiter: RateLimiter): Promise<{
    content: PaperMetadata;
}>;
export declare function fetchContentAndPrintText(input: FetchContentInput, rateLimiter: RateLimiter): Promise<{
    content: PaperMetadata;
}>;
