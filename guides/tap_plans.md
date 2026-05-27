# Tap Plans

Tap plans are ordered groups of tap specs.

## What This Covers

Each tap has a signal spec, selector, capture bounds, kind, and required flag.

## Worked Example

```elixir
CrucibleTap.plan!([
  [id: "final", signal_type: :final_logits, kind: :read]
])
```

## Related Guides

- [Quickstart](quickstart.md)
- [Selectors](selectors.md)
