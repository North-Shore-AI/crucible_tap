defmodule CrucibleTap.TapPlan do
  @moduledoc """
  Ordered set of tap specs for a forward pass.
  """

  alias CrucibleTap.TapSpec

  @derive Jason.Encoder
  defstruct plan_id: nil, specs: [], metadata: %{}

  @type t :: %__MODULE__{}

  def new(specs, attrs \\ []) when is_list(specs) do
    specs = Enum.map(specs, &normalize_spec/1)

    {:ok,
     %__MODULE__{
       plan_id: Keyword.get(attrs, :plan_id, "tap-plan:#{System.unique_integer([:positive])}"),
       specs: specs,
       metadata: Keyword.get(attrs, :metadata, %{})
     }}
  end

  def new!(specs, attrs \\ []) do
    {:ok, plan} = new(specs, attrs)
    plan
  end

  defp normalize_spec(%TapSpec{} = spec), do: spec
  defp normalize_spec(attrs), do: TapSpec.new!(attrs)
end
