defmodule Cachex.Actions.Expire do
  @moduledoc """
  Command module to allow setting entry expiration.

  This module is a little more involved than it would be as it's used as a
  binding for other actions (such as removing expirations). As such, we have
  to handle several edge cases with nil values.
  """
  alias Cachex.Actions
  alias Cachex.Actions.Del
  alias Cachex.Services.Locksmith

  # add required imports
  import Cachex.Actions
  import Cachex.Spec

  ##############
  # Public API #
  ##############

  @doc """
  Sets the expiration time on a given cache entry.

  If a negative expiration time is provided, the entry is immediately removed
  from the cache (as it means we have already expired). If a positive expiration
  time is provided, we update the touch time on the entry and update the expiration
  to the one provided.

  If the expiration provided is nil, we need to remove the expiration; so we update
  in the exact same way. This is done passively due to the fact that Erlang term order
  determines that `nil > -1 == true`.

  This command executes inside a lock aware context to ensure that the key isn't currently
  being used/modified/removed from another process in the application.
  """
  defaction expire(cache() = cache, key, expiration, options) do
    Locksmith.write(cache, key, fn ->
      do_expire(cache, key, expiration)
    end)
  end

  ###############
  # Private API #
  ###############

  # Updates/removes an expiration based on the provided expiration.
  #
  # If the expiration is non-negative, it's set directly in the cache with the
  # touch time updates. Otherwise the entry is immediately removed instead.
  defp do_expire(cache, key, exp) when exp > -1,
    do: Actions.update(cache, key, entry_mod_now(ttl: exp))
  defp do_expire(cache, key, _exp),
    do: Del.execute(cache, key, const(:purge_override))
end
