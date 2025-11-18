import type { ComplexityResult } from "@/types/complexity";

type ComplexityResultsProps = {
  result: ComplexityResult | null;
  loading: boolean;
  error: string | null;
};

export default function ComplexityResults({
  result,
  loading,
  error,
}: ComplexityResultsProps) {
  if (loading) {
    return (
      <div className="p-6 bg-gray-800 rounded-lg">
        <p className="text-gray-400">Analyzing code...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 bg-red-900/20 border border-red-500 rounded-lg">
        <p className="text-red-400">Error: {error}</p>
      </div>
    );
  }

  if (!result) {
    return (
      <div className="p-6 bg-gray-800 rounded-lg">
        <p className="text-gray-400">
          Enter Swift code and click Analyze to see complexity metrics
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* File Summary */}
      <div className="p-6 bg-gray-800 rounded-lg">
        <h2 className="text-xl font-semibold mb-4">Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
          <div>
            <p className="text-sm text-gray-400">Total Functions</p>
            <p className="text-2xl font-bold">{result.summary.totalFunctions}</p>
          </div>
          <div>
            <p className="text-sm text-gray-400">Avg Cyclomatic</p>
            <p className="text-2xl font-bold">
              {result.summary.averageCyclomaticComplexity.toFixed(1)}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-400">Avg Cognitive</p>
            <p className="text-2xl font-bold">
              {result.summary.averageCognitiveComplexity.toFixed(1)}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-400">Max Cyclomatic</p>
            <p className="text-2xl font-bold">
              {result.summary.maxCyclomaticComplexity}
            </p>
          </div>
          <div>
            <p className="text-sm text-gray-400">Max Cognitive</p>
            <p className="text-2xl font-bold">
              {result.summary.maxCognitiveComplexity}
            </p>
          </div>
        </div>
      </div>

      {/* Functions Table */}
      <div className="p-6 bg-gray-800 rounded-lg">
        <h2 className="text-xl font-semibold mb-4">Functions</h2>
        {result.functions.length === 0 ? (
          <p className="text-gray-400">No functions detected</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-700">
                  <th className="text-left py-2 px-4">Function</th>
                  <th className="text-left py-2 px-4">Location</th>
                  <th className="text-right py-2 px-4">Cyclomatic</th>
                  <th className="text-right py-2 px-4">Cognitive</th>
                </tr>
              </thead>
              <tbody>
                {result.functions.map((func, index) => (
                  <tr key={index} className="border-b border-gray-700/50">
                    <td className="py-2 px-4 font-mono text-sm">{func.name}</td>
                    <td className="py-2 px-4 text-sm text-gray-400">
                      {func.location.line}:{func.location.column}
                    </td>
                    <td
                      className={`py-2 px-4 text-right font-semibold ${
                        func.cyclomaticComplexity > 10
                          ? "text-red-400"
                          : func.cyclomaticComplexity > 5
                          ? "text-yellow-400"
                          : "text-green-400"
                      }`}
                    >
                      {func.cyclomaticComplexity}
                    </td>
                    <td
                      className={`py-2 px-4 text-right font-semibold ${
                        func.cognitiveComplexity > 10
                          ? "text-red-400"
                          : func.cognitiveComplexity > 5
                          ? "text-yellow-400"
                          : "text-green-400"
                      }`}
                    >
                      {func.cognitiveComplexity}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
