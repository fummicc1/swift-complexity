import type {
  AnalyzeRequest,
  ComplexityResult,
  FormatResponse,
} from "@/types/complexity";

const API_URL = process.env.NEXT_PUBLIC_API_URL!;

export async function analyzeCode(
  request: AnalyzeRequest
): Promise<{result: ComplexityResult} | {formatted: FormatResponse}> {
  const response = await fetch(`${API_URL}/api/v1/analyze`, {
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
