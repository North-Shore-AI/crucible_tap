# Capability Negotiation

Capability negotiation reports satisfied taps and dropped optional taps.

## What This Covers

Required taps fail closed. Optional taps are never dropped silently.

## Worked Example

```elixir
surface = CrucibleTap.Surface.new!(adapter: :fixture, model_family: :dense, nodes: [])
plan = CrucibleTap.plan!([[id: "moe", signal_type: :moe_router_logits, required?: false]])
CrucibleTap.CapabilityReport.negotiate(plan, surface)
```

## Related Guides

- [Plan Compilation](plan_compilation.md)
- [Testing](testing.md)
