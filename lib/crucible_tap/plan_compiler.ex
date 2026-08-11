defmodule CrucibleTap.PlanCompiler do
  @moduledoc """
  Negotiates a tap plan against an adapter-declared surface.
  """

  alias CrucibleTap.{
    CapabilityReport,
    CompiledPlan,
    Surface,
    TapPlan,
    TapResult,
    TapSpec
  }

  def compile(%TapPlan{} = plan, %Surface{} = surface) do
    {matched, unsupported_required, unsupported_optional} =
      Enum.reduce(plan.specs, {[], [], []}, fn spec, {matched, required, optional} ->
        nodes = Surface.matching_nodes(surface, spec.selector)
        {node_matches, node_unsupported} = compile_nodes(spec, nodes, surface)

        cond do
          node_matches != [] ->
            {node_matches ++ matched, required, node_unsupported ++ optional}

          node_unsupported != [] and spec.required? ->
            {matched, node_unsupported ++ required, optional}

          node_unsupported != [] ->
            {matched, required, node_unsupported ++ optional}

          true ->
            categorize_missing_node(spec, surface, matched, required, optional)
        end
      end)

    report = %CapabilityReport{
      adapter: surface.adapter,
      model_family: surface.model_family,
      matched: Enum.reverse(matched),
      unsupported_required: Enum.reverse(unsupported_required),
      unsupported_optional: Enum.reverse(unsupported_optional),
      capabilities: Surface.capabilities(surface)
    }

    if CapabilityReport.ok?(report) do
      {:ok,
       %CompiledPlan{
         plan_id: plan.plan_id,
         matched: report.matched,
         layer_descriptors: layer_descriptors(plan),
         global_layer_options: global_options(plan),
         hooks: hooks(report),
         extractors: extractors(report),
         report: report
       }}
    else
      {:error, report}
    end
  end

  defp compile_nodes(%TapSpec{} = spec, nodes, %Surface{} = surface) do
    nodes
    |> Enum.map(&compile_node(spec, &1, surface))
    |> Enum.split_with(&(&1.status == :matched))
  end

  defp categorize_missing_node(spec, surface, matched, required, optional) do
    result = unsupported_result(spec, :no_surface_node, surface)

    if spec.required? do
      {matched, [result | required], optional}
    else
      {matched, required, [result | optional]}
    end
  end

  defp compile_node(%TapSpec{} = spec, node, %Surface{} = surface) do
    cond do
      spec.signal_spec.capture_mode == :raw and not spec.bounds.raw_allowed? ->
        unsupported_result(spec, :raw_capture_disallowed, surface, node)

      required_operation(spec) not in node.operations ->
        unsupported_result(spec, :unsupported_operation, surface, node)

      spec.signal_spec.capture_mode not in node.capture_modes ->
        unsupported_result(spec, :unsupported_capture_mode, surface, node)

      true ->
        %TapResult{
          tap_id: spec.id,
          status: :matched,
          surface_node_id: node.id,
          metadata: %{
            layer_name: node.layer_name,
            kind: spec.kind,
            active?: TapSpec.active?(spec),
            activation_name: node.activation_name,
            component: node.component,
            axes: node.axes,
            layer_index: node.layer_index,
            required_operation: required_operation(spec),
            capture_mode: spec.signal_spec.capture_mode
          }
        }
    end
  end

  defp unsupported_result(%TapSpec{} = spec, reason, %Surface{} = surface, node \\ nil) do
    %TapResult{
      tap_id: spec.id,
      status: :unsupported,
      surface_node_id: if(node, do: node.id),
      reason: reason,
      metadata: %{
        kind: spec.kind,
        active?: TapSpec.active?(spec),
        limitation: :surface,
        adapter: surface.adapter,
        model_family: surface.model_family,
        activation_name: spec.selector.activation_name,
        component: spec.selector.component,
        axes: spec.selector.axes,
        required_operation: required_operation(spec),
        capture_mode: spec.signal_spec.capture_mode
      }
    }
  end

  defp required_operation(%TapSpec{kind: :inject}), do: :fuse
  defp required_operation(%TapSpec{kind: :gate}), do: :gate
  defp required_operation(%TapSpec{kind: :auxiliary}), do: :probe
  defp required_operation(%TapSpec{}), do: :read

  defp layer_descriptors(%TapPlan{} = plan) do
    plan.specs
    |> Enum.flat_map(fn spec ->
      spec.signal_spec.layers
      |> List.wrap()
      |> Enum.reject(&(&1 in [:all, :final]))
      |> Enum.map(fn layer ->
        {layer,
         %{
           tap_id: spec.id,
           kind: spec.kind,
           signal_type: spec.signal_spec.signal_type,
           capture: spec.signal_spec.capture_mode
         }}
      end)
    end)
    |> Map.new()
  end

  defp global_options(%TapPlan{}), do: []

  defp hooks(%CapabilityReport{} = report) do
    report.matched
    |> Enum.map(& &1.metadata[:layer_name])
    |> Enum.reject(&is_nil/1)
  end

  defp extractors(%CapabilityReport{} = report) do
    Enum.map(report.matched, &%{tap_id: &1.tap_id, surface_node_id: &1.surface_node_id})
  end
end
