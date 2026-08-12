# Golden fixtures for backward-compatibility regression tests

These files freeze the JSON output of the CLI **before** the coupling-metrics
feature (generated at commit `6aa21d0`, the `feature/coupling-metrics` branch
point). The regression test asserts that analysis without `--coupling` still
produces semantically identical output.

## Comparison contract

Raw output bytes are NOT comparable: `JSONEncoder` emits object keys in a
nondeterministic order (varies per process), and `Set<SuppressedMetric>`
encodes as an unordered array. The goldens are therefore stored in a
**canonical form**, and the test must canonicalize the current output the same
way before comparing:

1. Make `filePath` values repo-relative (strip the absolute repo-root prefix).
2. Sort all object keys.
3. Sort every `suppressedMetrics` array.

Everything else (file order, function order, all values) is deterministic and
must match exactly.

## Regeneration

Only regenerate from a commit that predates the change under test, otherwise
the regression guarantee is lost:

```bash
swift build
FIX=Tests/SwiftComplexityCoreTests/Fixtures
BIN=.build/debug/SwiftComplexityCLI
NORM='walk(if type=="object" and has("suppressedMetrics") and (.suppressedMetrics != null) then .suppressedMetrics |= sort else . end)'
"$BIN" "$FIX" --format json --recursive \
  | sed "s|$(pwd)/||g" | jq -S "$NORM" > "$FIX/golden/complexity_plain.json"
"$BIN" "$FIX" --format json --recursive --lcom4 --index-store-path .build/debug/index/store \
  | sed "s|$(pwd)/||g" | jq -S "$NORM" > "$FIX/golden/complexity_lcom4.json"
```

Note: the fixture inputs are the `.swift` files directly under `Fixtures/` at
generation time. New fixtures added for later features must live in
subdirectories that the golden test excludes, or the goldens become stale.
