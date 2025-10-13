import Config

config :ledger, ecto_repos: [Ledger.Repo]

import_config "#{config_env()}.exs"
