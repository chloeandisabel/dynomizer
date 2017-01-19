use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dynomizer, Dynomizer.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :dynomizer, Dynomizer.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "dynomizer_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# The module to use for actual dyno scaling.
config :dynomizer,
  scaler: Dynomizer.MockHeroku

# Napper REST API client configuration
config :napper,
  url: "https://api.example.com",
  auth: "Bearer xyzzy-plugh",
  accept: "application/vnd.heroku+json; version=3",
  master_prefix: "/apps",
  api: Dynomizer.MockHeroku
