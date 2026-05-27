surface =
  CrucibleTap.Surface.new!(
    adapter: :fixture,
    model_family: :dense_fixture,
    nodes: [
      [id: "h4", signal_type: :middle_residuals, layer_index: 4, layer_name: "block.4"],
      [id: "h8", signal_type: :middle_residuals, layer_index: 8, layer_name: "block.8"],
      [id: "logits", signal_type: :final_logits, layer_name: "lm_head"]
    ]
  )

trajectory = CrucibleTap.trajectory_tap("route", [4, 8])

plan =
  CrucibleTap.TapPlan.new!(
    trajectory.specs ++ [[id: "final", signal_type: :final_logits]],
    plan_id: "route-default"
  )

{:ok, result} = CrucibleTap.CapabilityReport.negotiate(plan, surface)

IO.puts(Jason.encode!(%{
  ok: true,
  example: "build_plan_mock",
  satisfied: result.satisfied,
  dropped_optional: result.dropped_optional
}))
