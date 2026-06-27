defmodule CrucibleTap.TapSelector do
  @moduledoc """
  Selector constraints for model surface nodes.
  """

  @derive Jason.Encoder
  defstruct signal_type: nil,
            layer: :any,
            token: :any,
            head: :any,
            layer_name: :any,
            metadata: %{}

  @type t :: %__MODULE__{}
  @type layer_selector ::
          :any
          | :all
          | :final
          | :first
          | :middle
          | :last
          | {:fraction, number()}
          | {:last_n, pos_integer()}
          | {:indices, [integer()]}
          | {:named, String.t()}
          | integer()
          | [term()]
  @type resolved_layer_selector :: :any | :final | integer() | [integer()] | {:named, String.t()}

  @spec new(keyword() | map()) :: {:ok, t()}
  def new(attrs \\ []) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)

    {:ok,
     struct(__MODULE__, %{
       signal_type: Map.get(attrs, :signal_type),
       layer: Map.get(attrs, :layer, :any),
       token: Map.get(attrs, :token, :any),
       head: Map.get(attrs, :head, :any),
       layer_name: Map.get(attrs, :layer_name, :any),
       metadata: Map.get(attrs, :metadata, %{})
     })}
  end

  @spec new!(keyword() | map()) :: t()
  def new!(attrs \\ []) do
    {:ok, selector} = new(attrs)
    selector
  end

  @spec matches?(t(), map()) :: boolean()
  def matches?(%__MODULE__{} = selector, node) do
    matches_value?(selector.signal_type, Map.get(node, :signal_type)) and
      matches_value?(selector.layer, Map.get(node, :layer_index)) and
      matches_value?(selector.token, Map.get(node, :token_index)) and
      matches_value?(selector.head, Map.get(node, :head_index)) and
      matches_name?(selector.layer_name, Map.get(node, :layer_name))
  end

  @doc """
  Materializes portable layer selectors against a concrete surface.

  Named layer selectors are converted into `layer_name` matches instead of
  numeric layer indexes because providers expose named graph nodes differently.
  """
  @spec materialize(t(), [map()]) :: t()
  def materialize(%__MODULE__{} = selector, nodes) when is_list(nodes) do
    block_count = block_count(nodes)

    case selector.layer do
      {:named, name} ->
        %{selector | layer: :any, layer_name: name}

      layer ->
        %{selector | layer: resolve_layers(layer, block_count)}
    end
  end

  @doc "Resolves portable layer selectors into concrete numeric indexes."
  @spec resolve_layers(layer_selector(), non_neg_integer()) :: resolved_layer_selector()
  def resolve_layers(:any, _block_count), do: :any
  def resolve_layers(nil, _block_count), do: :any
  def resolve_layers(:all, _block_count), do: :any
  def resolve_layers(:final, _block_count), do: :final
  def resolve_layers(:first, block_count), do: if(block_count > 0, do: [0], else: [])

  def resolve_layers(:middle, block_count),
    do: if(block_count > 0, do: [div(block_count, 2)], else: [])

  def resolve_layers(:last, block_count), do: if(block_count > 0, do: [block_count - 1], else: [])

  def resolve_layers({:fraction, fraction}, block_count)
      when is_number(fraction) and block_count > 0 do
    index =
      fraction
      |> Kernel.*(block_count)
      |> round()
      |> min(block_count - 1)
      |> max(0)

    [index]
  end

  def resolve_layers({:last_n, count}, block_count)
      when is_integer(count) and count > 0 and block_count > 0 do
    start = max(block_count - count, 0)
    Enum.to_list(start..(block_count - 1))
  end

  def resolve_layers({:indices, indices}, _block_count) when is_list(indices), do: indices

  def resolve_layers(layers, block_count) when is_list(layers) do
    Enum.flat_map(layers, &List.wrap(resolve_layers(&1, block_count)))
  end

  def resolve_layers(layer, _block_count), do: layer

  @spec parse_keyword(atom() | String.t() | term()) ::
          {:ok, layer_selector()}
          | {:error,
             {:unknown_selector_keyword, term()}
             | {:invalid_fraction_selector, String.t()}
             | {:invalid_last_n_selector, String.t()}}
  def parse_keyword(value) when is_atom(value), do: {:ok, value}

  def parse_keyword(value) when is_binary(value) do
    case String.trim(value) do
      "first" -> {:ok, :first}
      "middle" -> {:ok, :middle}
      "last" -> {:ok, :last}
      "all" -> {:ok, :all}
      "final" -> {:ok, :final}
      "fraction:" <> rest -> parse_fraction(rest)
      "last_n:" <> rest -> parse_last_n(rest)
      "named:" <> rest -> {:ok, {:named, rest}}
      other -> {:error, {:unknown_selector_keyword, other}}
    end
  end

  def parse_keyword(value), do: {:error, {:unknown_selector_keyword, value}}

  defp matches_value?(nil, _value), do: true
  defp matches_value?(:any, _value), do: true
  defp matches_value?(:final, :final), do: true
  defp matches_value?(values, value) when is_list(values), do: value in values
  defp matches_value?(value, value), do: true
  defp matches_value?(_expected, _value), do: false

  defp block_count(nodes) do
    nodes
    |> Enum.map(fn
      %{layer_index: index} -> index
      _node -> nil
    end)
    |> Enum.filter(&is_integer/1)
    |> case do
      [] -> 0
      indices -> Enum.max(indices) + 1
    end
  end

  defp parse_fraction(value) do
    case Float.parse(value) do
      {fraction, ""} -> {:ok, {:fraction, fraction}}
      _other -> {:error, {:invalid_fraction_selector, value}}
    end
  end

  defp parse_last_n(value) do
    case Integer.parse(value) do
      {count, ""} when count > 0 -> {:ok, {:last_n, count}}
      _other -> {:error, {:invalid_last_n_selector, value}}
    end
  end

  defp matches_name?(nil, _name), do: true
  defp matches_name?(:any, _name), do: true
  defp matches_name?(%Regex{} = regex, name) when is_binary(name), do: Regex.match?(regex, name)
  defp matches_name?(name, name) when is_binary(name), do: true

  defp matches_name?(pattern, name) when is_binary(pattern) and is_binary(name) do
    pattern
    |> Regex.escape()
    |> String.replace("\\*", ".*")
    |> then(&Regex.compile!("^#{&1}$"))
    |> Regex.match?(name)
  end

  defp matches_name?(_pattern, _name), do: false

  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      {key, value} -> {key, value}
    end)
  end
end
