defmodule Ledger.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      Ledger.Repo
    ]

    opts = [strategy: :one_for_one, name: Ledger.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
