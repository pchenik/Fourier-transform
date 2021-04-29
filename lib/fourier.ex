defmodule Fourier do

    def vector(a) do
      receive do
        #{:get_elem, ind, cust} -> send cust, {:get, PersistentVector.get(a, ind)}
        {:get, ind, cust} -> send cust, {:get, elem(a, ind)}
        {:get_elem, ind, cust} -> send cust, {:backward, PersistentVector.get(a, ind)}
      end
      vector(a)
    end

    def test_vector do
      receive do
        {:launch, ind, cust} -> send cust, {:get, ind, self()}
        {:launch_vector, ind, cust} -> send cust, {:get_elem, ind, self()}
        {:get, num} -> IO.puts "The number is #{num.re} + #{num.im}i"
        {:collect, res, flag} -> IO.inspect res
        {:test} -> IO.puts "Say something"
      end
      test_vector()
    end

    def custom_merge(n, w, cust, flag) do
      receive do
        {:calculate, res, res_ind, i} ->
          b = Complex.mult(Complex.pow(w, Complex.new(i, 0)), PersistentVector.get(res, i + n))
          #IO.puts "b = #{b.re}, i = #{i}"
          a = PersistentVector.get(res, i + res_ind)
          first = Complex.sub(a, b)
          second = Complex.add(a, b)
          res = PersistentVector.set(res, (i + res_ind + n), first)
          res = PersistentVector.set(res, (i + res_ind), second)
          if i + 1 < n do
            send cust, {:calculate, res, res_ind, i + 1}
          else
            send cust, {:collect, res, flag}
          end
      end
    end

    def test_custom_merge(merge_res, res_ind, n, w, flag) do
      receive do
        {:calculate, i, cust} ->
            if i == 0 do
              send cust, {:calculate, merge_res, res_ind, i}
            else
              cc = spawn(Fourier, :custom_merge, [div(n, 2), w, cust, flag])
              send self(), {:calculate, i - 1, cc}
            end
      end
      test_custom_merge(merge_res, res_ind, n, w, flag)
     end

     # def test do
     #   receive do
     #     {:calculate, i, cust} ->
     #         if i == 0 do
     #           send cust, {:test}
     #         else
     #           IO.puts i
     #           send(self(), {:calculate, i - 1, cust})
     #         end
     #   end
     #   test()
     #  end

    def merge(even, odd, w, res_ind, n, cust, flag, merge_res) do
      receive do
        {:collect, res, is_right} ->
            if even == :nil and odd == :nil do
              if is_right == true do
                  merge(:nil, res, w, res_ind, n, cust, flag, :nil)
              else
                  merge(res, :nil, w, res_ind, n, cust, flag, :nil)
              end
            else
                #merge_res = PersistentVector.empty()
                merge_res = if is_right == true do
                                PersistentVector.new(PersistentVector.to_list(even)
                                  ++ PersistentVector.to_list(res))
                            else
                                PersistentVector.new(PersistentVector.to_list(res)
                                  ++ PersistentVector.to_list(odd))
                            end
                #IO.inspect merge_res
                c = spawn(Fourier, :merge, [:nil, :nil, w, res_ind, n, cust, flag, merge_res])
                send c, {:calculate, div(n, 2), cust}
                Process.exit(self(), :kill)
            end
        {:calculate, i, cust} ->
            if i == 0 do
              send cust, {:calculate, merge_res, res_ind, i}
            else
              cc = spawn(Fourier, :custom_merge, [div(n, 2), w, cust, flag])
              send self(), {:calculate, i - 1, cc}
            end
            merge(:nil, :nil, w, res_ind, n, cust, flag, merge_res)
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

    def fft(w, cust, get_element, flag) do
      receive do
        {:forward, a_ind, res_ind, n, k} ->
          if n == 1 do
            send get_element, {:get_elem, a_ind, self()}
          else
            c = spawn(Fourier, :merge, [:nil, :nil, w, res_ind, n, cust, flag, :nil])
            even = spawn(Fourier, :fft, [Complex.pow(w, Complex.new(2, 0)), c, get_element, false])
            odd = spawn(Fourier, :fft, [Complex.pow(w, Complex.new(2, 0)), c, get_element, true])
            send even, {:forward, a_ind, res_ind, div(n, 2), 2 * k}
            send odd, {:forward, a_ind + k, res_ind, div(n, 2), 2 * k}
          end
        {:backward, new_val} ->
            res = PersistentVector.new([new_val])
            #IO.inspect res
            send cust, {:collect, res, flag}
      end
      fft(w, cust, get_element, flag)
    end

end

#TEST fft
cust = spawn(Fourier, :test_vector, [])
list1 = String.split(File.read!("./lib/numbers.txt"))
list2 = Enum.map(list1, fn x -> Complex.new(String.to_integer(x), 0) end)
arr1 = PersistentVector.new(list2)
n = PersistentVector.count(arr1)
IO.puts n
w = Complex.fromPolar(1, :math.pi * 2 / n);
get_element1 = spawn(Fourier, :vector, [arr1])
start = spawn(Fourier, :fft, [w, cust, get_element1, true])
send start, {:forward, 0, 0, n, 1}
