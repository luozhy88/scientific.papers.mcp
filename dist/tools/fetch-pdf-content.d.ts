import { z } from "zod";
export declare const fetchPdfContentSchema: z.ZodObject<{
    url: z.ZodString;
    maxSizeMB: z.ZodDefault<z.ZodNumber>;
    maxPages: z.ZodDefault<z.ZodNumber>;
    timeout: z.ZodDefault<z.ZodNumber>;
    confirmLargeFiles: z.ZodDefault<z.ZodBoolean>;
}, "strip", z.ZodTypeAny, {
    timeout: number;
    url: string;
    maxSizeMB: number;
    maxPages: number;
    confirmLargeFiles: boolean;
}, {
    url: string;
    timeout?: number | undefined;
    maxSizeMB?: number | undefined;
    maxPages?: number | undefined;
    confirmLargeFiles?: boolean | undefined;
}>;
export type FetchPdfContentInput = z.infer<typeof fetchPdfContentSchema>;
export interface FetchPdfContentResult {
    success: boolean;
    text?: string;
    metadata?: {
        pageCount?: number;
        sizeBytes?: number;
        sizeMB?: number;
        extractionTime?: number;
        extractionSource: "pdf";
        textTruncated?: boolean;
        contextWarning?: string;
    };
    error?: string;
    cancelled?: boolean;
}
/**
 * MCP tool: fetch_pdf_content
 * Extracts text content from PDF files via direct URL
 */
export declare function fetchPdfContent(input: FetchPdfContentInput): Promise<FetchPdfContentResult>;
