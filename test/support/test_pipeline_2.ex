defmodule TestPipeline2 do
  use PipelineFlow

  attrs(some_attribute: nil)

  def value(pipeline) when is_pipeline(pipeline), do: pipeline.some_attribute

  step second_step(pipeline), requires: :first_step do
    %{some_attribute: "second_step"}
  end

  step third_step(pipeline), requires: [:first_step, :second_step] do
    %{some_attribute: "third-step"}
  end

  step fourth_step(pipeline), requires: [:third_step] do
    %{some_attribute: "fourth-step"}
  end

  step first_step(pipeline) do
    %{some_attribute: "first-step"}
  end
end
