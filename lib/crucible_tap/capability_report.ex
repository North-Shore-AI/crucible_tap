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
end
