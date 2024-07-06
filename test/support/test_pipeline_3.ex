defmodule TestPipeline3 do
  use PipelineFlow

  attrs(some_attribute: nil)

  def first_step(%TestPipeline3{} = pipeline),
    do:
      pipeline
      |> set_last_step(:first_step)
      |> set_attribute(:some_attribute, "first-step")

  def second_step(%TestPipeline3{halted: true} = pipeline), do: pipeline

  def second_step(%TestPipeline3{} = pipeline),
    do: set_attribute(pipeline, :some_attribute, "second-step")

  def trigger_error(%TestPipeline3{} = pipeline) do
    pipeline
    |> set_error("some error")
    |> set_last_step(:trigger_error)
    |> halt()
  end
end
