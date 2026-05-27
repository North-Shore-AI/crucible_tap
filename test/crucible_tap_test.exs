defmodule CrucibleTapTest do
  use ExUnit.Case
  doctest CrucibleTap

  alias CrucibleTap.{
    CapabilityReport,
    CaptureBounds,
    PlanCompiler,
    Surface,
    SurfaceNode,
    TapPlan,
    TapSelector,
    TapSpec
  }

  test "exposes package version" do
    assert CrucibleTap.version() == "0.1.0"
  end

  test "builds capture bounds" do
    bounds = CaptureBounds.new!(max_elements: 128, max_bytes: 4096, top_k: 3)

    assert bounds.max_elements == 128
    assert bounds.max_bytes == 4096
    assert {:error, {:invalid_capture_bounds, _}} = CaptureBounds.new(max_elements: 0)
  end

  test "selectors match layer index, token index, head index, and layer pattern" do
    node =
      SurfaceNode.new!(
        id: "q",
        signal_type: :attention_q,
        layer_name: "decoder.blocks.3.self_attention.query",
        layer_index: 3,
        token_index: -1,
        head_index: 7
      )

    selector =
      TapSelector.new!(
        signal_type: :attention_q,
        layer: [2, 3],
        token: -1,
        head: 7,
        layer_name: "decoder.blocks.*.self_attention.query"
      )

    assert TapSelector.matches?(selector, Map.from_struct(node))
    refute TapSelector.matches?(%{selector | head: 4}, Map.from_struct(node))
  end

  test "builds tap specs and plans" do
    spec =
      TapSpec.new!(
        id: "late-logits",
        signal_type: :final_logits,
        operations: [:read, :route_on],
        layers: [:final],
        tokens: [-1],
        bounds: %{top_k: 10}
      )

    plan = TapPlan.new!([spec], plan_id: "plan-1")

    assert spec.signal_spec.operations == [:read, :route_on]
    assert spec.selector.signal_type == :final_logits
    assert spec.bounds.top_k == 10
    assert plan.specs == [spec]
  end

  test "surfaces expose capabilities" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :qwen3,
        nodes: [
          [
            id: "attn",
            signal_type: :attention_maps,
            layer_name: "decoder.blocks.0.attention",
            layer_index: 0,
            operations: [:read, :probe],
            capture_modes: [:summary, :sample]
          ]
        ]
      )

    [capability] = Surface.capabilities(surface)

    assert capability.signal_type == :attention_maps
    assert capability.adapter == :bumblebee
    assert capability.operations == [:read, :probe]
  end

  test "plan compiler matches supported taps" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :qwen3,
        nodes: [
          [
            id: "q",
            signal_type: :attention_q,
            layer_name: "decoder.blocks.2.self_attention.query",
            layer_index: 2,
            operations: [:read],
            capture_modes: [:summary]
          ]
        ]
      )

    plan =
      TapPlan.new!(
        [
          [
            id: "q-layer-2",
            signal_type: :attention_q,
            layers: [2],
            selector: %{layer_name: "decoder.blocks.*.self_attention.query"}
          ]
        ],
        plan_id: "plan-1"
      )

    assert {:ok, compiled} = PlanCompiler.compile(plan, surface)
    assert [%{tap_id: "q-layer-2", surface_node_id: "q"}] = compiled.matched
    assert CapabilityReport.ok?(compiled.report)
  end

  test "plan compiler reports unsupported optional and required taps" do
    surface = Surface.new!(adapter: :bumblebee, model_family: :qwen3, nodes: [])

    optional_plan =
      TapPlan.new!([
        [id: "optional", signal_type: :moe_router_logits, required?: false]
      ])

    assert {:ok, compiled} = PlanCompiler.compile(optional_plan, surface)
    assert [%{tap_id: "optional"}] = compiled.report.unsupported_optional

    required_plan =
      TapPlan.new!([
        [id: "required", signal_type: :mlp_gates, required?: true]
      ])

    assert {:error, report} = PlanCompiler.compile(required_plan, surface)
    assert [%{tap_id: "required"}] = report.unsupported_required
    refute CapabilityReport.ok?(report)
  end

  test "encodes plans to JSON" do
    plan = CrucibleTap.plan!([[id: "embeddings", signal_type: :embeddings]], plan_id: "plan-json")

    assert {:ok, json} = Jason.encode(plan)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["plan_id"] == "plan-json"
  end
end
