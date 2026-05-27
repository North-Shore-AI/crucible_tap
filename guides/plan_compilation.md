# Plan Compilation

Compiled plans carry matched nodes and per-layer descriptors.

## What This Covers

For standard model surfaces, layer descriptors guide post-processing. Graph-level selective capture is capability-gated.

## Worked Example

```elixir
plan = CrucibleTap.trajectory_tap("traj", [4, 8])
plan.plan_id
```

## Related Guides

- [Capability Negotiation](capability_negotiation.md)
- [Concepts](concepts.md)
