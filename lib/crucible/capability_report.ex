defmodule Crucible.CapabilityReport do
  @moduledoc """
  V4 provider-neutral capability negotiation report.
  """

  alias Crucible.{DegradedCapability, FailedCapability, UnsupportedCapability}

  @derive Jason.Encoder
  defstruct [
    :provider_kind,
    :model_id,
    :model_family,
    :backend,
    supported: [],
    unsupported: [],
    failed: [],
    degraded: [],
    resource_budget: nil,
    required_missing: [],
    optional_dropped: []
  ]

  @type capability :: atom()
  @type t :: %__MODULE__{}

  defmodule ResourceBudget do
    @moduledoc "V4 resource constraints advertised by a provider."
    @derive Jason.Encoder
    defstruct max_extra_forward_passes: 0,
              max_parallel_kv_caches: 1,
              supports_token_callback?: false,
              supports_auxiliary_forward?: false,
              supports_active_injection?: false,
              estimated_vram_multiplier: 1.0
  end

  def new(attrs \\ []) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    %__MODULE__{
      provider_kind: Map.get(attrs, :provider_kind),
      model_id: Map.get(attrs, :model_id),
      model_family: Map.get(attrs, :model_family),
      backend: Map.get(attrs, :backend),
      supported: Map.get(attrs, :supported, []),
      unsupported: Map.get(attrs, :unsupported, []),
      failed: Map.get(attrs, :failed, []),
      degraded: Map.get(attrs, :degraded, []),
      resource_budget:
        Map.get(attrs, :resource_budget) ||
          %ResourceBudget{
            supports_token_callback?: false,
            supports_auxiliary_forward?: false,
            supports_active_injection?: false
          },
      required_missing: Map.get(attrs, :required_missing, []),
      optional_dropped: Map.get(attrs, :optional_dropped, [])
    }
  end

  def negotiate(%CrucibleTap.TapPlan{} = tap_plan, %CrucibleTap.Surface{} = surface, opts \\ []) do
    case CrucibleTap.PlanCompiler.compile(tap_plan, surface) do
      {:ok, compiled} ->
        report =
          from_tap_report(compiled.report,
            provider_kind: Keyword.get(opts, :provider_kind),
            model_id: Keyword.get(opts, :model_id),
            backend: Keyword.get(opts, :backend),
            resource_budget: Keyword.get(opts, :resource_budget)
          )

        {:ok, compiled, report}

      {:error, tap_report} ->
        report =
          from_tap_report(tap_report,
            provider_kind: Keyword.get(opts, :provider_kind),
            model_id: Keyword.get(opts, :model_id),
            backend: Keyword.get(opts, :backend),
            resource_budget: Keyword.get(opts, :resource_budget)
          )

        {:error, {:tap_compile_failed, report}}
    end
  end

  def from_tap_report(%CrucibleTap.CapabilityReport{} = report, attrs \\ []) do
    attrs = normalize_attrs(attrs)

    unsupported =
      Enum.map(report.unsupported_optional, fn result ->
        %UnsupportedCapability{
          capability: result.tap_id,
          reason: normalize_reason(result.reason),
          required?: false,
          metadata: result.metadata
        }
      end)

    failed =
      Enum.map(report.unsupported_required, fn result ->
        %FailedCapability{
          capability: result.tap_id,
          reason: normalize_reason(result.reason),
          required?: true,
          metadata: result.metadata
        }
      end)

    %__MODULE__{
      provider_kind: Map.get(attrs, :provider_kind, report.adapter),
      model_id: Map.get(attrs, :model_id),
      model_family: Map.get(attrs, :model_family, report.model_family),
      backend: Map.get(attrs, :backend),
      supported: Enum.map(report.matched, & &1.tap_id),
      unsupported: unsupported,
      failed: failed,
      degraded: Enum.map(unsupported, &degraded_from_unsupported/1),
      resource_budget: Map.get(attrs, :resource_budget) || %ResourceBudget{},
      required_missing: Enum.map(failed, & &1.capability),
      optional_dropped: Enum.map(unsupported, & &1.capability)
    }
  end

  def supports?(%__MODULE__{} = report, capability), do: capability in report.supported

  def missing_required?(%__MODULE__{} = report), do: report.required_missing != []

  defp degraded_from_unsupported(%UnsupportedCapability{} = unsupported) do
    %DegradedCapability{
      capability: unsupported.capability,
      reason: unsupported.reason,
      required?: false,
      metadata: unsupported.metadata
    }
  end

  defp normalize_reason(:no_matching_surface_node), do: :no_surface_node
  defp normalize_reason(reason), do: reason

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end
end
