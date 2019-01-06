Process.register(self(), :demo)

defmodule Demo do
    def run(tries \\ 10)
    def run(0), do: :done

    def run(tries) do
        {:ok, hostname} = :inet.gethostname
        pony = {:any, :"pony@#{String.downcase("#{hostname}")}"}
        IO.inspect(pony)
        send(pony, {self(),"Hi!"})
        receive do
            m -> IO.puts "received: #{m}"
        after
            3_000 ->
                IO.puts "nobody sent anything, exiting"
        end

        run(tries - 1)
    end
end

Demo.run()
