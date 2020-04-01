defmodule Logflare.ContextCache do
  @moduledoc false

  @deprecated "user apply_fun/3"
  def apply_repo_fun(context, {fun, arity}, args) do
    cache = Module.concat(context, Cache)

    cache_key = {{fun, arity}, args}

    case Cachex.fetch(cache, cache_key, fn {_type, args} ->
           {:commit, apply(context, fun, args)}
         end) do
      {:commit, value} -> value
      {:ok, value} -> value
    end
  end

  def apply_fun(context, {fun, arity}, args) do
    cache = Module.concat(context, Cache)

    cache_key = {{fun, arity}, args}

    case Cachex.fetch(cache, cache_key, fn {_type, args} ->
           {:commit, apply(context, fun, args)}
         end) do
      {:commit, value} -> value
      {:ok, value} -> value
    end
  end
end
