# Capability Negotiation

Capability negotiation reports satisfied taps and dropped optional taps.

## What This Covers

Required taps fail closed. Optional taps are never dropped silently.

## Worked Example

```elixir
surface = CrucibleTap.Surface.new!(adapter: :fixture, model_family: :dense, nodes: [])
plan = CrucibleTap.plan!([[id: "moe", signal_type: :moe_router_logits, required?: false]])
Crucible.CapabilityReport.negotiate(plan, surface, provider_kind: :fixture)
```

## Negotiation Contract

The provider-neutral entrypoint is `Crucible.CapabilityReport.negotiate/3`.
It returns the compiled plan and a canonical report, or fails closed when a
required tap is missing:

```elixir
{:ok, compiled, report} =
  Crucible.CapabilityReport.negotiate(plan, surface,
    provider_kind: :elixir_bumblebee,
    model_id: "hf-internal-testing/tiny-random-gpt2",
    backend: :binary
  )

report.optional_dropped
```

Portable layer selectors include `:first`, `:middle`, `:last`,
`{:fraction, 0.5}`, `{:last_n, 4}`, `{:indices, [0, 6, 12]}`, and
`{:named, "decoder.blocks.0"}`.

`{:named, name}` materializes to a `layer_name` match rather than a numeric
layer index. Use it for provider graph nodes that have stable names but no
portable block index.

## Related Guides

- [Plan Compilation](plan_compilation.md)
- [Testing](testing.md)
