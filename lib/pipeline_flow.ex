defmodule PipelineFlow do
  @moduledoc """
  Module to formalize flow

  ## Examples

  ```elixir
  defmodule OrderFlow do
    use PipelineFlow

    attributes reference: nil,
      items: []
  end
  ```
  """

  defmodule Error do
    defexception [:message]
  end

  @type pipeline :: %{:__struct__ => atom(), :__pipeline__ => true, optional(atom()) => any()}
  @type pipeline_mod :: atom()
  @type step :: atom()

  alias PipelineFlow.MacroHelpers

  defmacro __using__(_opts) do
    quote do
      @before_compile PipelineFlow

      import PipelineFlow, only: [attrs: 1, step: 2, step: 3]
      import PipelineFlow.Helpers
    end
  end

  @doc """
  Defines struct for PipelineFlow module
  """
  defmacro attrs(attrs) do
    default_struct_attrs = [
      __pipeline__: true,
      completed_steps: [],
      error: nil,
      halted: false,
      last_step: nil,
      parent: nil,
      value: :not_set,
      warnings: []
    ]

    struct_attrs = default_struct_attrs ++ attrs

    fields = Keyword.keys(attrs)

    quote do
      Kernel.defstruct(unquote(struct_attrs))

      @type t() :: %__MODULE__{}

      Module.register_attribute(__MODULE__, :steps, accumulate: true)
      Module.register_attribute(__MODULE__, :required_steps, accumulate: true)

      @spec new() :: t()
      def new, do: %__MODULE__{}

      @spec new(map()) :: t()
      def new(%{} = attrs), do: set_attribute(%__MODULE__{}, attrs)

      defoverridable new: 1

      @spec fields() :: list(atom())
      def fields, do: unquote(fields)

      @spec result(t()) :: {:error, :atom, any()}
      def result(%__MODULE__{} = pipeline), do: PipelineFlow.Helpers.result(pipeline)

      @spec exec(t()) :: {:ok, any()} | {:error, atom(), any()}
      def exec(%__MODULE__{} = pipeline), do: PipelineFlow.Helpers.exec(pipeline)
    end
  end

  @doc """
  Defines a step
  """
  defmacro step(fun_def, do: body), do: define_step(fun_def, [], body)

  defmacro step(fun_def, options, do: body), do: define_step(fun_def, options, body)

  defp define_step(fun_def, options, body) when is_list(options) do
    {function, pipeline_arg} =
      case fun_def do
        {:when, _, [{function, _, [pipeline_arg | _]} | _]} ->
          {function, pipeline_arg}

        {function, _, [pipeline_arg | _tail]} ->
          {function, pipeline_arg}
      end

    required_steps = Keyword.get(options, :requires, [])
    required_steps = if is_list(required_steps), do: required_steps, else: [required_steps]

    fun_wrap_def =
      quote do
        pipeline = var!(unquote(pipeline_arg))

        if pipeline.halted do
          pipeline
        else
          if completed?(pipeline, unquote(required_steps)) do
            result = unquote(body)

            set_result(pipeline, unquote(function), result)
          else
            raise Error,
              message: "All required steps must be executed before calling this step"
          end
        end
      end

    quote do
      @required_steps {unquote(function), unquote(required_steps)}
      @steps unquote(function)

      def(unquote(fun_def), unquote(do: fun_wrap_def))
    end
  end

  defmacro __before_compile__(env) do
    steps = Module.get_attribute(env.module, :steps)

    steps = Enum.uniq(steps)
    required_steps = Module.get_attribute(env.module, :required_steps)

    MacroHelpers.check_required_steps!(steps, required_steps)

    steps_order = MacroHelpers.find_steps_order!(required_steps)

    quote do
      def steps, do: unquote(steps)
      def steps_order, do: unquote(Macro.escape(steps_order))
    end
  end
end
