surface =
  CrucibleTap.Surface.new!(
    adapter: :fixture,
    model_family: :configured_surface,
    nodes: [
      [id: "h4", signal_type: :middle_residuals, layer_index: 4, layer_name: "block.4"],
      [id: "final", signal_type: :final_logits, layer_name: "lm_head"]
    ]
  )

plan = CrucibleTap.trajectory_tap("live-route", [4], required?: false)

case CrucibleTap.PlanCompiler.compile(plan, surface) do
  {:ok, compiled} ->
    IO.puts(Jason.encode!(%{
      ok: true,
      example: "compile_plan_live",
      hooks: compiled.hooks,
      layer_descriptors: Map.keys(compiled.layer_descriptors)
    }))

  {:error, report} ->
    IO.puts(Jason.encode!(%{
      ok: true,
      skipped: true,
      example: "compile_plan_live",
      reason: inspect(report.unsupported_required)
    }))
end
