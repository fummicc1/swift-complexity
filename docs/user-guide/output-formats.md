# Output Formats

swift-complexity supports five output formats for different use cases.

## Text Format (Default)

Human-readable table format for terminal display.

### Example Output

```
File: Sources/Calculator.swift
+------------------+----------+----------+
| Function/Method  | Cyclo.   | Cogn.    |
+------------------+----------+----------+
| calculateTotal() |    5     |    7     |
| validateInput()  |    3     |    4     |
| processData()    |    8     |   12     |
+------------------+----------+----------+
Total: 3 functions, Average Cyclomatic: 5.3, Average Cognitive: 7.7

File: Sources/Validator.swift
+------------------+----------+----------+
| Function/Method  | Cyclo.   | Cogn.    |
+------------------+----------+----------+
| validate()       |    2     |    3     |
| sanitize()       |    4     |    5     |
+------------------+----------+----------+
Total: 2 functions, Average Cyclomatic: 3.0, Average Cognitive: 4.0
```

### Usage

```bash
swift run swift-complexity Sources --format text
# or simply (text is default)
swift run swift-complexity Sources
```

## JSON Format

Structured data format for tool integration and programmatic processing.

### Schema

```json
{
  "files": [
    {
      "filePath": "string",
      "functions": [
        {
          "name": "string",
          "signature": "string", 
          "cyclomaticComplexity": "number",
          "cognitiveComplexity": "number",
          "location": {
            "line": "number",
            "column": "number"
          }
        }
      ],
      "summary": {
        "totalFunctions": "number",
        "averageCyclomaticComplexity": "number",
        "averageCognitiveComplexity": "number",
        "maxCyclomaticComplexity": "number",
        "maxCognitiveComplexity": "number",
        "totalCyclomaticComplexity": "number",
        "totalCognitiveComplexity": "number"
      }
    }
  ]
}
```

### Example Output

```json
{
  "files": [
    {
      "filePath": "Sources/Calculator.swift",
      "functions": [
        {
          "name": "calculateTotal()",
          "signature": "func calculateTotal(items: [Item]) -> Double",
          "cyclomaticComplexity": 5,
          "cognitiveComplexity": 7,
          "location": {
            "line": 15,
            "column": 5
          }
        },
        {
          "name": "validateInput()",
          "signature": "func validateInput(_ input: String) -> Bool",
          "cyclomaticComplexity": 3,
          "cognitiveComplexity": 4,
          "location": {
            "line": 32,
            "column": 5
          }
        }
      ],
      "summary": {
        "totalFunctions": 2,
        "averageCyclomaticComplexity": 4.0,
        "averageCognitiveComplexity": 5.5,
        "maxCyclomaticComplexity": 5,
        "maxCognitiveComplexity": 7,
        "totalCyclomaticComplexity": 8,
        "totalCognitiveComplexity": 11
      }
    }
  ]
}
```

### Usage

```bash
swift run swift-complexity Sources --format json > complexity-report.json
```

### Integration Examples

**JavaScript/Node.js**:
```javascript
const fs = require('fs');
const report = JSON.parse(fs.readFileSync('complexity-report.json'));

report.files.forEach(file => {
  console.log(`File: ${file.filePath}`);
  console.log(`Average Complexity: ${file.summary.averageCyclomaticComplexity}`);
});
```

**Python**:
```python
import json

with open('complexity-report.json') as f:
    report = json.load(f)

for file in report['files']:
    high_complexity = [f for f in file['functions'] 
                      if f['cyclomaticComplexity'] > 10]
    if high_complexity:
        print(f"High complexity functions in {file['filePath']}:")
        for func in high_complexity:
            print(f"  {func['name']}: {func['cyclomaticComplexity']}")
```

## XML Format

Structured XML format for integration with reporting tools and IDEs.

### Schema

```xml
<?xml version="1.0" encoding="UTF-8"?>
<complexity-report>
  <file path="string">
    <function name="string" signature="string" line="number" column="number">
      <cyclomatic-complexity>number</cyclomatic-complexity>
      <cognitive-complexity>number</cognitive-complexity>
    </function>
    <summary>
      <total-functions>number</total-functions>
      <average-cyclomatic-complexity>number</average-cyclomatic-complexity>
      <average-cognitive-complexity>number</average-cognitive-complexity>
      <max-cyclomatic-complexity>number</max-cyclomatic-complexity>
      <max-cognitive-complexity>number</max-cognitive-complexity>
    </summary>
  </file>
</complexity-report>
```

### Example Output

