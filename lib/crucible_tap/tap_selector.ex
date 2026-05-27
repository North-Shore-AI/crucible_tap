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

  def new!(attrs \\ []) do
    {:ok, selector} = new(attrs)
    selector
  end

  def matches?(%__MODULE__{} = selector, node) do
    matches_value?(selector.signal_type, Map.get(node, :signal_type)) and
      matches_value?(selector.layer, Map.get(node, :layer_index)) and
      matches_value?(selector.token, Map.get(node, :token_index)) and
      matches_value?(selector.head, Map.get(node, :head_index)) and
      matches_name?(selector.layer_name, Map.get(node, :layer_name))
  end

  defp matches_value?(nil, _value), do: true
  defp matches_value?(:any, _value), do: true
  defp matches_value?(values, value) when is_list(values), do: value in values
  defp matches_value?(value, value), do: true
  defp matches_value?(_expected, _value), do: false

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
