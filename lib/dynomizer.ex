defmodule Dynomizer do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    {:ok, heroku_scaler_module} = Application.fetch_env(:dynomizer, :heroku_scaler)
    {:ok, hirefire_scaler_module} = Application.fetch_env(:dynomizer, :hirefire_scaler)
    children = [
      # Start the Ecto repository
      supervisor(Dynomizer.Repo, []),
      # Start the endpoint when the application starts
      supervisor(Dynomizer.Endpoint, []),
      # Start your own workers
      worker(Dynomizer.Scheduler, [heroku_scaler_module, hirefire_scaler_module])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Dynomizer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Dynomizer.Endpoint.config_change(changed, removed)
    :ok
  end
end
