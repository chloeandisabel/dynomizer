defmodule Dynomizer.Heroku.Ref do
  @moduledoc """
  Heroku id/name reference structure.
  """
  
  @derive [Poison.Encoder]
  
  defstruct id: "", name: ""

  @type t :: %__MODULE__{id: String.t, name: String.t}
end
