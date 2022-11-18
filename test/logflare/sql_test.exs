defmodule Logflare.SqlTest do
  @moduledoc false
  use Logflare.DataCase
  alias Logflare.SQL
  alias Logflare.SqlV2
  alias Ecto.Adapters.SQL.Sandbox
  @project_id "logflare-dev-238720"
  @env "test"
  setup do
    start_supervised!(SQL)

    on_exit(fn ->
      Sandbox.unboxed_run(Logflare.Repo, fn ->
        Logflare.Repo.delete_all(Logflare.User)
        Logflare.Repo.delete_all(Logflare.Source)
      end)
    end)

    :ok
  end

  test "transforms table names correctly" do
    Sandbox.unboxed_run(Logflare.Repo, fn ->
      user = insert(:user)
      source = insert(:source, user: user, name: "my_table")
      source_other = insert(:source, user: user, name: "other_table")
      table = bq_table_name(source)
      table_other = bq_table_name(source_other)

      for {input, expected} <- [
            # quoted
            {"select val from `my_table` where `my_table`.val > 5",
             "select val from #{table} where #{table}.val > 5"},
            # where
            {"select val from my_table where my_table.val > 5",
             "select val from #{table} where #{table}.val > 5"},
            # select named column
            {"select val, my_table.abc from my_table", "select val, #{table}.abc from #{table}"},
            # group by
            {"select val from my_table group by my_table.val",
             "select val from #{table} group by #{table}.val"},
            #  order by
            {"select val from my_table order by my_table.val",
             "select val from #{table} order by #{table}.val"},
            #  CTE
            {"with src as (select n from `my_table`) select n from src",
             "with src as (select n from #{table}) select n from src"},
            # having
            {"select val from my_table group by my_table.abc having count(my_table.id) > 5",
             "select val from #{table} group by #{table}.abc having count(#{table}.id) > 5"},
            # alias
            {"select a from my_table as src where src.b > 5",
             "select a from #{table} as src where src.b > 5"},
            # joins
            {"select a from my_table left join other_table on my_table.d = other_table.e",
             "select a from #{table} left join #{table_other} on #{table}.d = #{table_other}.e"},
            # CTE with union
            {"with abc as (select val from my_table where val > 5) select val from abc union select a from other_table",
             "with abc as (select val from #{table} where val > 5) select val from abc union select a from #{table_other}"},
            # recursive CTE
            {"with src as (select a from my_table union select a from src) select a from src",
             "with src as (select a from #{table} union select a from src) select a from src"},
            # CTE referencing
            {
              "with src as (select a from my_table), abc as (select b from src) select c from abc union select a from src",
              "with src as (select a from #{table}), abc as (select b from src) select c from abc union select a from src"
            },
            # sandboxed queries
            {
              {"with src as (select a from my_table), src2 as (select a from src where a > 5) select c from src",
               "select a, b, c from src2"},
              "with src as (select a from #{table}), src2 as (select a from src where a > 5) select a, b, c from src2"
            }
          ] do
        assert {:ok, v1} = SQL.transform(input, user)
        assert {:ok, v2} = SqlV2.transform(input, user)
        assert String.downcase(v1) == String.downcase(v2)
        assert String.downcase(v2) == expected
      end

      # queries where v1 differs from v2, don't test for equality
      for {input, expected} <- [
            # subquery
            {"select a from (select b from my_table)", "select a from (select b from #{table})"}
          ] do
        assert {:ok, v2} = SqlV2.transform(input, user)
        assert String.downcase(v2) == expected
      end
    end)
  end

  defp bq_table_name(%{user: user} = source) do
    token =
      source.token
      |> Atom.to_string()
      |> String.replace("-", "_")

    "`#{@project_id}.#{user.id}_#{@env}.#{token}`"
  end
end
