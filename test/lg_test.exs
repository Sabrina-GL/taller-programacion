defmodule LGTest do
  use ExUnit.Case
  doctest LG

  test "greets the world" do
    assert LG.hello() == :world
  end
end
