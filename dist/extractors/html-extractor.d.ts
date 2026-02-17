import { BaseExtractor, TextExtractionResult, ExtractionConfig } from "./base-extractor.js";
export declare class HtmlExtractor extends BaseExtractor {
    private textCleaner;
    private pdfExtractor;
    constructor(config: ExtractionConfig);
    extractText(url: string, fallbackPdfUrl?: string): Promise<TextExtractionResult>;
    private extractArxivText;
    private extractOpenAlexText;
    private fetchHtml;
    private processArxivHtml;
    private processOpenAlexHtml;
    private extractArxivId;
}
