defmodule PipelineFlow.HelpersTest do
  use ExUnit.Case

  alias PipelineFlow.Helpers

  doctest PipelineFlow.Helpers

  describe "result/1" do
    test "ok" do
      assert Helpers.result(%TestPipeline{}) == {:ok, %TestPipeline{}}
    end

    test "ok with set value" do
      assert Helpers.result(%TestPipeline{value: "final-result"}) == {:ok, "final-result"}
    end

    test "ok with defined value function" do
      assert Helpers.result(%TestPipeline2{some_attribute: "this-is-the-final-result"}) ==
               {:ok, "this-is-the-final-result"}
    end

    test "with error" do
      assert Helpers.result(%TestPipeline{
               error: :internal_server_error,
               last_step: :result_tuple_on_argument_two_arguments
             }) ==
               {:error, :result_tuple_on_argument_two_arguments, :internal_server_error}
    end
  end

  test "set_parent/1" do
    pipeline_1 = %TestPipeline{}
    pipeline_2 = %TestPipeline2{}

    assert pipeline_1.parent == nil
    assert pipeline_2.parent == nil

    %TestPipeline2{} = pipeline_2 = Helpers.set_parent(pipeline_2, pipeline_1)
    assert pipeline_2.parent == pipeline_1
  end

  test "allows_exec?/1" do
    refute Helpers.allows_exec?(TestPipeline)
    assert Helpers.allows_exec?(TestPipeline2)
  end

  describe "exec/1" do
    test "exec entire flow" do
      pipeline = TestPipeline2.new()

      assert TestPipeline2.exec(pipeline) == {:ok, "fourth-step"}
    end

    test "cannot exec flow because the module doesn't allow it" do
      assert_raise PipelineFlow.Error, "Not all steps are defined with an arity of one", fn ->
        pipeline = TestPipeline.new()
        TestPipeline.exec(pipeline)
      end
    end
  end
end
