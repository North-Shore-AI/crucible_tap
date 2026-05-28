defmodule CrucibleTap.CapabilityReport do
  @moduledoc """
  Internal plan-compiler capability report for a tap plan and model surface.

  Public negotiation goes through `Crucible.CapabilityReport.negotiate/3`.
  This struct stays in `crucible_tap` because it captures tap-plan matching
  details before they are projected into the provider-neutral report.
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

  @spec ok?(t()) :: boolean()
  def ok?(%__MODULE__{} = report), do: report.unsupported_required == []
end
