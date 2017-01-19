defmodule Dynomizer.Heroku.Formation do
  @moduledoc """
  Heroku formation.
  """
  
  alias Dynomizer.Heroku.Ref
  use Napper.Resource

  @derive [Poison.Encoder]

  defstruct id: "",
    app: %Ref{},
    command: "",
    quantity: 1,
    size: "",
    type: "",
    created_at: nil,
    updated_at: nil

  @type t :: %__MODULE__{
    id: String.t,
    app: Ref.t,
    command: String.t,
    quantity: integer,
    size: String.t,
    type: String.t,
    created_at: String.t,
    updated_at: String.t
  }
end

defimpl Napper.Endpoint, for: Dynomizer.Heroku.Formation do
  def under_master_resource?(_), do: true
  def endpoint_url(_), do: "/formation"
end
