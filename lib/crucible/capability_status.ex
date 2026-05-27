defmodule Crucible.UnsupportedCapability do
  @moduledoc "V4 unsupported capability descriptor."
  @derive Jason.Encoder
  defstruct [:capability, :reason, required?: false, metadata: %{}]
end

defmodule Crucible.FailedCapability do
  @moduledoc "V4 failed capability descriptor."
  @derive Jason.Encoder
  defstruct [:capability, :reason, required?: true, metadata: %{}]
end

defmodule Crucible.DegradedCapability do
  @moduledoc "V4 degraded capability descriptor."
  @derive Jason.Encoder
  defstruct [:capability, :reason, required?: false, metadata: %{}]
end
