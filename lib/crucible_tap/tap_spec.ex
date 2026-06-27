defmodule CrucibleTap.TapSpec do
  @moduledoc """
  One requested model-internal observation.
  """

  alias CrucibleSignal.{ActivationMetadata, SafeTerms, SignalSpec}
  alias CrucibleTap.{CaptureBounds, TapSelector}

  @derive Jason.Encoder
  defstruct id: nil,
            signal_spec: nil,
            selector: nil,
            bounds: nil,
            kind: :read,
            required?: true,
            metadata: %{}

  @type t :: %__MODULE__{}

  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    with {:ok, signal_spec} <- normalize_signal_spec(attrs),
         {:ok, selector} <- normalize_selector(Map.get(attrs, :selector, %{}), signal_spec),
         {:ok, kind} <- normalize_kind(Map.get(attrs, :kind, :read)),
         {:ok, bounds} <- CaptureBounds.new(Map.get(attrs, :bounds, %{})),
         {:ok, metadata} <- normalize_metadata(attrs, signal_spec) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id, signal_spec.id),
         signal_spec: signal_spec,
         selector: selector,
         bounds: bounds,
         kind: kind,
         required?: Map.get(attrs, :required?, signal_spec.required?),
         metadata: metadata
       }}
    end
  end

  def new!(attrs) do
    case new(attrs) do
      {:ok, spec} -> spec
      {:error, reason} -> raise ArgumentError, "invalid tap spec: #{inspect(reason)}"
    end
  end

  def active?(%__MODULE__{kind: kind}), do: kind in [:inject, :gate]
  def passive?(%__MODULE__{} = spec), do: not active?(spec)

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
      :required?,
      :metadata
    ])
    |> put_activation_metadata(attrs)
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
      |> Map.put_new(:activation_name, Map.get(signal_spec.metadata, :activation_name))
      |> Map.put_new(:component, Map.get(signal_spec.metadata, :component))

    TapSelector.new(selector_attrs)
  end

  defp selector_from_dimension(:all), do: :any
  defp selector_from_dimension(value), do: value

  defp normalize_kind(kind) when kind in [:read, :derive, :auxiliary, :inject, :gate],
    do: {:ok, kind}

  defp normalize_kind(kind), do: {:error, {:unknown_tap_kind, kind}}

  defp normalize_metadata(attrs, signal_spec) do
    attrs
    |> Map.get(:metadata, %{})
    |> Map.merge(signal_spec.metadata)
    |> ActivationMetadata.normalize()
  end

  defp put_activation_metadata(signal_attrs, attrs) do
    metadata =
      attrs
      |> Map.get(:metadata, %{})
      |> merge_metadata_field(attrs, :activation_name)
      |> merge_metadata_field(attrs, :component)
      |> merge_metadata_field(attrs, :axes)
      |> maybe_default_axes()

    Map.put(signal_attrs, :metadata, metadata)
  end

  defp merge_metadata_field(metadata, attrs, field) do
    case Map.fetch(attrs, field) do
      {:ok, nil} -> metadata
      {:ok, value} -> Map.put_new(metadata, field, value)
      :error -> metadata
    end
  end

  defp maybe_default_axes(%{activation_name: activation_name} = metadata)
       when is_binary(activation_name),
       do: Map.put_new(metadata, :axes, ActivationMetadata.default_axes(activation_name))

  defp maybe_default_axes(metadata), do: metadata

  defp normalize_attrs(attrs), do: SafeTerms.normalize_attrs(attrs)
end
