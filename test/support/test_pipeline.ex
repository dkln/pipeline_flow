defmodule TestPipeline do
  use PipelineFlow

  attrs(list_attribute: [], some_attribute: nil)

  step result_tuple_on_argument(pipeline) do
    {:ok, %{list_attribute: ["Apple", "Pear", "Pineapple"]}}
  end

  step result_tuple_on_argument_two_arguments(pipeline, value) do
    if is_binary(value) do
      {:ok, %{list_attribute: [value | pipeline.list_attribute]}}
    else
      {:error, :invalid_value}
    end
  end

  step result_tuple_pipeline_return_value(pipeline) do
    pipeline = set_attribute(pipeline, :list_attribute, ["Apple"])

    if pipeline.some_attribute == :trigger_error do
      {:error, set_error(pipeline, :test_error)}
    else
      {:ok, pipeline}
    end
  end

  step plain_return_value(pipeline) do
    :plain_value
  end

  step pipeline_return_value(pipeline) do
    pipeline
    |> set_attribute(:some_attribute, "Test value")
    |> set_attribute(:list_attribute, ["Apple"])
  end

  step with_guard(pipeline, value) when is_binary(value) and value != "" do
    %{some_attribute: value}
  end

  step with_guard(pipeline, value) when is_number(value) do
    %{some_attribute: value * 100}
  end

  step step_with_halt(pipeline, value) do
    if value == :trigger_halt do
      halt(pipeline)
    else
      %{some_attribute: "ok"}
    end
  end

  step step_with_halt_error(pipeline, value) do
    if value == :trigger_error do
      {:error, :halt, "this is an error"}
    else
      %{some_attribute: "ok"}
    end
  end

  step step_with_value_and_halt(pipeline, value) do
    if value == :trigger_halt do
      {:ok, :halt, %{some_attribute: "value after halt"}}
    else
      {:ok, %{some_attribute: "first value"}}
    end
  end

  step step_with_just_ok(pipeline) do
    :ok
  end
end
