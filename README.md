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
model-internal forward-pass observations.

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

Documentation can be generated with `mix docs` and published to HexDocs.
