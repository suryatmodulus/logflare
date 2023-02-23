defmodule Logflare.Partners do
  @moduledoc """
  Handles Partner context
  """
  import Ecto.Query

  alias Logflare.Partners.Partner
  alias Logflare.Repo
  alias Logflare.Users

  @spec new(binary()) :: {:ok, Partner.t()} | {:error, any()}
  @doc """
  Creates a new partner with given name and token to be encrypted
  """
  def new(name) do
    %Partner{}
    |> Partner.changeset(%{name: name})
    |> Repo.insert()
  end

  @spec list() :: [Partner.t()]
  @doc """
  Lists all partners
  """
  def list(), do: Repo.all(Partner)

  @spec list_users(Partner.t()) :: [User.t()]
  @doc """
  Lists all users created by a partner
  """
  def list_users(%Partner{token: token}) do
    query =
      from(p in Partner,
        join: u in assoc(p, :users),
        where: p.token == ^token,
        select: u
      )

    Repo.all(query)
  end

  @spec get_by_token(binary()) :: Partner.t() | nil

  @doc """
  Fetch single entry by given token
  """
  def get_by_token(token), do: Repo.get_by(Partner, token: token)

  @spec create_user(Partner.t(), map()) ::
          {:ok, %{user: User.t(), user_token: binary()}} | {:error, any()}
  @doc """
  Creates a new user and associates it with given partner
  """
  def create_user(%Partner{} = partner, params) do
    user_token = Ecto.UUID.generate()

    params =
      Map.merge(params, %{
        "provider_uid" => Ecto.UUID.generate(),
        "provider" => "email",
        "token" => user_token
      })

    Repo.transaction(fn ->
      with {:ok, user} <- Users.insert_user(params) do
        {:ok, _} =
          partner
          |> Repo.preload(:users)
          |> Partner.associate_user_changeset(user)
          |> Repo.update()

        %{user_token: user_token, user: user}
      end
    end)
  end

  @spec delete_by_token(binary()) :: {:ok, Partner.t()} | {:error, any()}
  @doc """
  Deletes a partner given his token
  """
  def delete_by_token(token) do
    token
    |> get_by_token()
    |> Repo.delete()
  end

  @spec get_user_by_token_for_partner(Partner.t(), binary()) :: User.t() | nil

  @doc """
  Fetches user by token for a given Partner
  """
  def get_user_by_token_for_partner(%Partner{token: token}, user_token) do
    query =
      from(p in Partner,
        join: u in assoc(p, :users),
        where: p.token == ^token,
        where: u.token == ^user_token,
        select: u
      )

    Repo.one(query)
  end
end
