Process.register(self(), :demo)

defmodule Demo do
    def run(tries \\ 10)
    def run(0), do: :done

    def run(tries) do
        {:ok, hostname} = :inet.gethostname
        pony = {:any, :"pony@#{String.downcase("#{hostname}")}"}
        IO.inspect(pony, label: "Elixir: pony destination")
        send(pony, {self(),"#{tries}: Hi!"})
        receive do
            m -> IO.puts "Elixir: received: #{inspect(m)}"
        after
            3_000 ->
                IO.puts "Elixir: nobody sent anything, continuing"
        end

        run(tries - 1)
    end
end

IO.puts("Elixir: this process: #{inspect(self())})")

Demo.run()

IO.puts("Elixir: done")
