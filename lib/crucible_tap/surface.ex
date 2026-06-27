defmodule CrucibleTap.Surface do
  @moduledoc """
  Adapter-declared observable model surface.
  """

  alias CrucibleSignal.{Capability, SafeTerms}
  alias CrucibleTap.{SurfaceNode, TapSelector}

  @derive Jason.Encoder
  defstruct adapter: nil, model_family: nil, nodes: [], metadata: %{}

  @type t :: %__MODULE__{}

  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = normalize_attrs(attrs)
    nodes = Enum.map(Map.get(attrs, :nodes, []), &normalize_node/1)

    {:ok,
     %__MODULE__{
       adapter: Map.get(attrs, :adapter),
       model_family: Map.get(attrs, :model_family),
       nodes: nodes,
       metadata: Map.get(attrs, :metadata, %{})
     }}
  end

  def new!(attrs) do
    {:ok, surface} = new(attrs)
    surface
  end

  def matching_nodes(%__MODULE__{} = surface, selector) do
    selector = normalize_selector(selector)
    selector = TapSelector.materialize(selector, surface.nodes)
    Enum.filter(surface.nodes, &TapSelector.matches?(selector, Map.from_struct(&1)))
  end

  def capabilities(%__MODULE__{} = surface) do
    Enum.map(surface.nodes, fn node ->
      Capability.new!(
        signal_type: node.signal_type,
        operations: node.operations,
        capture_modes: node.capture_modes,
        adapter: surface.adapter,
        model_family: surface.model_family,
        metadata:
          Map.merge(node.metadata, %{
            surface_node_id: node.id,
            layer_name: node.layer_name,
            activation_name: node.activation_name,
            component: node.component,
            axes: node.axes
          })
      )
    end)
  end

  defp normalize_node(%SurfaceNode{} = node), do: node
  defp normalize_node(attrs), do: SurfaceNode.new!(attrs)

  defp normalize_selector(%TapSelector{} = selector), do: selector
  defp normalize_selector(attrs), do: TapSelector.new!(attrs)

  defp normalize_attrs(attrs), do: SafeTerms.normalize_attrs(attrs)
end
