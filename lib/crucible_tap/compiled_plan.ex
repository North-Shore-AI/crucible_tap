defmodule CrucibleTap.CompiledPlan do
  @moduledoc """
  Adapter-neutral compiled tap plan.
  """

  @derive Jason.Encoder
  defstruct plan_id: nil,
            matched: [],
            layer_descriptors: %{},
            global_layer_options: [],
            hooks: [],
            extractors: [],
            report: nil,
            metadata: %{}

  @type t :: %__MODULE__{}
end
