defmodule LogflareWeb.EndpointController do
  use LogflareWeb, :controller
  import Ecto.Query, only: [from: 2]
  require Logger
  alias Logflare.Endpoint
  plug CORSPlug,
    origin: "*",
    max_age: 1_728_000,
    headers: [
      "Authorization",
      "Content-Type",
      "Content-Length",
      "X-Requested-With",
      "X-API-Key"
    ],
    methods: ["GET", "POST", "OPTIONS"],
    send_preflight_response?: true

  def query(%{params: %{"token" => token}} = conn, _) do
    endpoint_query = Endpoint.get_query_by_token(token)

    case Logflare.Endpoint.Cache.resolve(endpoint_query, conn.query_params)
         |> Logflare.Endpoint.Cache.query() do
      {:ok, result} ->
        render(conn, "query.json", result: result.rows)

      {:error, err} ->
        render(conn, "query.json", error: err)
    end
  end

  def index(%{assigns: %{user: user}} = conn, _) do
    render(conn, "index.html",
      endpoint_queries: Logflare.Repo.preload(user, :endpoint_queries).endpoint_queries,
      current_node: Node.self()
    )
  end

  def show(%{assigns: %{user: user}, params: %{"id" => id}} = conn, _) do
    endpoint_query =
      from(q in Logflare.Endpoint.Query,
        where: q.user_id == ^user.id and q.id == ^id
      )
      |> Logflare.Repo.one()
      |> Logflare.Endpoint.Query.map_query()

    parameters =
      case Logflare.SQL.parameters(endpoint_query.query) do
        {:ok, params} -> params
        _ -> []
      end

    render(conn, "show.html",
      endpoint_query: endpoint_query,
      parameters: parameters,
      current_node: Node.self()
    )
  end

  def edit(%{assigns: %{user: user}, params: %{"id" => id}} = conn, _) do
    endpoint_query =
      from(q in Logflare.Endpoint.Query,
        where: q.user_id == ^user.id and q.id == ^id
      )
      |> Logflare.Repo.one()
      |> Logflare.Repo.preload(:user)
      |> Logflare.Endpoint.Query.map_query()

    changeset = Logflare.Endpoint.Query.update_by_user_changeset(endpoint_query, %{})

    render(conn, "edit.html",
      endpoint_query: endpoint_query,
      changeset: changeset,
      current_node: Node.self()
    )
  end

  def new(conn, _) do
    changeset = Logflare.Endpoint.Query.update_by_user_changeset(%Logflare.Endpoint.Query{}, %{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(%{assigns: %{user: user}} = conn, %{"query" => params}) do
    params =
      params
      |> Map.put("token", Ecto.UUID.generate())

    Logflare.Endpoint.Query.update_by_user_changeset(%Logflare.Endpoint.Query{user: user}, params)
    |> Logflare.Repo.insert()
    |> case do
      {:ok, endpoint_query} ->
        conn
        |> put_flash(:info, "Endpoint created!")
        |> redirect(to: Routes.endpoint_path(conn, :show, endpoint_query.id))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong!")
        |> assign(:changeset, changeset)
        |> render("new.html", changeset: changeset)
    end
  end

  def update(%{assigns: %{user: user}} = conn, %{"id" => id, "query" => params}) do
    endpoint_query =
      from(q in Logflare.Endpoint.Query,
        where: q.user_id == ^user.id and q.id == ^id
      )
      |> Logflare.Repo.one()
      |> Logflare.Repo.preload(:user)

    for q <- Logflare.Endpoint.Cache.resolve(endpoint_query),
        do: Logflare.Endpoint.Cache.invalidate(q)

    Logflare.Endpoint.Query.update_by_user_changeset(endpoint_query, params)
    |> Logflare.Repo.update()
    |> case do
      {:ok, endpoint_query} ->
        conn
        |> put_flash(:info, "Endpoint updated!")
        |> redirect(to: Routes.endpoint_path(conn, :show, endpoint_query.id))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong!")
        |> assign(:changeset, changeset)
        |> render("edit.html",
          changeset: changeset,
          endpoint_query: endpoint_query
        )
    end
  end

  def reset_url(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    endpoint_query =
      from(q in Logflare.Endpoint.Query,
        where: q.user_id == ^user.id and q.id == ^id
      )
      |> Logflare.Repo.one()
      |> Logflare.Repo.preload(:user)

    Logflare.Endpoint.Query.update_by_user_changeset(endpoint_query, %{
      token: Ecto.UUID.generate()
    })
    |> Logflare.Repo.update()
    |> case do
      {:ok, endpoint_query} ->
        conn
        |> put_flash(:info, "Endpoint updated!")
        |> redirect(to: Routes.endpoint_path(conn, :edit, endpoint_query.id))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Something went wrong!")
        |> assign(:changeset, changeset)
        |> render("edit.html",
          changeset: changeset,
          endpoint_query: endpoint_query
        )
    end
  end

  def delete(%{assigns: %{user: user}} = conn, %{"id" => id}) do
    _endpoint_query =
      from(q in Logflare.Endpoint.Query,
        where: q.user_id == ^user.id and q.id == ^id
      )
      |> Logflare.Repo.one()
      |> Logflare.Repo.preload(:user)
      |> Logflare.Repo.delete()
      |> case do
        {:ok, _endpoint_query} ->
          conn
          |> put_flash(:info, "Endpoint deleted!")
          |> redirect(to: Routes.endpoint_path(conn, :index))

        {:error, changeset} ->
          conn
          |> put_flash(:error, "Something went wrong!")
          |> assign(:changeset, changeset)
          |> redirect(to: Routes.endpoint_path(conn, :index))
      end
  end

  def apply(%{assigns: %{user: user}} = conn, _params) do
    Logger.info("Endpoints application submitted.", %{user: %{id: user.id, email: user.email}})

    conn
    |> put_flash(:info, "Successfully applied for the Endpoints beta. We'll be in touch!")
    |> redirect(to: Routes.endpoint_path(conn, :index))
  end
end
