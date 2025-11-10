export type SourceLocation = {
  line: number;
  column: number;
};

export type FunctionComplexity = {
  name: string;
  signature: string;
  cyclomaticComplexity: number;
  cognitiveComplexity: number;
  location: SourceLocation;
};

export type FileSummary = {
  totalFunctions: number;
  averageCyclomaticComplexity: number;
  averageCognitiveComplexity: number;
  maxCyclomaticComplexity: number;
  maxCognitiveComplexity: number;
  totalCyclomaticComplexity: number;
  totalCognitiveComplexity: number;
};

export type ComplexityResult = {
  filePath: string;
  functions: FunctionComplexity[];
  summary: FileSummary;
};

export type OutputFormat = "text" | "json" | "xml" | "xcode";

export type AnalyzeRequest = {
  code: string;
  fileName: string;
  format?: OutputFormat;
  showCyclomaticOnly?: boolean;
  showCognitiveOnly?: boolean;
  threshold?: number;
};

export type FormatResponse = {
  formatted: string;
};
