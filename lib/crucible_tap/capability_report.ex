defmodule CrucibleTap.CapabilityReport do
  @moduledoc """
  Capability negotiation result for a tap plan and model surface.
  """

  @derive Jason.Encoder
  defstruct adapter: nil,
            model_family: nil,
            matched: [],
            unsupported_required: [],
            unsupported_optional: [],
            capabilities: [],
            metadata: %{}

  @type t :: %__MODULE__{}

  def ok?(%__MODULE__{} = report), do: report.unsupported_required == []

  def negotiate(tap_plan, surface) do
    case CrucibleTap.PlanCompiler.compile(tap_plan, surface) do
      {:ok, compiled} ->
        {:ok,
         %{
           plan: compiled,
           satisfied: Enum.map(compiled.report.matched, & &1.tap_id),
           dropped_optional: dropped_optional(compiled.report)
         }}

      {:error, %__MODULE__{} = report} ->
        {:error,
         %{
           unsupported_required: unsupported_required(report),
           dropped_optional: dropped_optional(report)
         }}
    end
  end

  defp unsupported_required(%__MODULE__{} = report) do
    Enum.map(report.unsupported_required, &{&1.tap_id, normalize_reason(&1.reason)})
  end

  defp dropped_optional(%__MODULE__{} = report) do
    Enum.map(report.unsupported_optional, &{&1.tap_id, normalize_reason(&1.reason)})
  end

  defp normalize_reason(:no_matching_surface_node), do: :no_surface_node
  defp normalize_reason(reason), do: reason
end
