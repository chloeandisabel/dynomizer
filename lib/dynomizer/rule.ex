defmodule Dynomizer.Rule do
  @moduledoc """
  Rules must be in one of the following formats:

  - An integer, optionally preceded by a sign (e.g., 12, +3, -5). A number
    without a sign indicates that the number of dynos should be set to that
    number. Else, the number is added to or subtracted from the current
    number of dynos.

  - A percentage, optionally preceded by a sign (e.g., 80%, +10%, -5.5%). As
    with integer rules, a number without a sign indicates that the number of
    dynos should be set to that percentage. Else, the percentage is added to
    or subtracted from the current number of dynos.

  - A multiplication or division sign followed by a number (e.g., /2, *3.5).

  A reminder: starting with one number, adding X%, then subtracting X%, does
  not result in the original number. For example 100 + 30% = 130, but 130 -
  30% = 91.
  """

  @doc """
  Given a rule string and an integer, return the result of applying the rule
  to the integer.

  ## Examples

  iex> Dynomizer.Rule.apply("10", 5)
  10
  iex> Dynomizer.Rule.apply("+10", 5)
  15
  iex> Dynomizer.Rule.apply("-3", 5)
  2
  iex> Dynomizer.Rule.apply("-10", 5) # won't go below 0
  0
  iex> Dynomizer.Rule.apply("20%", 5)
  1
  iex> Dynomizer.Rule.apply("+20%", 5)
  6
  iex> Dynomizer.Rule.apply("-20%", 5)
  4
  iex> Dynomizer.Rule.apply("-200%", 5) # won't go below 0
  0
  iex> Dynomizer.Rule.apply("*3", 5)
  15
  iex> Dynomizer.Rule.apply("*3.5", 5) # rounds the result
  18
  iex> Dynomizer.Rule.apply("/2", 5)
  3
  """
  def apply(rule_str, i) do
    rule_str
    |> parse
    |> apply_rule(i)
    |> max(0)
  end

  @doc """
  Given a rule string, return a tuple of the form
  {type_sym, sign (1 or -1), amount}

  ## Examples

  iex> Dynomizer.Rule.parse("3")
  {:number, nil, 3.0}
  iex> Dynomizer.Rule.parse("+3")
  {:number, 1, 3.0}
  iex> Dynomizer.Rule.parse("-3")
  {:number, -1, 3.0}
  iex> Dynomizer.Rule.parse("10%")
  {:percent, nil, 10.0}
  iex> Dynomizer.Rule.parse("+10.5%")
  {:percent, 1, 10.5}
  iex> Dynomizer.Rule.parse("-10%")
  {:percent, -1, 10.0}
  iex> Dynomizer.Rule.parse("*3.5")
  {:multiply, 3.5}
  iex> Dynomizer.Rule.parse("/3.5")
  {:divide, 3.5}
  """
  def parse(rule_str) do
    len = String.length(rule_str)
    first_char = String.at(rule_str, 0)
    last_char = String.at(rule_str, len-1)
    cond do
      first_char == "*" || first_char == "/" ->
        sym = if first_char == "*", do: :multiply, else: :divide
        {num, _} = rule_str |> String.slice(1, len-1) |> String.trim |> Float.parse
        {sym, num}
      last_char == "%" ->
        {sign, number} = signed_number(String.slice(rule_str, 0, len-1))
        {:percent, sign, number}
      true ->
        {sign, number} = signed_number(rule_str)
        {:number, sign, number}
    end
  end

  defp sign?("-"), do: true
  defp sign?("+"), do: true
  defp sign?(_), do: false

  # Return {sign, number} where sign is nil (absolute change), 1
  # (increment), or -1 (decrement).
  defp signed_number(s) do
    first_char = String.at(s, 0)
    sign = case first_char do
             "-" -> -1
             "+" -> 1
             _ -> nil
           end
    slice_start = if sign?(first_char), do: 1, else: 0
    maxlen = String.length(s)
    {num, _} = s |> String.slice(slice_start, maxlen) |> Float.parse
    {sign, num}
  end

  def apply_rule({:number, nil, num}, _i) do
    round(num)
  end
  def apply_rule({:number, sign, num}, i) do
    i + round(sign * num)
  end
  def apply_rule({:percent, nil, num}, i) do
    round(i * num / 100.0)
  end
  def apply_rule({:percent, sign, num}, i) do
    i + round(i * sign * num / 100.0)
  end
  def apply_rule({:multiply, num}, i) do
    round(i * num)
  end
  def apply_rule({:divide, num}, i) do
    round((i * 1.0) / (num * 1.0))
  end
end
