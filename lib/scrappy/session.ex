defmodule Scrappy.Session do

  @type t() :: %__MODULE__{
        url: String.t(),
        body: String.t(),
        cookies: List.t(),
        status: atom
      }

  defstruct url: nil,
  body: nil,
  cookies: [],
  status: nil

end
