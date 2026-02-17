import axios from "axios";
import { BaseExtractor } from "./base-extractor.js";
import { TextCleaner } from "./text-cleaner.js";
import { logInfo, logWarn, logError } from "../core/logger.js";
export class PdfExtractor extends BaseExtractor {
    textCleaner;
    abortController = null;
    options;
    constructor(config, options = {
        maxSizeMB: 50,
        timeoutMs: 120000, // 2 minutes
        maxPages: 100,
        requireConfirmation: true,
        interactive: true,
    }) {
        super(config);
        this.textCleaner = new TextCleaner(config.cleaningOptions);
        this.options = options;
    }
    async extractText(url, onProgress, onConfirm) {
        try {
            this.abortController = new AbortController();
            // Phase 1: Check PDF metadata
            onProgress?.({
                phase: "checking",
                progress: 0,
                message: "Checking PDF size and metadata...",
                cancellable: true,
            });
            const metadata = await this.checkPdfMetadata(url);
            // Phase 2: User confirmation for large PDFs
            if (this.options.requireConfirmation && metadata.sizeMB > 10) {
                const confirmed = await onConfirm?.(metadata);
                if (!confirmed) {
                    logInfo("PDF extraction cancelled by user", { url, size: metadata.sizeMB });
                    return {
                        text: "",
                        truncated: false,
                        extractionSuccess: false,
                        source: "failed",
                        metadata: {
                            userCancelled: true,
                            reason: "PDF too large, user declined extraction",
                            pdfSize: metadata.sizeMB,
                        },
                    };
                }
            }
            // Phase 3: Download PDF
            onProgress?.({
                phase: "downloading",
                progress: 20,
                message: `Downloading PDF (${metadata.sizeMB.toFixed(1)}MB)...`,
                cancellable: true,
            });
            const pdfBuffer = await this.downloadPdf(url, metadata);
            // Phase 4: Parse PDF
            onProgress?.({
                phase: "parsing",
                progress: 60,
                message: "Parsing PDF structure...",
                cancellable: true,
            });
            const pdfData = await this.parsePdf(pdfBuffer);
            // Phase 5: Extract and clean text
            onProgress?.({
                phase: "extracting",
                progress: 80,
                message: `Extracting text from ${pdfData.numpages} pages...`,
                cancellable: false, // Final phase, too late to cancel
            });
            const result = await this.processExtractedText(pdfData, url, metadata);
            onProgress?.({
                phase: "complete",
                progress: 100,
                message: "PDF extraction complete",
                cancellable: false,
            });
            return result;
        }
        catch (error) {
            if (error instanceof Error && error.name === "AbortError") {
                logInfo("PDF extraction cancelled by user", { url });
                return {
                    text: "",
                    truncated: false,
                    extractionSuccess: false,
                    source: "failed",
                    metadata: {
                        userCancelled: true,
                        reason: "Extraction cancelled by user",
                    },
                };
            }
            logError("PDF extraction failed", {
                url,
                error: error instanceof Error ? error.message : String(error),
            });
            return this.createFailedResult();
        }
    }
    async checkPdfMetadata(url) {
        try {
            const response = await axios.head(url, {
                timeout: 10000,
                signal: this.abortController?.signal,
                headers: {
                    "User-Agent": "Scientific Paper Harvester MCP Server/1.0",
                },
            });
            const sizeBytes = parseInt(response.headers["content-length"] || "0", 10);
            const sizeMB = sizeBytes / (1024 * 1024);
            // Check if size exceeds limits
            if (sizeMB > this.options.maxSizeMB) {
                throw new Error(`PDF too large: ${sizeMB.toFixed(1)}MB (limit: ${this.options.maxSizeMB}MB)`);
            }
            return {
                url,
                sizeBytes,
                sizeMB,
                title: response.headers["content-disposition"]?.match(/filename="(.+)"/)?.[1],
            };
        }
        catch (error) {
            if (error instanceof Error && error.name === "AbortError")
                throw error;
            logWarn("Could not check PDF metadata, proceeding with download", {
                url,
                error: error instanceof Error ? error.message : String(error),
            });
            // Fallback metadata
            return {
                url,
                sizeBytes: 0,
                sizeMB: 0,
            };
        }
    }
    async downloadPdf(url, metadata) {
        const response = await axios.get(url, {
            responseType: "arraybuffer",
            timeout: this.options.timeoutMs,
            signal: this.abortController?.signal,
            headers: {
                "User-Agent": "Scientific Paper Harvester MCP Server/1.0",
            },
            maxContentLength: this.options.maxSizeMB * 1024 * 1024, // Convert MB to bytes
        });
        if (response.status !== 200) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return Buffer.from(response.data);
    }
    async parsePdf(buffer) {
        const options = {
            max: this.options.maxPages,
            version: "default",
        };
        // Dynamic import to avoid pdf-parse debug mode issues
        const pdfParse = await import("pdf-parse").then(m => m.default || m);
        return pdfParse(buffer, options);
    }
    async processExtractedText(pdfData, url, metadata) {
        const extractedText = pdfData.text || "";
        const pageCount = pdfData.numpages || 0;
        // Clean the extracted text
        const cleanedText = this.textCleaner.cleanText(extractedText);
        const { text, truncated } = this.checkTextLength(cleanedText);
        // Check for context window concerns
        const isLargeExtraction = text.length > 2000000; // 2MB of text
        const contextWarning = isLargeExtraction
            ? "⚠️ Large text extraction may consume significant context window space"
            : undefined;
        logInfo("PDF text extraction successful", {
            url,
            pageCount,
            originalLength: extractedText.length,
            cleanedLength: cleanedText.length,
            finalLength: text.length,
            truncated,
            sizeMB: metadata.sizeMB,
        });
        return {
            text,
            truncated,
            extractionSuccess: true,
            source: "pdf",
            metadata: {
                pageCount,
                pdfSize: metadata.sizeMB,
                contextWarning,
                extractionTime: Date.now(),
            },
        };
    }
    cancel() {
        if (this.abortController) {
            this.abortController.abort();
            logInfo("PDF extraction cancelled");
        }
    }
    createFailedResult() {
        return {
            text: "",
            truncated: false,
            extractionSuccess: false,
            source: "failed",
            metadata: {
                extractionFailed: true,
                fallbackAvailable: true,
            },
        };
    }
}
//# sourceMappingURL=pdf-extractor.js.map