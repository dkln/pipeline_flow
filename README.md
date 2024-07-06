# PipelineFlow

Magic macro that defines a pipeable struct for you. Comparable with Plug.Conn.
It gives you the tools to properly formalize a flow or a so called operation.
A flow that can fail at any step. The idea is that you define a flow that brings you from A->Z.

With the macro, you can define functions that will be wrapped and will automatically
the merge results, halt on execution and log every executed step.

Imagine the following with statement:

```elixir
def make_payment(user_id, order_id) do
  with {:user, {:ok, user}} <- {:user, Users.get_user(user_id)},
    {:order, {:ok, order}} <- {:order, Orders.get_order(order_id)},
    {:auth, {:ok, %{token: token}}} <- {:auth, PaymentApi.get_auth_token(user.app_token)},
    {:payment, {:ok, payment}} <- {:payment, PaymentApi.make_payment(user, token, order)} do
    {:ok, Orders.get_order(order_id)}
  else
    {step, {:error, error}} -> {:error, step, error}
end
```

You could also define a flow by using the `PipelineFlow` macro:

```elixir
defmodule PaymentFlow do
  use PipelineFlow

  attrs(user: nil, order: nil, auth_token: nil)

  step get_user(pipeline) do
    case Users.get_user(pipeline.user_id) do
      {:ok, user} -> %{user: user}
      {:error, error} -> {:error, :halt, error}
    end
  end

  step get_order(pipeline), requires: :get_user do
    case Orders.get_order(pipeline.order_id) do
      {:ok, order} -> %{order: order}
      {:error, error} -> {:error, :halt, error}
    end
  end

  step get_auth_token(pipeline), requires: :get_order do
    case PaymentApi.get_auth_token(user.app_token) do
      {:ok, %{token: token}} -> %{auth_token: token}
      {:error, error} -> {:error, :halt, error}
    end
  end

  step make_payment(pipeline), requires: :get_auth_token do
    case PaymentApi.make_payment(user, token, order) do
      {:ok, %{order: order}} -> {:ok, %{order: order}}
      {:error, error}  -> {:error, :halt, error}
    end
  end

  def value(pipeline), do: pipeline.order
end
```

Now you can do:

```elixir
result =
  %{user_id: user_id, order_id: order_id}
  |> PaymentFlow.new()
  |> PaymentFlow.exec()

case result do
  {:ok, order} -> ...
  {:error, step, reason} -> ...
end
```

Or make your steps more explicit to your fellow developers:

```elixir
result =
  %{user_id: user_id, order_id: order_id}
  |> PaymentFlow.new()
  |> PaymentFlow.get_user()
  |> PaymentFlow.get_order()
  |> PaymentFlow.get_auth_token()
  |> PaymentFlow.make_payment()
  |> PaymentFlow.result()
```

This will now return `{:ok, order}` or `{:error, step_where_it_went_wrong, the_error}`.
You can also call the individual steps if you like:

```elixir
flow = PaymentFlow.new(%{user_id: user_id, order_id: order_id})
flow = PaymentFlow.get_user()
```

And unit test them:

```elixir
flow = PaymentFlow.new(%{user_id: user_id)
flow = PaymentFlow.get_user(flow)

assert flow.user == expected_user
```

## Getting started

In order to get started with a Pipeline, use the `PipelineFlow` macro:

```elixir
defmodule Payment do
  use PipelineFlow
end
```

Next, define the attributes of the struct:

```elixir
defmodule Payment do
  use PipelineFlow

  attrs(user: nil, user_id: nil)
end
```

Now the macro generated a struct `%Payment{}` with attributes `user` and `user_id`. It also exposes the function `new/0` and `new/1` now for you:

```elixir
payment = Payment.new(%{user: user})
```

The general idea is that a pipeline holds a state. Every step can manipulate that state, just like `Plug.Conn` or a `GenServer`.

## Default attributes

A PipelineFlow struct always has a couple of default attributes:

- `last_step`: The last step that was called.
- `error`: The last error that was encountered. Will be set if a step errors.
- `halted`: Indicates if other steps can still be called on the pipeline.
- `completed_steps`: A list of steps that were executed
- `value`: The end result of the execution. Note that this is entirely optional. Can be used by the developer if a pipeline always results in just one useable value.
- `parent`: A reference to another pipeline struct that was called before this pipeline. That way you can chain different pipelines together. For example: a registration flow followed by an onboarding flow.
- `warnings`: A list of warnings that were encountered when a step was executed.

## Defining steps

Steps can be defined by using `step`. `step` just generates a wrapper function for you with the same function name:

```elixir
step get_user(pipeline) do
  :ok
end
```

Note, that the first argument is always the struct to the pipeline itself. You can use this in your function definition:

```elixir
step get_user(pipeline) do
  IO.inspect(pipeline.user_id)

  :ok
end
```

You can now just call this as a function:

```elixir
pipeline = Pipeline.new(user_id)

Payment.get_user(pipeline)
# ok
```

As you can see now, the wrapper function did some stuff for us:

```elixir
IO.inspect pipeline.last_step # get_user
IO.inspect pipeline.completed_steps # [:get_user]
```

