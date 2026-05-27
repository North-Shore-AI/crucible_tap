defmodule CrucibleTap.TapSpec do
  @moduledoc """
  One requested model-internal observation.
  """

  alias CrucibleSignal.SignalSpec
  alias CrucibleTap.{CaptureBounds, TapSelector}

  @derive Jason.Encoder
  defstruct id: nil,
            signal_spec: nil,
            selector: nil,
            bounds: nil,
            required?: true,
            metadata: %{}

  @type t :: %__MODULE__{}

  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    with {:ok, signal_spec} <- normalize_signal_spec(attrs),
         {:ok, selector} <- normalize_selector(Map.get(attrs, :selector, %{}), signal_spec),
         {:ok, bounds} <- CaptureBounds.new(Map.get(attrs, :bounds, %{})) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id, signal_spec.id),
         signal_spec: signal_spec,
         selector: selector,
         bounds: bounds,
         required?: Map.get(attrs, :required?, signal_spec.required?),
         metadata: Map.get(attrs, :metadata, %{})
       }}
    end
  end

  def new!(attrs) do
    case new(attrs) do
      {:ok, spec} -> spec
      {:error, reason} -> raise ArgumentError, "invalid tap spec: #{inspect(reason)}"
    end
  end

  defp normalize_signal_spec(%{signal_spec: %SignalSpec{} = spec}), do: {:ok, spec}

  defp normalize_signal_spec(attrs) do
    attrs
    |> Map.take([
      :id,
      :signal_type,
      :layers,
      :tokens,
      :heads,
      :operations,
      :capture_mode,
      :required?
    ])
    |> Map.put_new(:signal_type, Map.get(attrs, :signal_type))
    |> SignalSpec.new()
  end

  defp normalize_selector(%TapSelector{} = selector, _signal_spec), do: {:ok, selector}

  defp normalize_selector(selector_attrs, signal_spec) do
    selector_attrs =
      selector_attrs
      |> normalize_attrs()
      |> Map.put_new(:signal_type, signal_spec.signal_type)
      |> Map.put_new(:layer, selector_from_dimension(signal_spec.layers))
      |> Map.put_new(:token, selector_from_dimension(signal_spec.tokens))
      |> Map.put_new(:head, selector_from_dimension(signal_spec.heads))

    TapSelector.new(selector_attrs)
  end

  defp selector_from_dimension(:all), do: :any
  defp selector_from_dimension(value), do: value

  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end
end
