import Config

config :ledger, Ledger.Repo,
  username: "postgres",
  password: "postgres",
  database: "mundo_dev",
  hostname: "127.0.0.1",
  port: "5432",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
