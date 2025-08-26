# Output Formats

swift-complexity supports three output formats for different use cases.

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

## Choosing the Right Format

| Format | Use Case | Best For |
|--------|----------|----------|
| **Text** | Terminal display, quick review | Developers, manual inspection |
| **JSON** | Tool integration, scripts | CI/CD, analysis tools, dashboards |
| **XML** | Enterprise reporting, XSLT | Report generation, IDE integration |