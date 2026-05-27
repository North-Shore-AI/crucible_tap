<p align="center">
  <img src="assets/crucible_tap.svg" width="200" height="200" alt="crucible_tap logo" />
</p>

<p align="center">
  <a href="https://github.com/North-Shore-AI/crucible_tap">
    <img alt="GitHub: crucible_tap" src="https://img.shields.io/badge/GitHub-crucible_tap-0b0f14?logo=github" />
  </a>
  <a href="https://github.com/North-Shore-AI/crucible_tap/blob/main/LICENSE">
    <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0b0f14.svg" />
  </a>
</p>

# CrucibleTap

Tap-plan and probe-contract library for selecting, bounding, and negotiating
model-internal forward-pass observations. Plans are model-agnostic; surfaces
advertise which signals and active controls they support.

## Stack Position

`crucible_tap` sits above `crucible_signal`. It defines requested observations
and capability negotiation, while adapter-specific compilation belongs in
`crucible_bumblebee`.

## Installation

```elixir
def deps do
  [
    {:crucible_tap, "~> 0.1.0"}
  ]
end
```

## Boundary

This package owns tap plans, selectors, capture bounds, capability reports, and
tap results. It does not execute model graphs, persist traces, or choose
policies.

## Usage

```elixir
alias CrucibleTap.{PlanCompiler, Surface, TapPlan}

surface =
  Surface.new!(
    adapter: :fixture,
    model_family: :dense_decoder,
    nodes: [
      [
        id: "q-layer-2",
        signal_type: :attention_q,
        layer_name: "decoder.blocks.2.self_attention.query",
        layer_index: 2
      ]
    ]
  )

plan =
  TapPlan.new!([
    [
      id: "capture-q",
      signal_type: :attention_q,
      layers: [2],
      selector: %{layer_name: "decoder.blocks.*.self_attention.query"}
    ]
  ])

{:ok, compiled} = PlanCompiler.compile(plan, surface)
```

## Guides

- [Quickstart](guides/quickstart.md)
- [Concepts](guides/concepts.md)
- [Tap Plans](guides/tap_plans.md)
- [Selectors](guides/selectors.md)
- [Capability Negotiation](guides/capability_negotiation.md)
- [Plan Compilation](guides/plan_compilation.md)
- [Working Examples](guides/working_examples.md)
- [Testing](guides/testing.md)

## Examples

- `examples/build_plan_mock.exs`
- `examples/compile_plan_live.exs`

## Testing

- Default suite: `mix test`
- Full local gate: `mix ci`

Documentation can be generated with `mix docs` and published to HexDocs.
