defmodule PipelineFlowTest do
  use ExUnit.Case

  test "attributes" do
    assert %TestPipeline{} = pipeline = TestPipeline.new()
    assert pipeline.__pipeline__ == true
    assert pipeline.completed_steps == []
    assert pipeline.error == nil
    assert pipeline.last_step == nil
    assert pipeline.halted == false
    assert pipeline.warnings == []
    assert pipeline.list_attribute == []
    assert pipeline.some_attribute == nil
  end

  describe "step" do
    test "step with only pipeline argument" do
      pipeline = TestPipeline.new()

      assert pipeline.completed_steps == []
      assert pipeline.error == nil
      assert pipeline.last_step == nil
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.result_tuple_on_argument(pipeline)

      assert pipeline.completed_steps == [:result_tuple_on_argument]
      assert pipeline.error == nil
      assert pipeline.last_step == :result_tuple_on_argument
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false
    end

    test "step with extra argument" do
      pipeline = TestPipeline.new()

      assert pipeline.completed_steps == []
      assert pipeline.error == nil
      assert pipeline.last_step == nil
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.result_tuple_on_argument_two_arguments(pipeline, "Coconut")

      assert pipeline.completed_steps == [:result_tuple_on_argument_two_arguments]
      assert pipeline.error == nil
      assert pipeline.last_step == :result_tuple_on_argument_two_arguments
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Coconut"]
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.result_tuple_on_argument_two_arguments(pipeline, "Apple")

      assert pipeline.completed_steps == [
               :result_tuple_on_argument_two_arguments,
               :result_tuple_on_argument_two_arguments
             ]

      assert pipeline.error == nil
      assert pipeline.last_step == :result_tuple_on_argument_two_arguments
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Coconut"]
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false
    end

    test "step with extra argument that spits out error" do
      pipeline =
        TestPipeline.new()
        |> TestPipeline.result_tuple_on_argument_two_arguments(:invalid_data)

      assert pipeline.completed_steps == []
      assert pipeline.error == :invalid_value
      assert pipeline.last_step == :result_tuple_on_argument_two_arguments
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false
    end

    test "step that just returns a plain value" do
      pipeline = TestPipeline.new()

      assert TestPipeline.plain_return_value(pipeline) == :plain_value
    end

    test "step that returns pipline" do
      pipeline = TestPipeline.new()

      assert %TestPipeline{} = pipeline = TestPipeline.pipeline_return_value(pipeline)

      assert pipeline.completed_steps == [:pipeline_return_value]
      assert pipeline.error == nil
      assert pipeline.last_step == :pipeline_return_value
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple"]
      assert pipeline.some_attribute == "Test value"
      assert pipeline.halted == false
    end

    test "step that returns pipline with :ok result tuple" do
      pipeline = TestPipeline.new()

      assert %TestPipeline{} =
               pipeline = TestPipeline.result_tuple_pipeline_return_value(pipeline)

      assert pipeline.completed_steps == [:result_tuple_pipeline_return_value]
      assert pipeline.error == nil
      assert pipeline.last_step == :result_tuple_pipeline_return_value
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple"]
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false
    end

    test "step that returns pipline with :error result tuple" do
      pipeline = TestPipeline.new()

      pipeline = %TestPipeline{pipeline | some_attribute: :trigger_error}

      assert %TestPipeline{} =
               pipeline = TestPipeline.result_tuple_pipeline_return_value(pipeline)

      assert pipeline.completed_steps == []
      assert pipeline.error == :test_error
      assert pipeline.last_step == :result_tuple_pipeline_return_value
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple"]
      assert pipeline.some_attribute == :trigger_error
      assert pipeline.halted == false
    end

    test "step that uses guards" do
      pipeline =
        TestPipeline.new()
        |> TestPipeline.with_guard("test")

      assert pipeline.completed_steps == [:with_guard]
      assert pipeline.error == nil
      assert pipeline.last_step == :with_guard
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == "test"
      assert pipeline.halted == false

      pipeline = TestPipeline.with_guard(pipeline, 25)

      assert pipeline.completed_steps == [:with_guard, :with_guard]
      assert pipeline.error == nil
      assert pipeline.last_step == :with_guard
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == 2500
      assert pipeline.halted == false
    end

    test "step that comes to a halt" do
      pipeline = TestPipeline.new()

      pipeline = TestPipeline.result_tuple_on_argument(pipeline)

      assert pipeline.completed_steps == [:result_tuple_on_argument]
      assert pipeline.error == nil
      assert pipeline.last_step == :result_tuple_on_argument
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_halt(pipeline, "all-is-good")

      assert pipeline.completed_steps == [:step_with_halt, :result_tuple_on_argument]
      assert pipeline.error == nil
      assert pipeline.last_step == :step_with_halt
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == "ok"
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_halt(pipeline, :trigger_halt)

      assert pipeline.completed_steps == [
               :step_with_halt,
               :step_with_halt,
               :result_tuple_on_argument
             ]

      assert pipeline.error == nil
      assert pipeline.last_step == :step_with_halt
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == "ok"
      assert pipeline.halted == true
    end

    test "step that comes to a halt because of an error" do
      pipeline = TestPipeline.new()

      pipeline = TestPipeline.result_tuple_on_argument(pipeline)

      assert pipeline.completed_steps == [:result_tuple_on_argument]
      assert pipeline.error == nil
      assert pipeline.last_step == :result_tuple_on_argument
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_halt_error(pipeline, "all-is-good")

      assert pipeline.completed_steps == [:step_with_halt_error, :result_tuple_on_argument]
      assert pipeline.error == nil
      assert pipeline.last_step == :step_with_halt_error
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == "ok"
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_halt_error(pipeline, :trigger_error)

      assert pipeline.completed_steps == [:step_with_halt_error, :result_tuple_on_argument]

      assert pipeline.error == "this is an error"
      assert pipeline.last_step == :step_with_halt_error
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == "ok"
      assert pipeline.halted == true

      pipeline = TestPipeline.step_with_halt_error(pipeline, :trigger_error)

      assert pipeline.completed_steps == [:step_with_halt_error, :result_tuple_on_argument]

      assert pipeline.error == "this is an error"
      assert pipeline.last_step == :step_with_halt_error
      assert pipeline.warnings == []
      assert pipeline.list_attribute == ["Apple", "Pear", "Pineapple"]
      assert pipeline.some_attribute == "ok"
      assert pipeline.halted == true
    end

    test "step with tuple and :halt command" do
      pipeline = TestPipeline.new()

      assert pipeline.completed_steps == []
      assert pipeline.error == nil
      assert pipeline.last_step == nil
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_value_and_halt(pipeline, "all-is-good")

      assert pipeline.completed_steps == [:step_with_value_and_halt]
      assert pipeline.error == nil
      assert pipeline.last_step == :step_with_value_and_halt
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == "first value"
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_value_and_halt(pipeline, :trigger_halt)

      assert pipeline.completed_steps == [:step_with_value_and_halt, :step_with_value_and_halt]

      assert pipeline.error == nil
      assert pipeline.last_step == :step_with_value_and_halt
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == "value after halt"
      assert pipeline.halted == true
    end

    test "steps that have a requirement with other steps" do
      pipeline =
        TestPipeline2.new()
        |> TestPipeline2.first_step()
        |> TestPipeline2.second_step()
        |> TestPipeline2.third_step()
        |> TestPipeline2.fourth_step()

      assert pipeline.last_step == :fourth_step
      assert pipeline.some_attribute == "fourth-step"
    end

    test "steps that fail because they have a requirement with other steps" do
      assert_raise PipelineFlow.Error,
                   "All required steps must be executed before calling this step",
                   fn ->
                     TestPipeline2.new()
                     |> TestPipeline2.second_step()
                     |> TestPipeline2.third_step()
                   end
    end

    test "step that just returns an :ok" do
      pipeline = TestPipeline.new()

      assert pipeline.completed_steps == []
      assert pipeline.error == nil
      assert pipeline.last_step == nil
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false

      pipeline = TestPipeline.step_with_just_ok(pipeline)

      assert pipeline.completed_steps == [:step_with_just_ok]
      assert pipeline.error == nil
      assert pipeline.last_step == :step_with_just_ok
      assert pipeline.warnings == []
      assert pipeline.list_attribute == []
      assert pipeline.some_attribute == nil
      assert pipeline.halted == false
    end
  end

  test "steps" do
    assert TestPipeline.steps() == [
             :step_with_just_ok,
             :step_with_value_and_halt,
             :step_with_halt_error,
             :step_with_halt,
             :with_guard,
             :pipeline_return_value,
             :plain_return_value,
             :result_tuple_pipeline_return_value,
             :result_tuple_on_argument_two_arguments,
             :result_tuple_on_argument
           ]
  end
end
