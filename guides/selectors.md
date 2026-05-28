# Selectors

Selectors match requested taps to model-surface nodes.

## What This Covers

Selectors can match signal type, layer, token, head, or wildcard layer names.
Portable layer selectors resolve against the provider surface before matching.
Named selectors, such as `{:named, "decoder.final_norm"}`, become `layer_name`
matches and leave numeric layer selection unconstrained.

## Worked Example

```elixir
selector = CrucibleTap.TapSelector.new!(signal_type: :attention_maps, layer: [2, 3])
CrucibleTap.TapSelector.matches?(selector, %{signal_type: :attention_maps, layer_index: 3})
```

```elixir
selector = CrucibleTap.TapSelector.new!(signal_type: :hidden_state, layer: {:named, "decoder.final_norm"})
materialized = CrucibleTap.TapSelector.materialize(selector, [])
materialized.layer_name
```

## Related Guides

- [Tap Plans](tap_plans.md)
- [Capability Negotiation](capability_negotiation.md)
