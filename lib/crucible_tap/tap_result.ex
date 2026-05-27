defmodule CrucibleTap.TapResult do
  @moduledoc """
  Result metadata for one compiled or captured tap.
  """

  @derive Jason.Encoder
  defstruct tap_id: nil,
            status: :matched,
            surface_node_id: nil,
            signal_ref: nil,
            reason: nil,
            metadata: %{}

  @type status :: :matched | :captured | :unsupported | :skipped | :failed
  @type t :: %__MODULE__{}
end
