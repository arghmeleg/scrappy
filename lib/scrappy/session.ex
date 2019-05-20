defmodule Scrappy.Session do
  @type t() :: %__MODULE__{
          url: String.t(),
          body: String.t(),
          headers: List.t(),
          cookies: List.t(),
          status: atom
        }

  defstruct url: nil,
            body: nil,
            headers: [],
            cookies: [],
            status: nil
end
