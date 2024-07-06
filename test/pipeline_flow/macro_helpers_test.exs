defmodule PipelineFlow.MacroHelpersTest do
  use ExUnit.Case

  alias PipelineFlow.MacroHelpers

  describe "find_steps_order!/1" do
    test "straight line" do
      steps = [
        {:second_step, [:first_step]},
        {:third_step, [:second_step]},
        {:first_step, []}
      ]

      assert MacroHelpers.find_steps_order!(steps) == [:first_step, :second_step, :third_step]
    end

    test "multiple starts" do
      steps = [
        {:second_step, [:first_step]},
        {:third_step, [:second_step]},
        {:first_step, []},
        {:another_first_step, []}
      ]

      assert MacroHelpers.find_steps_order!(steps) == [
               :another_first_step,
               :first_step,
               :second_step,
               :third_step
             ]
    end

    test "multiple requires" do
      steps = [
        {:second_step, [:third_step, :first_step]},
        {:third_step, [:second_step]},
        {:first_step, []},
        {:fourth_step, [:third_step]}
      ]

      assert MacroHelpers.find_steps_order!(steps) == [
               :first_step,
               :second_step,
               :third_step,
               :fourth_step
             ]
    end
  end
end
