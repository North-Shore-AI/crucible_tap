defmodule CrucibleTap.PlanBuilder do
  @moduledoc """
  Helpers for building common tap-plan shapes.
  """

  alias CrucibleSignal.ActivationMetadata
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

  def activation_tap(id, activation_name, opts \\ []) when is_binary(activation_name) do
    metadata =
      ActivationMetadata.put_activation(Keyword.get(opts, :metadata, %{}), activation_name)

    signal_type =
      Keyword.get(opts, :signal_type, ActivationMetadata.default_signal_type(activation_name))

    capture_mode = Keyword.get(opts, :capture_mode, :summary)
    required? = Keyword.get(opts, :required?, true)
    kind = Keyword.get(opts, :kind, :read)

    spec =
      TapSpec.new!(
        id: id,
        signal_type: signal_type,
        layers: Keyword.get(opts, :layers, selector_layer(metadata)),
        tokens: Keyword.get(opts, :tokens, :all),
        heads: Keyword.get(opts, :heads, :all),
        capture_mode: capture_mode,
        bounds: Keyword.get(opts, :bounds, %{}),
        required?: required?,
        kind: kind,
        selector: Keyword.get(opts, :selector, %{}),
        metadata: metadata
      )

    TapPlan.new!([spec],
      plan_id: Keyword.get(opts, :plan_id, "#{id}:activation"),
      metadata: %{activation_name: activation_name}
    )
  end

  defp selector_layer(%{layer_index: nil}), do: :all
  defp selector_layer(%{layer_index: layer_index}), do: [layer_index]
  defp selector_layer(_metadata), do: :all
end
