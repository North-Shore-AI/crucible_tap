defmodule CrucibleTap.PlanCompiler do
  @moduledoc """
  Negotiates a tap plan against an adapter-declared surface.
  """

  alias CrucibleTap.{
    CapabilityReport,
    CompiledPlan,
    Surface,
    TapPlan,
    TapResult
  }

  def compile(%TapPlan{} = plan, %Surface{} = surface) do
    {matched, unsupported_required, unsupported_optional} =
      Enum.reduce(plan.specs, {[], [], []}, fn spec, {matched, required, optional} ->
        nodes = Surface.matching_nodes(surface, spec.selector)

        if nodes == [] do
          result = %TapResult{
            tap_id: spec.id,
            status: :unsupported,
            reason: :no_matching_surface_node
          }

          if spec.required? do
            {matched, [result | required], optional}
          else
            {matched, required, [result | optional]}
          end
        else
          results =
            Enum.map(nodes, fn node ->
              %TapResult{
                tap_id: spec.id,
                status: :matched,
                surface_node_id: node.id,
                metadata: %{layer_name: node.layer_name}
              }
            end)

          {results ++ matched, required, optional}
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
      {:ok, %CompiledPlan{plan_id: plan.plan_id, matched: report.matched, report: report}}
    else
      {:error, report}
    end
  end
end
