defmodule Cachex.TransactionTest do
  use PowerAssert, async: false

  setup do
    { :ok, cache: TestHelper.create_cache() }
  end

  test "transaction requires an existing cache name", _state do
    assert(Cachex.transaction("test", &(&1)) == { :error, "Invalid cache provided, got: \"test\"" })
  end

  test "transaction with a worker instance", state do
    state_result = Cachex.inspect!(state.cache, :worker)
    assert(Cachex.transaction(state_result, &(!!&1)) == { :ok, true })
  end

  test "transaction requires a single arity function", state do
    worker = Cachex.inspect!(state.cache, :state)

    assert_raise(FunctionClauseError, fn ->
      Cachex.Worker.transaction(worker, "test")
    end)

    assert_raise(FunctionClauseError, fn ->
      Cachex.Worker.transaction(worker, fn(_, _) -> true end)
    end)
  end

  test "transaction can write", state do
    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.set(worker, "my_key", "my_value")
    end)

    assert(result == { :ok, true })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, "my_value" })
  end

  test "transaction can have writes aborted", state do
    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.set(worker, "my_key", "my_value")
      Cachex.abort(worker, :dont_wanna)
    end)

    assert(result == { :error, :dont_wanna })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :missing, nil })
  end

  test "transaction can update", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.update(worker, "my_key", "my_new_value")
    end)

    assert(result == { :ok, true })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, "my_new_value" })
  end

  test "transaction can have updates aborted", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.update(worker, "my_key", "my_new_value")
      Cachex.abort(worker, :dont_wanna)
    end)

    assert(result == { :error, :dont_wanna })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, "my_value" })
  end

  test "transaction can delete", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.del(worker, "my_key")
    end)

    assert(result == { :ok, true })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :missing, nil })
  end

  test "transaction can have deletes aborted", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.del(worker, "my_key")
      Cachex.abort(worker, :dont_wanna)
    end)

    assert(result == { :error, :dont_wanna })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, "my_value" })
  end

  test "transaction can incr", state do
    set_result = Cachex.set(state.cache, "my_key", 1)
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.incr(worker, "my_key")
    end)

    assert(result == { :ok, 2 })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, 2 })
  end

  test "transaction can incr with missing", state do
    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.incr(worker, "my_key")
    end)

    assert(result == { :missing, 1 })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, 1 })
  end

  test "transaction can incr with error", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.incr(worker, "my_key")
    end)

    assert(result == { :error, :non_numeric_value })
  end

  test "transaction can have incrs aborted", state do
    set_result = Cachex.set(state.cache, "my_key", 1)
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.incr(worker, "my_key")
      Cachex.abort(worker, :dont_wanna)
    end)

    assert(result == { :error, :dont_wanna })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, 1 })
  end

  test "transaction can take", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.take(worker, "my_key")
    end)

    assert(result == { :ok, "my_value" })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :missing, nil })
  end

  test "transaction can have takes aborted", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.take(worker, "my_key")
      Cachex.abort(worker, :dont_wanna)
    end)

    assert(result == { :error, :dont_wanna })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, "my_value" })
  end

  test "transaction carries out many actions", state do
    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.set(worker, "my_key1", "my_value1")
      Cachex.set(worker, "my_key2", "my_value2")
      Cachex.set(worker, "my_key3", "my_value3")
    end)

    assert(result == { :ok, true })

    size_result = Cachex.size(state.cache)

    assert(size_result == { :ok, 3 })
  end

  test "transaction returns a custom value", state do
    transaction_result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.get(worker, "my_key")
    end)

    assert(transaction_result == { :missing, nil })
  end

  test "transaction clears return an error", state do
    set_result = Cachex.set(state.cache, "my_key", "my_value")
    assert(set_result == { :ok, true })

    result = Cachex.transaction(state.cache, fn(worker) ->
      Cachex.clear(worker)
    end)

    assert(result == { :error, :nested_transaction })
  end

end
