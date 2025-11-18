import type {
  AnalyzeRequest,
  ComplexityResult,
  FormatResponse,
} from "@/types/complexity";

export async function analyzeCode(
  request: AnalyzeRequest
): Promise<{result: ComplexityResult} | {formatted: FormatResponse}> {
  // Next.js Route Handlerを呼び出す（本番・開発共通）
  const response = await fetch("/api/analyze", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    throw new Error(`API Error: ${response.statusText}`);
  }

  // If format was specified, return FormatResponse
  if (request.format) {
    return (await response.json()) as {formatted: FormatResponse};
  }

  // Otherwise return ComplexityResult
  return (await response.json()) as {result: ComplexityResult};
}
