defmodule Fourier do

    def vector(a) do
      receive do
        {:get, ind, cust} -> send cust, {:get, elem(a, ind)}
        {:get_elem, ind, cust} -> send cust, {:backward, PersistentVector.get(a, ind)}
      end
      vector(a)
    end

    def get_result do
      receive do
        {:collect, res, flag, time} ->
          #IO.inspect res
          IO.puts :erlang.float_to_binary((:os.system_time(:millisecond) - time) / 1_000, [decimals: 6])
        {:launch, ind, cust} -> send cust, {:get, ind, self()}
        {:launch_vector, ind, cust} -> send cust, {:get_elem, ind, self()}
        {:get, num} -> IO.puts "The number is #{num.re} + #{num.im}i"
        {:collect, res, flag} -> IO.inspect res
        {:test} -> IO.puts "Say something"
      end
      get_result()
    end

    def custom_merge(n, w, cust, flag, time) do
      receive do
        {:calculate, res, i} ->
          b = Complex.mult(Complex.pow(w, Complex.new(i, 0)), PersistentVector.get(res, i + n))
          a = PersistentVector.get(res, i)
          first = Complex.sub(a, b)
          second = Complex.add(a, b)
          res = PersistentVector.set(res, (i + n), first)
          res = PersistentVector.set(res, (i), second)
          if i + 1 < n do
            send self(), {:calculate, res, i + 1}
          else
            send cust, {:collect, res, flag, time}
            Process.exit(self(), :kill)
          end
      end
      custom_merge(n, w, cust, flag, time)
    end

    def merge(even, odd, w, n, cust, flag, merge_res, time) do
      receive do
        {:collect, res, is_right, time} ->
            if even == :nil and odd == :nil do
              if is_right == true do
                  merge(:nil, res, w, n, cust, flag, :nil, time)
              else
                  merge(res, :nil, w, n, cust, flag, :nil, time)
              end
            else
                merge_res = if is_right == true do
                                PersistentVector.new(PersistentVector.to_list(even)
                                  ++ PersistentVector.to_list(res))
                            else
                                PersistentVector.new(PersistentVector.to_list(res)
                                  ++ PersistentVector.to_list(odd))
                            end
                cc = spawn(Fourier, :custom_merge, [div(n, 2), w, cust, flag, time])
                send cc, {:calculate, merge_res, 0}
                Process.exit(self(), :kill)
            end
        end
      end


    def test_merge(w, n, cust, flag) do
      receive do
        {:test} ->
            c = spawn(Fourier, :merge, [:nil, :nil, w, 0, n, cust, flag, :nil]);
            w2 = Complex.new(0, 1)
            w1 = Complex.new(1, 0)
            left = PersistentVector.new([w1, w1, w1, w1])
            right = PersistentVector.new([w2, w2, w2, w2])
            send c, {:collect, left, false}
            send c, {:collect, right, true}
      end
    end

    def fft(w, cust, get_element, flag, time) do
      receive do
        {:forward, a_ind, n, k} ->
          if n == 1 do
            send get_element, {:get_elem, a_ind, self()}
          else
            c = spawn(Fourier, :merge, [:nil, :nil, w, n, cust, flag, :nil, time])
            even = spawn(Fourier, :fft, [Complex.pow(w, Complex.new(2, 0)), c, get_element, false, time])
            odd = spawn(Fourier, :fft, [Complex.pow(w, Complex.new(2, 0)), c, get_element, true, time])
            send even, {:forward, a_ind, div(n, 2), 2 * k}
            send odd, {:forward, a_ind + k, div(n, 2), 2 * k}
            Process.exit(self(), :kill)
          end
        {:backward, new_val} ->
            res = PersistentVector.new([new_val])
            send cust, {:collect, res, flag, time}
      end
      fft(w, cust, get_element, flag, time)
    end

    def begin do
      cust = spawn(Fourier, :get_result, [])
      list1 = String.split(File.read!("./lib/numbers.txt"))
      list2 = Enum.map(list1, fn x -> Complex.new(String.to_integer(x), 0) end)
      arr = PersistentVector.new(list2)
      n = PersistentVector.count(arr)
      w = Complex.fromPolar(1, :math.pi * 2 / n);
      get_element = spawn(Fourier, :vector, [arr])
      IO.puts n

      time = :os.system_time(:millisecond)
      IO.puts time + 3

      start = spawn(Fourier, :fft, [w, cust, get_element, true, time])
      send start, {:forward, 0, n, 1}
    end


end
