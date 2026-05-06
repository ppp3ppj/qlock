# Qlock

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Installer
`
mix igniter.new qlock --with phx.new --with-args "--database sqlite3" \
  --install ash,ash_phoenix --install ash_json_api,ash_sqlite \
  --install ash_authentication,ash_authentication_phoenix \
  --install ash_admin,live_debugger --auth-strategy password --setup --yes
`

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
