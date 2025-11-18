"use client";

import { useState } from "react";
import CodeEditor from "@/components/CodeEditor";
import ComplexityResults from "@/components/ComplexityResults";
import { analyzeCode } from "@/lib/api";
import type { ComplexityResult } from "@/types/complexity";

const INITIAL_CODE = `func example(value: Int) -> String {
    if value > 0 {
        return "Positive"
    }
    return "Not positive"
}`;

export default function Home() {
  const [code, setCode] = useState(INITIAL_CODE);
  const [result, setResult] = useState<ComplexityResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleAnalyze = async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await analyzeCode({
        code,
        fileName: "input.swift",
      });

      // Response should be ComplexityResult when format is not specified
      setResult("result" in response ? response.result : null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "An error occurred");
      setResult(null);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* Header */}
      <header className="border-b border-gray-800 bg-gray-950">
        <div className="container mx-auto px-4 py-6">
          <h1 className="text-3xl font-bold">Swift Complexity Analyzer</h1>
          <p className="text-gray-400 mt-2">
            Analyze cyclomatic and cognitive complexity of your Swift code
          </p>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Left: Code Editor */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-semibold">Swift Code</h2>
              <button
                onClick={handleAnalyze}
                disabled={loading}
                className="px-6 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 disabled:cursor-not-allowed rounded-lg font-medium transition-colors"
              >
                {loading ? "Analyzing..." : "Analyze"}
              </button>
            </div>
            <div className="border border-gray-700 rounded-lg overflow-hidden">
              <CodeEditor
                value={code}
                onChange={(value) => setCode(value || "")}
                height="600px"
              />
            </div>
          </div>

          {/* Right: Results */}
          <div className="space-y-4">
            <h2 className="text-xl font-semibold">Complexity Metrics</h2>
            <ComplexityResults
              result={result}
              loading={loading}
              error={error}
            />
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-800 mt-16">
        <div className="container mx-auto px-4 py-6 text-center text-gray-400 text-sm">
          <p>
            Powered by{" "}
            <a
              href="https://github.com/fummicc1/swift-complexity"
              className="text-blue-400 hover:underline"
              target="_blank"
              rel="noopener noreferrer"
            >
              swift-complexity
            </a>
          </p>
        </div>
      </footer>
    </div>
  );
}
