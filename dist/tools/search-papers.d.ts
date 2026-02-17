import { z } from "zod";
import { RateLimiter } from "../core/rate-limiter.js";
import { PaperMetadata } from "../types/papers.js";
export declare const searchPapersSchema: z.ZodObject<{
    source: z.ZodEnum<["arxiv", "openalex", "europepmc", "core"]>;
    query: z.ZodString;
    field: z.ZodDefault<z.ZodOptional<z.ZodEnum<["all", "title", "abstract", "author", "fulltext"]>>>;
    count: z.ZodDefault<z.ZodNumber>;
    sortBy: z.ZodDefault<z.ZodOptional<z.ZodEnum<["relevance", "date", "citations"]>>>;
}, "strip", z.ZodTypeAny, {
    source: "arxiv" | "openalex" | "europepmc" | "core";
    count: number;
    query: string;
    field: "title" | "author" | "abstract" | "all" | "fulltext";
    sortBy: "date" | "relevance" | "citations";
}, {
    source: "arxiv" | "openalex" | "europepmc" | "core";
    query: string;
    count?: number | undefined;
    field?: "title" | "author" | "abstract" | "all" | "fulltext" | undefined;
    sortBy?: "date" | "relevance" | "citations" | undefined;
}>;
export type SearchPapersInput = z.infer<typeof searchPapersSchema>;
/**
 * MCP tool: search_papers
 * Search for papers across different sources with query and field-specific options
 */
export declare function searchPapers(input: SearchPapersInput, rateLimiter: RateLimiter): Promise<{
    content: PaperMetadata[];
}>;
