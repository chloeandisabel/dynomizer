defmodule Dynomizer.Router do
  use Dynomizer.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug Dynomizer.Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Dynomizer do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index

    get "/heroku_schedules/snapshot_form", HerokuScheduleController, :snapshot_form
    post "/heroku_schedules/snapshot", HerokuScheduleController, :snapshot
    get "/heroku_schedules/:id/copy", HerokuScheduleController, :copy
    resources "/heroku_schedules", HerokuScheduleController

    get "/hirefire_schedules/snapshot_form", HirefireScheduleController, :snapshot_form
    post "/hirefire_schedules/snapshot", HirefireScheduleController, :snapshot
    get "/hirefire_schedules/:id/copy", HirefireScheduleController, :copy
    resources "/hirefire_schedules", HirefireScheduleController
  end

  # Other scopes may use custom stacks.
  # scope "/api", Dynomizer do
  #   pipe_through :api
  # end
end
