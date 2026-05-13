defmodule QlockWeb.PageController do
  use QlockWeb, :controller

  def home(conn, _params) do
    conn
    |> put_layout(html: false)
    |> render(:home, current_page: :home)
  end
end
