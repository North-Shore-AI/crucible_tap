# Quickstart

Build tap plans without binding them to one model family.

## What This Covers

This guide creates a trajectory tap and negotiates it against a fixture surface.

## Worked Example

```elixir
plan = CrucibleTap.trajectory_tap("route", [4, 8, 12])
Enum.map(plan.specs, & &1.signal_spec.capture_mode)
```

## Related Guides

- [Tap Plans](tap_plans.md)
- [Capability Negotiation](capability_negotiation.md)
