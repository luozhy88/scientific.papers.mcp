import { BaseExtractor, TextExtractionResult, ExtractionConfig } from "./base-extractor.js";
export interface PdfExtractionOptions {
    maxSizeMB: number;
    timeoutMs: number;
    maxPages?: number;
    requireConfirmation: boolean;
    interactive: boolean;
}
export interface PdfMetadata {
    url: string;
    sizeBytes: number;
    sizeMB: number;
    pageCount?: number;
    title?: string;
    author?: string;
}
export interface PdfExtractionProgress {
    phase: "checking" | "downloading" | "parsing" | "extracting" | "complete";
    progress: number;
    message: string;
    cancellable: boolean;
}
export declare class PdfExtractor extends BaseExtractor {
    private textCleaner;
    private abortController;
    private options;
    constructor(config: ExtractionConfig, options?: PdfExtractionOptions);
    extractText(url: string, onProgress?: (progress: PdfExtractionProgress) => void, onConfirm?: (metadata: PdfMetadata) => Promise<boolean>): Promise<TextExtractionResult>;
    private checkPdfMetadata;
    private downloadPdf;
    private parsePdf;
    private processExtractedText;
    cancel(): void;
    protected createFailedResult(): TextExtractionResult;
}
