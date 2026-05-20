# Role-Based Access Control (RBAC)

## Roles

| Role    | Description                                  |
|---------|----------------------------------------------|
| `:user` | Default. Can manage their own time entries.  |
| `:admin`| Can promote other users. Sends HR broadcasts (future). |

All new registrations default to `:user`. Role is never exposed in the JSON:API response.

---

## Setting Up the First Admin

### Step 1 — Run the migration

After deploying or on a fresh setup, run:

```sh
mix ash.codegen add_role_to_users
mix ash.migrate
```

This adds the `role` column to the `users` table. All existing users default to `:user`.

### Step 2 — Register your account normally

Use the app sign-up flow or the API to create your account:

```sh
POST /api/json/users/register
```

### Step 3 — Promote yourself to admin

```sh
mix qlock.promote_admin your@email.com
```

Output on success:
```
OK: your@email.com is now an admin
```

This command bypasses authorization — it is meant to be run only by a system operator on the server.

---

## Promoting Additional Admins

Any existing admin can promote another user via the `promote_to_admin` Ash action. This can be done through AshAdmin at `/admin` or via a future admin API endpoint.

From the shell:
```sh
mix qlock.promote_admin colleague@email.com
```

---

## How Authorization Works

Roles are enforced exclusively through **Ash policies** in the resource files — never in controllers or LiveViews.

### User resource (`Qlock.Accounts.User`)

| Action              | Who can call it          |
|---------------------|--------------------------|
| `:read`             | Any authenticated user   |
| `:promote_to_admin` | Admins only (or mix task with `authorize?: false`) |

### Adding admin-only actions (e.g. HR broadcast)

When adding a new admin-only action, add this policy block to the relevant resource:

```elixir
policy action(:your_admin_action) do
  authorize_if actor_attribute_equals(:role, :admin)
end
```

---

## Checking Role in LiveView / Controllers

Read the role from `conn.assigns[:current_user].role` or `socket.assigns[:current_user].role`.

Example guard in a LiveView:

```elixir
def mount(_params, _session, socket) do
  if socket.assigns.current_user.role == :admin do
    {:ok, socket}
  else
    {:ok, redirect(socket, to: "/")}
  end
end
```

---

## Security Notes

- `role` attribute has `public?: false` — it never appears in JSON:API responses
- Users cannot change their own role via any API — the `:update` action does not accept `:role`
- The `:promote_to_admin` action only sets role to `:admin`; there is no demotion action (do it via AshAdmin if needed)
- The mix task runs with `authorize?: false` — restrict server access accordingly
