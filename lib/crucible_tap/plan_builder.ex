defmodule CrucibleTap.PlanBuilder do
  @moduledoc """
  Helpers for building common tap-plan shapes.
  """

  alias CrucibleTap.{TapPlan, TapSpec}

  def trajectory_tap(id, layers, opts \\ []) when is_list(layers) do
    capture_mode =
      if Keyword.get(opts, :drift?, true) do
        Keyword.get(opts, :capture_mode, :compressed_vector)
      else
        Keyword.get(opts, :capture_mode, :summary)
      end

    required? = Keyword.get(opts, :required?, true)

    specs =
      Enum.map(layers, fn layer ->
        TapSpec.new!(
          id: "#{id}:layer:#{layer}",
          signal_type: :middle_residuals,
          layers: [layer],
          capture_mode: capture_mode,
          required?: required?,
          kind: :read,
          metadata: %{trajectory_id: id}
        )
      end)

    TapPlan.new!(specs, plan_id: "#{id}:trajectory", metadata: %{trajectory_id: id})
  end
end
