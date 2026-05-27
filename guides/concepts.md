# Concepts

Tap plans declare requested signals; surfaces declare what a backend can provide.

## What This Covers

Passive reads, active injections, and gates share one plan shape but negotiate separately.

## Worked Example

```elixir
CrucibleTap.TapSpec.new!(id: "logits", signal_type: :final_logits, kind: :read)
```

## Related Guides

- [Selectors](selectors.md)
- [Plan Compilation](plan_compilation.md)
