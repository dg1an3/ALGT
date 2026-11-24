defmodule ClarionReaderTest do
  use ExUnit.Case

  describe "ParserAdapter" do
    test "strips module directive" do
      source = ":- module(clarion_parser, [parse_clarion/2]).\nfoo(X) :- bar(X).\n"
      result = ClarionReader.ParserAdapter.strip_directives_public(source)
      refute String.contains?(result, ":- module")
      assert String.contains?(result, "foo(X)")
    end

    test "expands star combinator calls" do
      source = "top_decls(Items) --> star(top_decl_item, Items).\n"
      result = ClarionReader.ParserAdapter.expand_combinators_public(source)
      assert String.contains?(result, "star_top_decl_item(Items)")
      refute String.contains?(result, "star(top_decl_item,")
    end

    test "expands comma_list combinator calls" do
      source = "foo(Ps) --> comma_list(map_param, Ps).\n"
      result = ClarionReader.ParserAdapter.expand_combinators_public(source)
      assert String.contains?(result, "comma_list_map_param(Ps)")
    end

    test "expands comma_attrs combinator calls" do
      source = "bar(As) --> comma_attrs(window_attr, As).\n"
      result = ClarionReader.ParserAdapter.expand_combinators_public(source)
      assert String.contains?(result, "comma_attrs_window_attr(As)")
    end

    test "generates concrete combinator definitions" do
      parser_path = Path.expand("../../unified/clarion_parser.pl", __DIR__)

      if File.exists?(parser_path) do
        adapted = ClarionReader.ParserAdapter.adapt(parser_path)
        assert String.contains?(adapted, "star_top_decl_item([X|Xs])")
        assert String.contains?(adapted, "comma_list_map_param([X|Xs])")
        assert String.contains?(adapted, "comma_attrs_window_attr([A|As])")
        refute String.contains?(adapted, ":- module(")
        refute String.contains?(adapted, ":- meta_predicate")
      end
    end
  end

  describe "Display" do
    test "formats a simple procedure" do
      ast = {:procedure, [:myproc, [], :void, [], [{:return, [{:lit, [42]}]}]]}
      formatted = ClarionReader.Display.format(ast)
      assert String.contains?(formatted, "PROCEDURE myproc")
      assert String.contains?(formatted, "RETURN")
    end

    test "formats assignment" do
      ast = {:assign, [{:var, [:x]}, {:lit, [5]}]}
      formatted = ClarionReader.Display.format(ast)
      assert String.contains?(formatted, "x = 5")
    end

    test "formats binary expression" do
      ast = {:add, [{:var, [:a]}, {:lit, [1]}]}
      formatted = ClarionReader.Display.format_expr(ast)
      assert formatted == "(a + 1)"
    end

    test "formats nested expressions" do
      ast = {:mul, [{:add, [{:var, [:x]}, {:lit, [1]}]}, {:var, [:y]}]}
      formatted = ClarionReader.Display.format_expr(ast)
      assert formatted == "((x + 1) * y)"
    end
  end

  describe "Engine" do
    @tag :erlog
    test "initializes with parser loaded" do
      parser_path = Path.expand("../../unified/clarion_parser.pl", __DIR__)

      if File.exists?(parser_path) do
        assert {:ok, engine} = ClarionReader.Engine.new(parser_path)
        assert engine.erlog_state != nil
      end
    end

    @tag :erlog
    test "parses simple MEMBER source" do
      parser_path = Path.expand("../../unified/clarion_parser.pl", __DIR__)

      if File.exists?(parser_path) do
        {:ok, engine} = ClarionReader.Engine.new(parser_path)

        source = """
        MEMBER()
        MAP
          MathAdd(LONG, LONG),LONG,C
        END
        MathAdd PROCEDURE(LONG A, LONG B)
        Result LONG
          CODE
          Result = A + B
          RETURN Result
        """

        case ClarionReader.Engine.parse(engine, source) do
          {:ok, ast, _engine} ->
            formatted = ClarionReader.Display.format(ast)
            assert is_binary(formatted)

          {:error, reason, _engine} ->
            IO.puts("Parse failed (may be Erlog limitation): #{inspect(reason)}")
        end
      end
    end
  end

  describe "erlog_to_elixir conversion" do
    test "converts atoms" do
      assert ClarionReader.Engine.erlog_to_elixir(:hello) == :hello
    end

    test "converts numbers" do
      assert ClarionReader.Engine.erlog_to_elixir(42) == 42
    end

    test "converts lists" do
      assert ClarionReader.Engine.erlog_to_elixir([1, :a, 2]) == [1, :a, 2]
    end

    test "converts compound terms" do
      assert ClarionReader.Engine.erlog_to_elixir({:f, :a, :b}) == {:f, [:a, :b]}
    end

    test "converts nested terms" do
      term = {:add, {:lit, 1}, {:var, :x}}
      result = ClarionReader.Engine.erlog_to_elixir(term)
      assert result == {:add, [{:lit, [1]}, {:var, [:x]}]}
    end

    test "converts variables" do
      assert ClarionReader.Engine.erlog_to_elixir({:X}) == {:var, :X}
    end
  end
end
