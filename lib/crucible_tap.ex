defmodule CrucibleTap do
  @moduledoc """
  Tap-plan and probe-contract library for model-internal observations.

  This package describes what to read from a model forward pass, how to bound
  capture, and how to negotiate those requests against adapter capabilities.
  """

  @version Mix.Project.config()[:version]

  @doc "Returns the package version."
  def version, do: @version

  @doc "Builds a tap plan."
  defdelegate plan!(specs, attrs \\ []), to: CrucibleTap.TapPlan, as: :new!
end
