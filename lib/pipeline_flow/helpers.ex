defmodule PipelineFlow.Helpers do
  @moduledoc """
  Helpers module for PipelineFlow structs. All these functions are also imported when you use the PiplineFlow macro.
  """
  require Logger

  defguard is_pipeline(pipeline)
           when is_struct(pipeline) and is_map_key(pipeline, :__pipeline__)

  defguard is_step(step) when is_atom(step) and is_nil(step) == false

  defguard is_pipeline_module(pipeline) when is_atom(pipeline) and is_nil(pipeline) == false

  @doc """
  Parses the result of a PiplineFlow struct. Returns `{:ok, any()}` when pipeline.
  Depending on the implementation of the PipelineFlow struct, the result will be that struct itself,
  the value set in the struct or the value that is returned from the `value(PipelineFlow.t())` function
  that is implemented on the module.

  didn't encountered an error. Returns `{:error, atom(), any()}` (where `atom()` is the step where the error eccoured)

  ## Examples

      iex> PipelineFlow.Helpers.result(%TestPipeline{})
      {:ok, %TestPipeline{}}

      iex> PipelineFlow.Helpers.result(%TestPipeline{value: "some-value"})
      {:ok, "some-value"}

      iex> PipelineFlow.Helpers.result(%TestPipeline2{some_attribute: "value-returned-from-value-function"})
      {:ok, "value-returned-from-value-function"}

      iex> PipelineFlow.Helpers.result(%TestPipeline{error: :faulty, last_step: :get_data})
      {:error, :get_data, :faulty}

  """
  @spec result(PipelineFlow.pipeline()) ::
          {:ok, PipelineFlow.pipeline()} | {:error, :atom, term()}
  def result(%mod{} = pipeline) when is_pipeline(pipeline) do
    if error?(pipeline) do
      {:error, pipeline.last_step, pipeline.error}
    else
      cond do
        Kernel.function_exported?(mod, :value, 1) ->
          {:ok, mod.value(pipeline)}

        pipeline.value != :not_set ->
          {:ok, pipeline.value}

        true ->
          {:ok, pipeline}
      end
    end
  end

  @doc """
  Tests if given step is defined on PipelineFlow struct

  ## Examples

      iex> PipelineFlow.Helpers.step_defined?(TestPipeline, :get_products)
      false

      iex> PipelineFlow.Helpers.step_defined?(TestPipeline, :result_tuple_on_argument)
      true

  """
  @spec step_defined?(PipelineFlow.pipeline_mod(), PipelineFlow.step()) :: boolean()
  def step_defined?(pipeline_mod, step) when is_pipeline_module(pipeline_mod) and is_step(step),
    do: Enum.member?(pipeline_mod.steps(), step)

  @doc """
  Tests if the given steps on the PiplineFlow struct are completed

  ## Examples

      iex> PipelineFlow.Helpers.completed?(%TestPipeline{}, [:result_tuple_on_argument])
      false

      iex> PipelineFlow.Helpers.completed?(%TestPipeline{}, :result_tuple_on_argument)
      false

      iex> PipelineFlow.Helpers.completed?(%TestPipeline{completed_steps: [:result_tuple_on_argument]}, [:result_tuple_on_argument])
      true

      iex> PipelineFlow.Helpers.completed?(%TestPipeline{completed_steps: [:result_tuple_on_argument]}, :result_tuple_on_argument)
      true

  """
  @spec completed?(PipelineFlow.pipeline(), PipelineFlow.step() | list(PipelineFlow.step())) ::
          boolean()
  def completed?(pipeline, step) when is_pipeline(pipeline) and is_step(step),
    do: step in pipeline.completed_steps

  def completed?(pipeline, steps) when is_pipeline(pipeline) and is_list(steps),
    do: Enum.all?(steps, &completed?(pipeline, &1))

  @doc """
  Checks if PiplineFlow was executed correctly

  ## Examples

      iex> PipelineFlow.Helpers.ok?(%TestPipeline{})
      true

      iex> PipelineFlow.Helpers.ok?(%TestPipeline{error: :faulty})
      false

  """
  @spec ok?(PipelineFlow.pipeline()) :: boolean()
  def ok?(%{error: nil} = pipeline) when is_pipeline(pipeline), do: true
  def ok?(pipeline) when is_pipeline(pipeline), do: false

  @doc """
  Checks if PiplineFlow was executed correctly

  ## Examples

      iex> PipelineFlow.Helpers.error?(%TestPipeline{error: :faulty})
      true

      iex> PipelineFlow.Helpers.error?(%TestPipeline{})
      false

  """
  @spec error?(PipelineFlow.pipeline()) :: boolean()
  def error?(pipeline) when is_pipeline(pipeline), do: not ok?(pipeline)

  @doc """
  Checks if the PipelineFlow has halted execution

  ## Examples

      iex> PipelineFlow.Helpers.halted?(%TestPipeline{})
      false

      iex> PipelineFlow.Helpers.halted?(%TestPipeline{} |> PipelineFlow.Helpers.halt())
      true

  """
  @spec halted?(PipelineFlow.pipeline()) :: boolean()
  def halted?(pipeline) when is_pipeline(pipeline), do: pipeline.halted == true

  @doc """
  Sets attribute on PipelineFlow module struct

  ## Examples

      iex> %TestPipeline{}
      %TestPipeline{some_attribute: nil}

      iex> PipelineFlow.Helpers.set_attribute(%TestPipeline{}, :some_attribute, "foobar")
      %TestPipeline{some_attribute: "foobar"}

      iex> PipelineFlow.Helpers.set_attribute(%TestPipeline{}, :non_existing_field, "foobar")
      %TestPipeline{}

      iex> PipelineFlow.Helpers.set_attribute(%TestPipeline{}, %{some_attribute: "foobar"})
      %TestPipeline{some_attribute: "foobar"}

      iex> PipelineFlow.Helpers.set_attribute(%TestPipeline{}, %{non_existing_field: "foobar"})
      %TestPipeline{}

  """
  @spec set_attribute(PipelineFlow.pipeline(), map() | nil) :: PipelineFlow.pipeline()
  def set_attribute(pipeline, nil) when is_pipeline(pipeline), do: pipeline

  def set_attribute(%mod{} = pipeline, attrs) when is_pipeline(pipeline) and is_map(attrs) do
    attrs = Map.filter(attrs, fn {k, _v} -> k in mod.fields() end)

    Map.merge(pipeline, attrs)
  end

  @spec set_attribute(PipelineFlow.pipeline(), atom(), any()) :: PipelineFlow.pipeline()
  def set_attribute(pipeline, key, value) when is_pipeline(pipeline) and is_atom(key),
    do: Map.replace(pipeline, key, value)

  @doc """
  Transforms PipelineFlow in map of attributes

  iex> PipelineFlow.Helpers.get_attributes(%TestPipeline{some_attribute: "foobar", list_attribute: ["1", "2", "3"]})
  %{some_attribute: "foobar", list_attribute: ["1", "2", "3"]}

  """
  @spec get_attributes(PipelineFlow.pipeline()) :: map()
  def get_attributes(%mod{} = pipeline), do: Map.take(pipeline, mod.fields())

  @doc """
  Sets last performed step of PipelineFlow struct

  ## Examples

      iex> PipelineFlow.Helpers.set_last_step(%TestPipeline{}, :result_tuple_pipeline_return_value)
      %TestPipeline{last_step: :result_tuple_pipeline_return_value}

      iex> PipelineFlow.Helpers.set_last_step(%TestPipeline{}, :step_does_not_exist)
      %TestPipeline{}

  """
  def set_last_step(%mod{} = pipeline, step) when is_pipeline(pipeline) and is_atom(step) do
    if step in mod.steps() do
      Map.replace(pipeline, :last_step, step)
    else
      pipeline
    end
  end

  @doc """
  Sets last encountered error of PipelineFlow struct
  """
  @spec set_error(PipelineFlow.pipeline(), nil | any()) :: PipelineFlow.pipeline()
  def set_error(pipeline, nil) when is_pipeline(pipeline), do: pipeline

  def set_error(pipeline, error) when is_pipeline(pipeline) and is_nil(error) == false,
    do: Map.replace(pipeline, :error, error)

  @doc """
  Adds a warning

  ## Examples

      iex> pipeline = %TestPipeline{}
      ...> pipeline.warnings
      []
      iex> pipeline = PipelineFlow.Helpers.add_warning(pipeline, :first_step, "A warning")
      ...> pipeline.warnings
      [{:first_step, "A warning"}]

  """
  @spec add_warning(PipelineFlow.pipeline(), atom(), any()) :: PipelineFlow.pipeline()
  def add_warning(pipeline, step, warning) when is_pipeline(pipeline) and is_atom(step),
    do: Map.replace(pipeline, :warnings, [{step, warning} | pipeline.warnings])

  @doc """
  Halts execution of flow

  ## Examples

      iex> pipeline = %TestPipeline{}
      %TestPipeline{}
      iex> pipeline = PipelineFlow.Helpers.halt(pipeline)
      ...> PipelineFlow.Helpers.halted?(pipeline)
      true

  """
  @spec halt(PipelineFlow.pipeline()) :: PipelineFlow.pipeline()
  def halt(pipeline) when is_pipeline(pipeline),
    do: Map.replace(pipeline, :halted, true)

  @doc """
  Logs the state of a given PipelineFlow struct
  """
  @spec log(PipelineFlow.pipeline()) :: PipelineFlow.pipeline()
  def log(pipeline) when is_pipeline(pipeline) do
    Enum.each(pipeline.warnings, fn {step, warning} ->
      if is_nil(step) do
        Logger.warning("Warning in pipeline: #{inspect(warning)}")
      else
        Logger.warning("Warning in pipeline at step #{step}: #{inspect(warning)}")
      end
    end)

    if error?(pipeline) do
      Logger.error("Error in pipeline at step ##{pipeline.last_step}: #{inspect(pipeline.error)}")
    end

    pipeline
  end

  @doc """
  Adds completed step to list

  ## Examples

      iex> pipeline = %TestPipeline{}
      ...> pipeline.completed_steps
      []
      iex> pipeline = PipelineFlow.Helpers.set_completed_step(pipeline, :result_tuple_on_argument)
      ...> pipeline.completed_steps
      [:result_tuple_on_argument]
      iex> pipeline = PipelineFlow.Helpers.set_completed_step(pipeline, :non_existing_step)
      ...> pipeline.completed_steps
      [:result_tuple_on_argument]

  """
  @spec set_completed_step(PipelineFlow.pipeline(), atom()) :: PipelineFlow.pipeline()
  def set_completed_step(%mod{} = pipeline, step) when is_pipeline(pipeline) and is_atom(step) do
    if step in mod.steps() do
      Map.replace(pipeline, :completed_steps, [step | pipeline.completed_steps])
    else
      pipeline
    end
  end

  @spec set_result(PipelineFlow.pipeline(), atom(), any()) :: any()
  def set_result(pipeline, step, result) when is_pipeline(pipeline) and is_atom(step) do
    case result do
      :ok ->
        set_result_from_status(pipeline, step, nil, :ok)

      :error ->
        set_result_from_status(pipeline, step, nil, :error)

      {result, pipeline_return}
      when is_pipeline(pipeline_return) and result in [:ok, :error] ->
        set_result_from_status(pipeline_return, step, nil, result)

      {result, :halt, pipeline_return}
      when is_pipeline(pipeline_return) and result in [:ok, :error] ->
        pipeline_return
        |> set_result_from_status(step, nil, result)
        |> halt()

      {result, value} when result in [:ok, :error] ->
        set_result_from_status(pipeline, step, value, result)

      {result, :halt, value} when result in [:ok, :error] ->
        pipeline
        |> set_result_from_status(step, value, result)
        |> halt()

      pipeline_return when is_struct(pipeline_return) ->
        result = status(pipeline_return)
        set_result_from_status(pipeline_return, step, nil, result)

      %{} = attrs ->
        set_result_from_status(pipeline, step, attrs, :ok)

      value ->
        value
    end
  end

  @doc """
  Sets a parent PipelineFlow to the child PipelineFlow. Can be used when
  you are using a string of flows that are dependent of each other.

  ## Examples

      iex> pipeline = %TestPipeline{}
      ...> pipeline.parent
      nil
      iex> other_pipeline = %TestPipeline2{}
      ...>
      ...> PipelineFlow.Helpers.set_parent(pipeline, other_pipeline)
      %TestPipeline{parent: %TestPipeline2{}}

  """
  @spec set_parent(PipelineFlow.pipeline(), nil | PipelineFlow.pipeline()) ::
          PipelineFlow.pipeline()
  def set_parent(pipeline, parent)
      when is_pipeline(pipeline) and (is_nil(parent) or is_pipeline(parent)),
      do: Map.put(pipeline, :parent, parent)

  @doc """
  Returns the current status of a pipeline. Can be either be :ok, :error or :halt

  ## Examples

      iex> PipelineFlow.Helpers.status(%TestPipeline{})
      :ok
      iex> PipelineFlow.Helpers.status(%TestPipeline{error: :faulty})
      :error
      iex> PipelineFlow.Helpers.status(%TestPipeline{halted: true})
      :halt
      iex> PipelineFlow.Helpers.status(%TestPipeline{error: :faulty, halted: true})
      :halt

  """
  @spec status(PipelineFlow.pipeline()) :: atom()
  def status(pipeline) when is_pipeline(pipeline) do
    cond do
      pipeline.halted -> :halt
      pipeline.error -> :error
      true -> :ok
    end
  end

  @spec exec(PipelineFlow.pipeline()) :: {:ok, any()} | {:error, atom(), any()}
  def exec(%mod{} = pipeline) when is_pipeline(pipeline) do
    if allows_exec?(mod) do
      mod.steps_order()
      |> Enum.reduce(pipeline, fn step, pipeline ->
        apply(mod, step, [pipeline])
      end)
      |> result()
    else
      raise PipelineFlow.Error, "Not all steps are defined with an arity of one"
    end
  end

  @spec allows_exec?(atom()) :: boolean()
  def allows_exec?(pipeline_mod) when is_pipeline_module(pipeline_mod) do
    Enum.all?(pipeline_mod.steps(), fn step ->
      Kernel.function_exported?(pipeline_mod, step, 1)
    end)
  end

  defp set_result_from_status(pipeline, step, return_value, :ok) do
    pipeline
    |> set_last_step(step)
    |> set_completed_step(step)
    |> set_attribute(return_value)
  end

  defp set_result_from_status(pipeline, step, return_value, :halt) do
    pipeline
    |> set_last_step(step)
    |> set_completed_step(step)
    |> set_attribute(return_value)
    |> halt()
  end

  defp set_result_from_status(pipeline, step, return_value, :error) do
    pipeline
    |> set_last_step(step)
    |> set_error(return_value)
  end
end
