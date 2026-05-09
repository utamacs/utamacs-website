declare module 'pdfmake' {
  interface FontFamilyTypes {
    normal?: string | Buffer;
    bold?: string | Buffer;
    italics?: string | Buffer;
    bolditalics?: string | Buffer;
  }
  class PdfPrinter {
    constructor(fontDescriptors: Record<string, FontFamilyTypes>);
    createPdfKitDocument(
      docDefinition: Record<string, unknown>,
      options?: Record<string, unknown>
    ): NodeJS.ReadableStream & { end(): void };
  }
  export = PdfPrinter;
}
