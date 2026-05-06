defmodule QlockWeb.PageController do
  use QlockWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
