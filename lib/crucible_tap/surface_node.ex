defmodule CrucibleTap.SurfaceNode do
  @moduledoc """
  Adapter-declared model surface node.
  """

  alias CrucibleSignal.{CaptureMode, Operation, SignalType}

  @derive Jason.Encoder
  defstruct id: nil,
            signal_type: nil,
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
           normalize_many(Map.get(attrs, :capture_modes, [:summary]), CaptureMode) do
      {:ok,
       struct(__MODULE__, %{
         id: Map.get(attrs, :id, Map.get(attrs, :layer_name)),
         signal_type: signal_type,
         layer_name: Map.get(attrs, :layer_name),
         layer_index: Map.get(attrs, :layer_index),
         token_index: Map.get(attrs, :token_index),
         head_index: Map.get(attrs, :head_index),
         operations: operations,
         capture_modes: capture_modes,
         metadata: Map.get(attrs, :metadata, %{})
       })}
    end
  end

  def new!(attrs) do
    case new(attrs) do
      {:ok, node} -> node
      {:error, reason} -> raise ArgumentError, "invalid surface node: #{inspect(reason)}"
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end

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
end
