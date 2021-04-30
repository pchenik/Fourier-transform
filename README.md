# Fourier

**Actor model based implementation of the Fast Fourier transform algorithm**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fourier` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fourier, "~> 0.1.0"}
  ]
end
```

## Example
```elixir
#Инициализация процесса, последнего в цепочке выполнения процессов, ответственного за выдачу результатов
cust = spawn(Fourier, :get_result, [])
#Чтение вектора коэффициентов многочлена и преобразование односвязного списка в массив
list = String.split(File.read!("./lib/numbers.txt"))
array = Enum.map(list1, fn x -> Complex.new(String.to_integer(x), 0) end)
        |> PersistentVector.new

#Получение размера массива и инициализация первообразного корня из единицы
n = PersistentVector.count(array)
w = Complex.fromPolar(1, :math.pi * 2 / n)

#Инициализация процесса vector, отвечающий за выдачу коэффициента многочлена
#по запросу и получение времени системы
get_element = spawn(Fourier, :vector, [array])
time = :os.system_time(:millisecond)

#Инициализация процесса с поведением fft и передача ему сообщения - начало вычислений
start = spawn(Fourier, :fft, [w, cust, get_element, true, time])
send start, {:forward, 0, n, 1}
```



Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/fourier](https://hexdocs.pm/fourier).
