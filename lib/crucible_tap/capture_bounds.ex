defmodule CrucibleTap.CaptureBounds do
  @moduledoc """
  Bounded capture limits for tap requests.
  """

  @derive Jason.Encoder
  defstruct max_elements: 4096,
            max_bytes: 65_536,
            top_k: 5,
            raw_allowed?: false,
            sample_rate: 1.0,
            metadata: %{}

  @type t :: %__MODULE__{}

  def new(attrs \\ []) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    bounds =
      struct(__MODULE__, %{
        max_elements: Map.get(attrs, :max_elements, 4096),
        max_bytes: Map.get(attrs, :max_bytes, 65_536),
        top_k: Map.get(attrs, :top_k, 5),
        raw_allowed?: Map.get(attrs, :raw_allowed?, false),
        sample_rate: Map.get(attrs, :sample_rate, 1.0),
        metadata: Map.get(attrs, :metadata, %{})
      })

    if valid?(bounds), do: {:ok, bounds}, else: {:error, {:invalid_capture_bounds, bounds}}
  end

  def new!(attrs \\ []) do
    case new(attrs) do
      {:ok, bounds} -> bounds
      {:error, reason} -> raise ArgumentError, "invalid capture bounds: #{inspect(reason)}"
    end
  end

  defp valid?(%__MODULE__{} = bounds) do
    positive_integer?(bounds.max_elements) and positive_integer?(bounds.max_bytes) and
      non_negative_integer?(bounds.top_k) and is_boolean(bounds.raw_allowed?) and
      is_number(bounds.sample_rate) and bounds.sample_rate > 0 and bounds.sample_rate <= 1
  end

  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp non_negative_integer?(value), do: is_integer(value) and value >= 0

  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end
end
