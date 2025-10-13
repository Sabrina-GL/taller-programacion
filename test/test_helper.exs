ExUnit.start()
{:ok, _} = Application.ensure_all_started(:ledger)
Ecto.Adapters.SQL.Sandbox.mode(Ledger.Repo, :manual)
ExUnit.configure(exclude: [pending: true])
