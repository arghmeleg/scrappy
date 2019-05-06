defmodule ScrappyTest do
  use ExUnit.Case
  doctest Scrappy

  test "greets the world" do
    assert Scrappy.hello() == :world
  end
end
