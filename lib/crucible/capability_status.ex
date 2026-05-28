defmodule Crucible.UnsupportedCapability do
  @moduledoc "Unsupported capability descriptor."
  @derive Jason.Encoder
  defstruct [:capability, :reason, required?: false, metadata: %{}]
end

defmodule Crucible.FailedCapability do
  @moduledoc "Failed capability descriptor."
  @derive Jason.Encoder
  defstruct [:capability, :reason, required?: true, metadata: %{}]
end

defmodule Crucible.DegradedCapability do
  @moduledoc "Degraded capability descriptor."
  @derive Jason.Encoder
  defstruct [:capability, :reason, required?: false, metadata: %{}]
end
