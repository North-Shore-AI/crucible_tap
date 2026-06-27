defmodule CrucibleTap.SurfaceNode do
  @moduledoc """
  Adapter-declared model surface node.
  """

  alias CrucibleSignal.{ActivationMetadata, CaptureMode, Operation, SafeTerms, SignalType}

  @derive Jason.Encoder
  defstruct id: nil,
            signal_type: nil,
            activation_name: nil,
            component: nil,
            axes: nil,
            layer_name: nil,
            layer_index: nil,
            token_index: nil,
            head_index: nil,
            operations: [:read],
            capture_modes: [:summary],
            metadata: %{}

  @type t :: %__MODULE__{}

  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    with {:ok, raw_signal_type} <- fetch_required(attrs, :signal_type),
         {:ok, signal_type} <- SignalType.normalize(raw_signal_type),
         {:ok, operations} <- normalize_many(Map.get(attrs, :operations, [:read]), Operation),
         {:ok, capture_modes} <-
           normalize_many(Map.get(attrs, :capture_modes, [:summary]), CaptureMode),
         {:ok, metadata} <- activation_metadata(attrs) do
      {:ok,
       struct(__MODULE__, %{
         id: Map.get(attrs, :id, Map.get(attrs, :layer_name)),
         signal_type: signal_type,
         activation_name: Map.get(metadata, :activation_name),
         component: Map.get(metadata, :component),
         axes: Map.get(metadata, :axes),
         layer_name: Map.get(attrs, :layer_name),
         layer_index: Map.get(attrs, :layer_index, Map.get(metadata, :layer_index)),
         token_index: Map.get(attrs, :token_index, Map.get(metadata, :token_index)),
         head_index: Map.get(attrs, :head_index, Map.get(metadata, :head_index)),
         operations: operations,
         capture_modes: capture_modes,
         metadata: metadata
       })}
    end
  end

  def new!(attrs) do
    case new(attrs) do
      {:ok, node} -> node
      {:error, reason} -> raise ArgumentError, "invalid surface node: #{inspect(reason)}"
    end
  end

  defp normalize_attrs(attrs), do: SafeTerms.normalize_attrs(attrs)

  defp fetch_required(attrs, field) do
    case Map.fetch(attrs, field) do
      {:ok, value} when value not in [nil, ""] -> {:ok, value}
      _ -> {:error, {:missing_required_fields, [field]}}
    end
  end

  defp normalize_many(values, module) do
    values
    |> List.wrap()
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case module.normalize(value) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp activation_metadata(attrs) do
    metadata =
      attrs
      |> Map.get(:metadata, %{})
      |> merge_metadata_fields(attrs)
      |> maybe_default_axes()

    ActivationMetadata.normalize(metadata)
  end

  defp merge_metadata_fields(metadata, attrs) do
    Enum.reduce(
      [
        :activation_name,
        :component,
        :axes,
        :layer_index,
        :head_index,
        :token_index,
        :capture_mode,
        :raw_ref
      ],
      metadata,
      fn field, acc ->
        case Map.fetch(attrs, field) do
          {:ok, nil} -> acc
          {:ok, value} -> Map.put_new(acc, field, value)
          :error -> acc
        end
      end
    )
  end

  defp maybe_default_axes(%{activation_name: name} = metadata) when is_binary(name) do
    Map.put_new(metadata, :axes, ActivationMetadata.default_axes(name))
  end

  defp maybe_default_axes(metadata), do: metadata
end
