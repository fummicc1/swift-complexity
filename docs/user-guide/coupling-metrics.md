# Type Coupling Metrics

swift-complexity measures type-level coupling — how tangled your types are
with each other — using the same IndexStoreDB semantic analysis that powers
LCOM4. Together with complexity (readability of one function) and cohesion
(consistency inside one type), coupling completes the classic
"high cohesion, low coupling" pair.

## The Metrics

| Metric | Meaning | Reading |
| ------ | ------- | ------- |
| **fan-out** (efferent coupling) | How many other project types this type references | High = fragile: changes elsewhere break it |
| **fan-in** (afferent coupling) | How many other project types reference this type | High = wide blast radius: changing it ripples |
| **instability** | fan-out / (fan-in + fan-out), in 0...1 | 1.0 = free to change (entry points), 0.0 = must stay stable (core models) |

Instability describes a type's *role*, not a defect. Healthy dependencies
point from unstable code (CLI, UI) toward stable code (models, protocols) —
the Stable Dependencies Principle. A type with no project-internal coupling
at all has undefined instability, reported as `null`/`-`.

## Usage

Coupling analysis reads the index store your build produces:

```bash
swift build
swift run swift-complexity Sources --coupling \
  --index-store-path .build/debug/index/store --recursive
```

On Linux, `--toolchain-path` is also required (same as `--lcom4`). Both
index-backed analyses share one index database, so combining
`--lcom4 --coupling` costs only one database load.

### Hotspots: which violation to fix first

When a complexity threshold is set alongside `--coupling`, the text output
ends with a hotspot ranking — complexity violations ordered by their
enclosing type's fan-in, so the most dangerous code surfaces first:

```console
Hotspots (complexity violations x fan-in):
| #  | Function             | Type                 | Fan-In | Cyclo | Cogn  |
+----+----------------------+----------------------+--------+-------+-------+
| 1  | format(_:options:)   | OutputFormatter      | 3      | 12    | 18    |
```

A complex function inside a high fan-in type is both hard to change and
depended upon by everything — fix those first.

## Thresholds and Gating

Coupling is **report-only by default**. Unlike cyclomatic complexity's
established 10/20 convention, there is no standard for "too much fan-out",
and sensible limits depend on codebase size — so swift-complexity ships no
default. To gate, set explicit limits in `.swift-complexity.yml`:

```yaml
coupling:
  fanOut: 15   # exit code 1 when a type's fan-out reaches 15
  # fanIn: 25  # available, but start with fanOut (see below)
```

With a limit configured, violations use the same `>=` semantics as the
complexity gate and appear in SARIF as `type_fan_out` / `type_fan_in`
(warning, error at double the threshold).

Prefer `fanOut` gating: a type that reaches into many others is usually a
refactoring signal by itself. High fan-in alone is often *good* (a stable
shared model); its risk only materializes combined with complexity, which is
what the hotspot ranking evaluates.

### Reference values

Measured on real codebases with this feature (no telemetry is ever
collected — these are one-off local measurements):

| Codebase | Types | Median fan-out | Max fan-out | Attribution |
| -------- | ----- | -------------- | ----------- | ----------- |
| Alamofire | 186 | 1 | 48 (`Session`) | 96% |
| swift-complexity (self) | 77 | 1 | 30 (`OutputFormatter`) | 99% |
| GeoHashSwift | 8 | 1 | 4 (`GeoHash`) | 100% |

The shape is consistent: most types couple to one or two others (median 1),
while a handful of hub types carry most of the coupling — those hubs are
where the fan-out numbers earn their keep.

The stderr diagnostics line reports attribution quality for your run:

```console
coupling: 5925 refs (2783 project), 99% attributed (containedBy 2769, baseOf 2, location 10), 2 unattributed
```

## Suppression

Exempt a type from coupling gating with an inline comment on its primary
declaration (values are still reported; only the judgment is skipped):

```swift
// swift-complexity:disable coupling
final class LegacyGodObject { ... }
```

A bare `// swift-complexity:disable` on a type suppresses every type-level
metric (LCOM4 and coupling). Comments on `extension` declarations are
ignored — suppression is scoped to the primary declaration so extensions
cannot contradict it.

## Semantics Details

- **Population**: only types defined in the analyzed paths count, for both
  ends of an edge. Standard library and framework references are excluded.
- **Distinct types**: referencing one type many times counts once.
- **Self references** never count.
- **Extensions** attribute their members to the extended type.
- **Nested types** are independent nodes (reported as `Outer.Inner`);
  references between nested and outer types count as edges.
- **Conformances** count as an edge from the conforming type to the
  protocol. Protocols therefore accumulate fan-in from their conformers —
  that is the healthy direction (abstractions are the stable side), not a
  smell.
- **Typealiases** are excluded in this version; references through an alias
  are dropped and counted in the diagnostics.

## Requirements and Limitations

- Requires a **built index store** (`swift build` first). Index freshness is
  your responsibility: analyze after building, not after editing.
- Not available through the GitHub Action's zero-toolchain path (bare
  runners have no build). Run it in a job that builds your package — see
  [CI Integration](ci-integration.md).
