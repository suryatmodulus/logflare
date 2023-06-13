defmodule LogflareWeb.EndpointsLive do
  @moduledoc false
  use LogflareWeb, :live_view
  require Logger
  alias Logflare.Endpoints
  alias Logflare.Users
  alias LogflareWeb.Utils
  use Phoenix.Component
  embed_templates "actions/*", suffix: "_action"
  embed_templates "components/*"

  def render(%{allow_access: false} = assigns), do: closed_beta_action(assigns)

  def render(%{live_action: :index} = assigns), do: index_action(assigns)
  def render(%{live_action: :show, show_endpoint: nil} = assigns), do: not_found_action(assigns)
  def render(%{live_action: :show} = assigns), do: show_action(assigns)
  def render(%{live_action: :new} = assigns), do: new_action(assigns)
  def render(%{live_action: :edit} = assigns), do: edit_action(assigns)

  defp render_docs_link(assigns) do
    ~H"""
    <.subheader_link to="https://docs.logflare.app/endpoints" text="docs" fa_icon="book" />
    """
  end

  defp render_access_tokens_link(assigns) do
    ~H"""
    <.subheader_link to={~p"/access-tokens"} text="access tokens" fa_icon="key" />
    """
  end

  def mount(%{}, %{"user_id" => user_id}, socket) do
    endpoints = Endpoints.list_endpoints_by(user_id: user_id)
    user = Users.get(user_id)

    allow_access =
      Enum.any?([
        Utils.flag("endpointsOpenBeta"),
        user.endpoints_beta
      ])

    {:ok,
     socket
     |> assign(:endpoints, endpoints)
     |> assign(:user_id, user_id)
     |> assign(:user, user)
     |> assign(:query_result_rows, nil)
     |> assign(:show_endpoint, nil)
     |> assign(:endpoint_changeset, Endpoints.change_query(%Endpoints.Query{}))
     |> assign(:allow_access, allow_access)
     |> assign(:base_url, LogflareWeb.Endpoint.url())
     |> assign(:parse_error_message, nil)
     |> assign(:query_string, nil)
     |> assign(:params_form, to_form(%{"query" => "", "params" => %{}}, as: "run"))
     |> assign(:declared_params, [])}
  end

  def handle_params(params, _uri, socket) do
    endpoint_id = params["id"]

    endpoint =
      if endpoint_id do
        Endpoints.get_by(id: endpoint_id, user_id: socket.assigns.user_id)
      end

    socket =
      socket
      |> assign(:show_endpoint, endpoint)
      |> then(fn
        socket when endpoint != nil ->
          {:ok, %{parameters: parameters}} = Endpoints.parse_query_string(endpoint.query)

          socket
          |> update_params_form(parameters)
          # set changeset
          |> assign(:endpoint_changeset, Endpoints.change_query(endpoint, %{}))

        other ->
          other
          # reset the changeset
          |> assign(:endpoint_changeset, nil)
      end)

    {:noreply, socket}
  end

  def handle_event(
        "save-endpoint",
        %{"endpoint" => params},
        %{assigns: %{user: user, show_endpoint: show_endpoint}} = socket
      ) do
    {action, endpoint} =
      case show_endpoint do
        nil ->
          {:ok, endpoint} = Endpoints.create_query(user, params)
          {:created, endpoint}

        %_{} ->
          {:ok, endpoint} = Endpoints.update_query(show_endpoint, params)
          {:updated, endpoint}
      end

    {:noreply,
     socket
     |> put_flash(:info, "Successfully #{Atom.to_string(action)} endpoint #{endpoint.name}")
     |> push_patch(to: Routes.endpoints_path(socket, :show, endpoint))
     |> assign(:show_endpoint, endpoint)}
  end

  def handle_event(
        "delete-endpoint",
        %{"endpoint_id" => id},
        %{assigns: assigns} = socket
      ) do
    endpoint = Endpoints.get_endpoint_query(id)
    {:ok, _} = Endpoints.delete_query(endpoint)
    endpoints = Endpoints.list_endpoints_by(user_id: assigns.user_id)

    {:noreply,
     socket
     |> assign(:endpoints, endpoints)
     |> assign(:show_endpoint, nil)
     |> put_flash(
       :info,
       "#{endpoint.name} has been deleted"
     )
     |> push_patch(to: "/endpoints")}
  end

  def handle_event(
        "run-query",
        %{"run" => payload},
        %{assigns: %{user: user}} = socket
      ) do
    query_string = Map.get(payload, "query", "")
    query_params = Map.get(payload, "params", %{})

    case Endpoints.run_query_string(user, {:bq_sql, query_string}, params: query_params) do
      {:ok, %{rows: rows}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ran query successfully")
         |> assign(:query_result_rows, rows)}

      {:error, err} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error occured when running query: #{inspect(err)}")
         |> assign(:query_result_rows, nil)}
    end
  end

  def handle_event(
        "parse-query",
        %{
          "endpoint" => %{"query" => query_string}
        },
        socket
      ) do
    socket =
      case Endpoints.parse_query_string(query_string) do
        {:ok, %{parameters: params_list}} ->
          socket
          |> assign(:query_string, query_string)
          |> assign(:declared_params, params_list)
          |> assign(:parse_error_message, nil)

        {:error, err} ->
          socket
          |> assign(:parse_error_message, if(is_binary(err), do: err, else: inspect(err)))
      end

    {:noreply, socket}
  end

  def handle_event("apply-beta", _params, %{assigns: %{user: user}} = socket) do
    Logger.info("Endpoints application submitted.", %{user: %{id: user.id, email: user.email}})

    {:noreply,
     socket
     |> put_flash(:info, "Successfully applied for the Endpoints beta. We'll be in touch!")}
  end

  defp update_params_form(socket, parameters) do
    socket
    |> assign(
      :params_form,
      to_form(
        %{
          "query" => nil,
          "params" => for(k <- parameters, do: {k, nil}, into: %{})
        },
        as: "run"
      )
    )
    |> assign(:declared_params, parameters)
  end
end
