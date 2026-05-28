defmodule CrucibleTap do
  @moduledoc """
  Tap-plan and probe-contract library for model-internal observations.

  This package describes what to read from a model forward pass, how to bound
  capture, and how to negotiate those requests against adapter capabilities.

  It owns tap plans, model surfaces, and the provider-neutral
  `Crucible.CapabilityReport` contract.
  """

  @version Mix.Project.config()[:version]

  @doc "Returns the package version."
  def version, do: @version

  @doc "Builds a tap plan."
  defdelegate plan!(specs, attrs \\ []), to: CrucibleTap.TapPlan, as: :new!

  @doc "Builds a plan-level trajectory tap from multiple layer captures."
  defdelegate trajectory_tap(id, layers, opts \\ []), to: CrucibleTap.PlanBuilder
end
