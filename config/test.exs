import Config

config :ledger, Ledger.Repo,
  username: "postgres",
  password: "postgres",
  database: "mundo_test",
  hostname: "127.0.0.1",
  port: "5432",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :ledger, :sql_sandbox, true