## Step return values

Just like `defnew`, the step macro expects the function to return one of the following things:
- `map()` The map() represents the attributs to be set to the struct. The key/values will be merged with the struct. Any unknown keys will be ignored. The `last_step` attribute will be set and the step will be added to `completed_steps`
- `{:ok, map()}` Same as above.
- `:ok` Will just return the struct in the called state.
- `%__MODULE__{}` You can also just return the struct itself as you see fit. The wrapper function will return the struct as you just returned. Besides that, it will also add the step to the list of `completed_steps` and set `last_step`.
- `{:ok, %__MODULE__{}` Same as above.
- `{:error, reason}` In case of an error, the struct will be returned and the `error` attribute of the struct will be set to the returned error. The `last_step` attribute will be set to the called step. Note that the `halted` attribute will **not** be set in this case.
- `{:error, %__MODULE__{}}` Same as above.
- `{:error, :halt, reason}` This will do the same things as {:error, reason} but will also set `halted` to `true`. Meaning: any other steps will not be executed anymore.

## Halted

If the `halted` state is set to the pipeline, other steps will be ignored. So for instance:

```elixir
step trigger_error(pipeline) do
  {:error, :halt, :internal_error}
end

step make_payment(pipeline) do
  IO.puts "This should not be called"
  :ok
end
```

```elixir
pipeline
|> Payment.trigger_error()
|> Payment.make_payment()
```

The step `make_payment` will not be called, since `halted` is set.

## Steps that are dependent on other steps

You can use the `step` macro to define a required step:

```elixir
step get_api_config(pipeline), requires: [:get_user] do
  ...
end
```

If you now call `get_api_config` without calling `get_user`, first, you will get an exception:

```elixir
pipeline = Payment.new(user_id)

pipeline
|> Payment.get_api_config()

# Throws PipelineFlow.Error exception now
```

## Example with an execution chain

Another upside of defining required steps, is that you can define an execution chain of the steps. That way you
can tell the macro in what order certain steps need to be called:

```elixir
defmodule Payment do
  use PipelineFlow

  attrs(user: nil, user_id: nil, api_config: %{}, api_session_token: nil, api_result: nil, product: nil)

  step get_user(pipeline) do
    case Users.get_user(pipeline.user_id) do
      {:ok, user} -> {:ok, %{user: user}
        {:error, :not_found} -> {:error, :not_found}
    end
  end

  step get_api_config(pipeline) do
    Application.get_env(:test_app, :api_config)
  end

  step get_api_session_token(pipeline), requires: [:get_user] do
    case PaymentApi.get_api_token(user: pipeline.api_config[:user], password: pipeline.api_config[:password]) do
      {:ok, %{token: token}} -> {:ok, %{api_session_token: token}}
      {:error, error} -> {:error, :halt, error}
    end
  end

  step pay_for_product(pipeline), requires: [:get_api_session_token] do
    case PaymentApi.pay(pipeline.api_session_token, pipeline.product) do
      {:ok, %{status: "paid"}} -> {:ok, %{payment_result: status}}
      {:ok, %{status: "pending"}} -> {:error, :payment_pending}
      {:error, error} -> {:error, :halt, error}
    end
  end

  step set_product_status(pipeline), requires: [:pay_for_product] do
    case Products.update_status(pipeline.user, pipeline.product, "paid") do
      {:ok, _} -> {:ok, pipeline}
      {:error, error} -> {:error, error}
    end
  end

  def value(pipeline), do: pipeline.product
end
```

You can now execute the individual steps:

```elixir
result =
  %{user_id: user_id}
  |> Payment.new()
  |> Payment.get_user()
  |> Payment.get_api_config()
  |> Payment.pay_for_product()
  |> Payment.set_product_status()
```

Or call the entire chain by just calling `exec`:

```elixir
result =
  %{user_id: user_id}
  |> Payment.new()
  |> Payment.exec()
```

The result in the example above will be `{:ok, product}` or `{:error, :atom_of_step_where_it_went_wrong, error}`.

## Ignored/halted steps

Steps that are "halted" (just like Plug.Conn.halt()) will not be executed and just be ignored. Instead, the pipeline itself will be returned. For example, if the step `get_api_session_token` returns an error with a :halt `{:error, :halt, atom()}`, all the other function calls will be ignored:

```elixir
|> Payment.pay_for_product()
|> Payment.set_product_status()
```

## Example with steps with arguments

You can also define steps that require an argument:

```elixir
defmodule Payment do
  ...

  step get_user(pipeline, user_id) when is_binary(user_id) do
    case Users.get_user(user_id) do
      {:ok, user} -> {:ok, %{user: user, user_id: user_id}}
      {:error, error} -> {:error, error}
    end
  end
end
```

This will give you the opportunity to some more complex stuff with the pipeline. However, take into account that you cannot use `exec` anymore since once of the steps now require a function argument. You can still call the step individually of course:

```elixir
pipeline =
  Payment.new()
  |> Payment.get_user(user_id)
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pipeline` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pipeline, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/pipeline>.
