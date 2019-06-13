defmodule Logflare.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      Logflare.Users.Cache,
      Logflare.Sources.Cache,
      Logflare.Logs.RejectedEvents,
      supervisor(Logflare.Repo, []),
      supervisor(LogflareWeb.Endpoint, [])
    ]

    dev_prod_children = [
      supervisor(Logflare.Repo, []),
      Logflare.Users.Cache,
      Logflare.Sources.Cache,
      Logflare.Logs.RejectedEvents,
      {Task.Supervisor, name: Logflare.TaskSupervisor},
      # init Counters before Manager as Manager calls Counters through table create
      supervisor(Logflare.Sources.Counters, []),
      supervisor(Logflare.SystemMetrics, []),
      supervisor(Logflare.Source.Supervisor, []),
      supervisor(LogflareWeb.Endpoint, [])
    ]

    env = Application.get_env(:logflare, :env)

    children =
      if env == :test do
        children
      else
        dev_prod_children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Logflare.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    LogflareWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
