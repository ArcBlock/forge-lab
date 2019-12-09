defmodule ForgeLab do
  def connect do
    ForgeSdk.connect("tcp://127.0.0.1:28210", name: "default", default: true)
  end
end
