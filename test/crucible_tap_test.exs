defmodule CrucibleTapTest do
  use ExUnit.Case
  doctest CrucibleTap

  alias Crucible.CapabilityReport, as: CanonicalCapabilityReport

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
        kind: :read,
        layers: [:final],
        tokens: [-1],
        bounds: %{top_k: 10}
      )

    plan = TapPlan.new!([spec], plan_id: "plan-1")

    assert spec.signal_spec.operations == [:read, :route_on]
    assert spec.kind == :read
    assert spec.selector.signal_type == :final_logits
    assert spec.bounds.top_k == 10
    assert plan.specs == [spec]
  end

  test "validates active tap kinds" do
    assert TapSpec.new!(id: "inject", signal_type: :middle_residuals, kind: :inject).kind ==
             :inject

    assert TapSpec.new!(id: "gate", signal_type: :final_logits, kind: :gate).kind == :gate

    assert TapSpec.active?(
             TapSpec.new!(id: "inject", signal_type: :middle_residuals, kind: :inject)
           )

    assert TapSpec.passive?(TapSpec.new!(id: "read", signal_type: :final_logits, kind: :read))

    assert {:error, {:unknown_tap_kind, :mutate}} =
             TapSpec.new(id: "bad", signal_type: :final_logits, kind: :mutate)
  end

  test "portable layer selectors resolve across block counts" do
    assert TapSelector.resolve_layers(:first, 12) == [0]
    assert TapSelector.resolve_layers(:middle, 12) == [6]
    assert TapSelector.resolve_layers(:last, 12) == [11]
    assert TapSelector.resolve_layers({:fraction, 0.25}, 12) == [3]
    assert TapSelector.resolve_layers({:last_n, 3}, 12) == [9, 10, 11]
    assert TapSelector.resolve_layers({:indices, [0, 4, 8]}, 12) == [0, 4, 8]

    assert {:ok, {:named, "decoder.final_norm"}} =
             TapSelector.parse_keyword("named:decoder.final_norm")
  end

  test "builds trajectory taps as plan-level combinators" do
    plan = CrucibleTap.trajectory_tap("route", [4, 8, 12])

    assert Enum.map(plan.specs, & &1.signal_spec.layers) == [[4], [8], [12]]
    assert Enum.all?(plan.specs, &(&1.signal_spec.capture_mode == :compressed_vector))
    assert Enum.all?(plan.specs, &(&1.kind == :read))
  end

  test "surfaces expose capabilities" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture_decoder,
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
        model_family: :fixture_decoder,
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
    assert compiled.hooks == ["decoder.blocks.2.self_attention.query"]
    assert CapabilityReport.ok?(compiled.report)
  end

  test "plan compiler emits per-layer descriptors" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [
          [
            id: "h4",
            signal_type: :middle_residuals,
            layer_index: 4,
            layer_name: "block.4",
            capture_modes: [:summary, :compressed_vector]
          ],
          [
            id: "h8",
            signal_type: :middle_residuals,
            layer_index: 8,
            layer_name: "block.8",
            capture_modes: [:summary, :compressed_vector]
          ]
        ]
      )

    plan = CrucibleTap.trajectory_tap("traj", [4, 8])

    assert {:ok, compiled} = PlanCompiler.compile(plan, surface)
    assert compiled.layer_descriptors[4].capture == :compressed_vector
    assert compiled.global_layer_options == []
  end

  test "plan compiler reports unsupported optional and required taps" do
    surface = Surface.new!(adapter: :bumblebee, model_family: :fixture_decoder, nodes: [])

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

  test "required and optional hidden-state taps fail closed or degrade explicitly" do
    surface = Surface.new!(adapter: :bumblebee, model_family: :gpt2, nodes: [])

    required_plan = TapPlan.new!([[id: "hidden", signal_type: :hidden_state, required?: true]])
    optional_plan = TapPlan.new!([[id: "hidden", signal_type: :hidden_state, required?: false]])

    assert {:error, report} = PlanCompiler.compile(required_plan, surface)
    assert [%{tap_id: "hidden", reason: :no_surface_node}] = report.unsupported_required

    assert {:ok, compiled} = PlanCompiler.compile(optional_plan, surface)
    assert [%{tap_id: "hidden", reason: :no_surface_node}] = compiled.report.unsupported_optional
  end

  test "generation step logits required and optional behavior is explicit" do
    surface = Surface.new!(adapter: :bumblebee, model_family: :gpt2, nodes: [])

    assert {:error, report} =
             PlanCompiler.compile(
               TapPlan.new!([[id: "step-logits", signal_type: :generation_step_logits]]),
               surface
             )

    assert [%{reason: :no_surface_node}] = report.unsupported_required

    assert {:ok, compiled} =
             PlanCompiler.compile(
               TapPlan.new!([
                 [id: "step-logits", signal_type: :generation_step_logits, required?: false]
               ]),
               surface
             )

    assert [%{reason: :no_surface_node}] = compiled.report.unsupported_optional
  end

  test "signal tap classes compile when the surface exposes them" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [
          [id: "attn", signal_type: :attention_weights, operations: [:read]],
          [id: "resid", signal_type: :residual_stream, operations: [:read]],
          [id: "mlp", signal_type: :mlp_activation, operations: [:read]],
          [id: "kv", signal_type: :kv_cache_metadata, operations: [:read]],
          [id: "router", signal_type: :router_logits, operations: [:read]],
          [id: "experts", signal_type: :moe_expert_weights, operations: [:read]]
        ]
      )

    plan =
      TapPlan.new!([
        [id: "attn", signal_type: :attention_weights],
        [id: "resid", signal_type: :residual_stream],
        [id: "mlp", signal_type: :mlp_activation],
        [id: "kv", signal_type: :kv_cache_metadata],
        [id: "router", signal_type: :router_logits],
        [id: "experts", signal_type: :moe_expert_weights]
      ])

    assert {:ok, compiled} = PlanCompiler.compile(plan, surface)

    assert compiled.matched |> Enum.map(& &1.tap_id) |> Enum.sort() ==
             ~w(attn experts kv mlp resid router)
  end

  test "required raw capture disallowed by bounds fails closed" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [
          [
            id: "resid",
            signal_type: :residual_stream,
            operations: [:read],
            capture_modes: [:summary, :raw]
          ]
        ]
      )

    required_plan =
      TapPlan.new!([
        [
          id: "raw-resid",
          signal_type: :residual_stream,
          capture_mode: :raw,
          required?: true
        ]
      ])

    assert {:error, report} = PlanCompiler.compile(required_plan, surface)
    assert [%{tap_id: "raw-resid", reason: :raw_capture_disallowed}] = report.unsupported_required
  end

  test "optional raw capture disallowed by bounds degrades explicitly" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [
          [
            id: "resid",
            signal_type: :residual_stream,
            operations: [:read],
            capture_modes: [:summary, :raw]
          ]
        ]
      )

    optional_plan =
      TapPlan.new!([
        [
          id: "raw-resid",
          signal_type: :residual_stream,
          capture_mode: :raw,
          required?: false
        ]
      ])

    assert {:ok, compiled} = PlanCompiler.compile(optional_plan, surface)

    assert [%{tap_id: "raw-resid", reason: :raw_capture_disallowed}] =
             compiled.report.unsupported_optional
  end

  test "required unsupported capture mode fails closed when raw is allowed" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [
          [
            id: "resid",
            signal_type: :residual_stream,
            operations: [:read],
            capture_modes: [:summary]
          ]
        ]
      )

    required_plan =
      TapPlan.new!([
        [
          id: "raw-resid",
          signal_type: :residual_stream,
          capture_mode: :raw,
          bounds: [raw_allowed?: true],
          required?: true
        ]
      ])

    assert {:error, report} = PlanCompiler.compile(required_plan, surface)

    assert [%{tap_id: "raw-resid", reason: :unsupported_capture_mode}] =
             report.unsupported_required
  end

  test "optional unsupported capture mode degrades explicitly when raw is allowed" do
    surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [
          [
            id: "resid",
            signal_type: :residual_stream,
            operations: [:read],
            capture_modes: [:summary]
          ]
        ]
      )

    optional_plan =
      TapPlan.new!([
        [
          id: "raw-resid",
          signal_type: :residual_stream,
          capture_mode: :raw,
          bounds: [raw_allowed?: true],
          required?: false
        ]
      ])

    assert {:ok, compiled} = PlanCompiler.compile(optional_plan, surface)

    assert [%{tap_id: "raw-resid", reason: :unsupported_capture_mode}] =
             compiled.report.unsupported_optional
  end

  test "capability report JSON roundtrips" do
    report =
      CanonicalCapabilityReport.new(
        provider_kind: :fixture,
        model_id: "model:fixture",
        model_family: :dense_fixture,
        backend: :fixture,
        supported: ["final-logits"],
        unsupported: [
          %Crucible.UnsupportedCapability{
            capability: "hidden",
            reason: :no_surface_node,
            required?: false,
            metadata: %{}
          }
        ],
        required_missing: [],
        optional_dropped: ["hidden"]
      )

    assert {:ok, json} = Jason.encode(report)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["provider_kind"] == "fixture"
    assert decoded["model_id"] == "model:fixture"
    assert decoded["optional_dropped"] == ["hidden"]
    assert [%{"capability" => "hidden", "reason" => "no_surface_node"}] = decoded["unsupported"]
  end

  test "gate taps cannot be satisfied by passive read-only nodes" do
    passive_surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [[id: "resid", signal_type: :residual_stream, operations: [:read]]]
      )

    gate_plan = TapPlan.new!([[id: "gate", signal_type: :residual_stream, kind: :gate]])

    assert {:error, report} = PlanCompiler.compile(gate_plan, passive_surface)
    assert [%{reason: :unsupported_operation}] = report.unsupported_required

    active_surface =
      Surface.new!(
        adapter: :native_fixture,
        model_family: :fixture,
        nodes: [[id: "resid", signal_type: :residual_stream, operations: [:read, :gate]]]
      )

    assert {:ok, compiled} = PlanCompiler.compile(gate_plan, active_surface)
    assert [%{metadata: %{active?: true, required_operation: :gate}}] = compiled.matched
  end

  test "active taps cannot be satisfied by passive read-only nodes" do
    passive_surface =
      Surface.new!(
        adapter: :bumblebee,
        model_family: :fixture,
        nodes: [[id: "resid", signal_type: :residual_stream, operations: [:read]]]
      )

    active_plan = TapPlan.new!([[id: "inject", signal_type: :residual_stream, kind: :inject]])

    assert {:error, report} = PlanCompiler.compile(active_plan, passive_surface)
    assert [%{reason: :unsupported_operation}] = report.unsupported_required

    active_surface =
      Surface.new!(
        adapter: :native_fixture,
        model_family: :fixture,
        nodes: [[id: "resid", signal_type: :residual_stream, operations: [:read, :fuse]]]
      )

    assert {:ok, compiled} = PlanCompiler.compile(active_plan, active_surface)
    assert [%{metadata: %{active?: true, required_operation: :fuse}}] = compiled.matched
  end

  test "capability negotiation returns rich dropped optional reasons" do
    surface = Surface.new!(adapter: :bumblebee, model_family: :dense_fixture, nodes: [])

    optional_plan =
      TapPlan.new!([
        [id: "optional", signal_type: :moe_router_logits, required?: false]
      ])

    assert {:ok, _compiled, report} =
             CanonicalCapabilityReport.negotiate(optional_plan, surface)

    assert report.supported == []
    assert report.optional_dropped == ["optional"]

    assert [%Crucible.UnsupportedCapability{capability: "optional", reason: :no_surface_node}] =
             report.unsupported

    required_plan = TapPlan.new!([[id: "required", signal_type: :mlp_gates]])

    assert {:error, {:tap_compile_failed, report}} =
             CanonicalCapabilityReport.negotiate(required_plan, surface)

    assert report.required_missing == ["required"]

    assert [%Crucible.FailedCapability{capability: "required", reason: :no_surface_node}] =
             report.failed
  end

  test "tap report does not expose a duplicate negotiation entrypoint" do
    refute function_exported?(CapabilityReport, :negotiate, 2)
  end

  test "encodes plans to JSON" do
    plan = CrucibleTap.plan!([[id: "embeddings", signal_type: :embeddings]], plan_id: "plan-json")

    assert {:ok, json} = Jason.encode(plan)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["plan_id"] == "plan-json"
  end

  test "compiled plan JSON roundtrips" do
    surface =
      Surface.new!(
        adapter: :fixture,
        model_family: :dense_fixture,
        nodes: [[id: "logits", signal_type: :final_logits, operations: [:read]]]
      )

    plan = TapPlan.new!([[id: "logits", signal_type: :final_logits]])
    assert {:ok, compiled} = PlanCompiler.compile(plan, surface)

    assert {:ok, json} = Jason.encode(compiled)
    assert {:ok, decoded} = Jason.decode(json)
    assert decoded["plan_id"] == compiled.plan_id
    assert [%{"tap_id" => "logits"}] = decoded["matched"]
    assert decoded["report"]["adapter"] == "fixture"
  end
end