```xml
<?xml version="1.0" encoding="UTF-8"?>
<complexity-report>
  <file path="Sources/Calculator.swift">
    <function name="calculateTotal()" 
              signature="func calculateTotal(items: [Item]) -> Double"
              line="15" column="5">
      <cyclomatic-complexity>5</cyclomatic-complexity>
      <cognitive-complexity>7</cognitive-complexity>
    </function>
    <function name="validateInput()"
              signature="func validateInput(_ input: String) -> Bool" 
              line="32" column="5">
      <cyclomatic-complexity>3</cyclomatic-complexity>
      <cognitive-complexity>4</cognitive-complexity>
    </function>
    <summary>
      <total-functions>2</total-functions>
      <average-cyclomatic-complexity>4.0</average-cyclomatic-complexity>
      <average-cognitive-complexity>5.5</average-cognitive-complexity>
      <max-cyclomatic-complexity>5</max-cyclomatic-complexity>
      <max-cognitive-complexity>7</max-cognitive-complexity>
    </summary>
  </file>
</complexity-report>
```

### Usage

```bash
swift run swift-complexity Sources --format xml > complexity-report.xml
```

### Integration Examples

**XSLT Transformation**:
```xsl
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="/">
    <html>
      <body>
        <h1>Complexity Report</h1>
        <xsl:for-each select="complexity-report/file">
          <h2><xsl:value-of select="@path"/></h2>
          <table border="1">
            <tr><th>Function</th><th>Cyclomatic</th><th>Cognitive</th></tr>
            <xsl:for-each select="function">
              <tr>
                <td><xsl:value-of select="@name"/></td>
                <td><xsl:value-of select="cyclomatic-complexity"/></td>
                <td><xsl:value-of select="cognitive-complexity"/></td>
              </tr>
            </xsl:for-each>
          </table>
        </xsl:for-each>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
```

## Xcode Diagnostics Format

Emits `file:line:column: severity: message` lines that Xcode picks up as inline
warnings and errors. Functions above the threshold produce a `warning`, and
functions above twice the threshold produce an `error`.

### Example Output

```text
/path/to/Sources/MyFile.swift:45:1: error: Function 'complexFunction' has high complexity (Cyclomatic: 15, Cognitive: 23, Threshold: 10)
/path/to/Sources/MyFile.swift:89:1: warning: Function 'anotherFunction' has high complexity (Cyclomatic: 12, Cognitive: 18, Threshold: 10)
```

### Usage

```bash
swift run swift-complexity Sources --format xcode --threshold 10
```

## SARIF Format

[SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
(Static Analysis Results Interchange Format) is the standard interchange format
consumed by GitHub Code Scanning and many other analysis platforms.

Each metric violation becomes one SARIF result:

| Rule ID | Trigger | Level |
|---------|---------|-------|
| `cyclomatic_complexity` | Cyclomatic complexity >= threshold | `warning`, `error` at 2x threshold |
| `cognitive_complexity` | Cognitive complexity >= threshold | `warning`, `error` at 2x threshold |
| `lcom4_cohesion` | LCOM4 >= 3 (low cohesion) | `warning`, `error` at LCOM4 >= 5 |

Violation detection uses the same `>=` semantics as the exit-code check, so a
non-empty `results` array always coincides with exit code 1.

> **Note**: A threshold is required (via `--threshold` or a config file) for
> complexity results to be reported. Without one, the report is empty and a
> warning is printed to stderr.

File paths are emitted relative to the current working directory, so run the
tool from your repository root for GitHub-compatible URIs.

### Example Output

```json
{
  "$schema" : "https://json.schemastore.org/sarif-2.1.0.json",
  "version" : "2.1.0",
  "runs" : [
    {
      "tool" : {
        "driver" : {
          "name" : "swift-complexity",
          "version" : "1.2.1",
          "informationUri" : "https://github.com/fummicc1/swift-complexity",
          "rules" : [...]
        }
      },
      "results" : [
        {
          "ruleId" : "cognitive_complexity",
          "level" : "warning",
          "message" : {
            "text" : "Function 'processData' has cognitive complexity 12 (threshold: 10)"
          },
          "locations" : [
            {
              "physicalLocation" : {
                "artifactLocation" : { "uri" : "Sources/Calculator.swift" },
                "region" : { "startLine" : 42, "startColumn" : 5 }
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### Usage

```bash
swift run swift-complexity Sources --format sarif --threshold 10 --recursive > swift-complexity.sarif
```

### GitHub Code Scanning Integration

Upload the report in a GitHub Actions workflow to see violations as pull
request annotations and in the repository's Security tab:

```yaml
- name: Analyze complexity
  run: swift-complexity Sources --format sarif --threshold 10 --recursive > swift-complexity.sarif

- name: Upload SARIF
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: swift-complexity.sarif
```

`if: always()` ensures the report is uploaded even when the analysis step fails
the build via exit code 1.

## Choosing the Right Format

| Format | Use Case | Best For |
|--------|----------|----------|
| **Text** | Terminal display, quick review | Developers, manual inspection |
| **JSON** | Tool integration, scripts | CI/CD, analysis tools, dashboards |
| **XML** | Enterprise reporting, XSLT | Report generation, IDE integration |
| **Xcode** | In-editor diagnostics | Xcode users, build tool plugins |
| **SARIF** | Code scanning platforms | GitHub Code Scanning, PR annotations |