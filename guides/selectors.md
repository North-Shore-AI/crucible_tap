# Selectors

Selectors match requested taps to model-surface nodes.

## What This Covers

Selectors can match signal type, layer, token, head, or wildcard layer names.

## Worked Example

```elixir
selector = CrucibleTap.TapSelector.new!(signal_type: :attention_maps, layer: [2, 3])
CrucibleTap.TapSelector.matches?(selector, %{signal_type: :attention_maps, layer_index: 3})
```

## Related Guides

- [Tap Plans](tap_plans.md)
- [Capability Negotiation](capability_negotiation.md)
