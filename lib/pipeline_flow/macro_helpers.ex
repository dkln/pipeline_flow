defmodule PipelineFlow.MacroHelpers do
  def check_required_steps!(steps, required_steps) do
    Enum.each(required_steps, fn {step, other_steps} ->
      Enum.each(other_steps, fn other_step ->
        if other_step not in steps do
          raise PipelineFlow.Error,
                "Step #{inspect(step)} has a required step #{inspect(other_step)} that doesn't exist"
        end
      end)
    end)
  end

  def find_steps_order!(step_definitions) do
    steps =
      step_definitions
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()

    first_steps =
      step_definitions
      |> Enum.filter(fn {_step, other_steps} -> other_steps == [] end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Enum.sort()

    if first_steps == [] do
      []
    else
      steps
      |> Enum.reduce({first_steps, first_steps}, fn _step, {current_steps, chain} ->
        dependent_steps =
          current_steps
          |> Enum.map(fn current_step ->
            step_definitions
            |> Enum.filter(fn {other_step, required_steps} ->
              other_step != current_step && current_step in required_steps
            end)
            |> Enum.map(&elem(&1, 0))
          end)
          |> List.flatten()
          |> Enum.uniq()
          |> Enum.sort()

        {dependent_steps, Enum.uniq(chain ++ dependent_steps)}
      end)
      |> elem(1)
    end
  end
end
