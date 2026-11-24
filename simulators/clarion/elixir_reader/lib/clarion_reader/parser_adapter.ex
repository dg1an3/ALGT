defmodule ClarionReader.ParserAdapter do
  @moduledoc """
  Preprocesses the SWI-Prolog clarion_parser.pl for Erlog compatibility.

  Transformations:
  1. Strip module/directive declarations (:- module, :- meta_predicate, etc.)
  2. Expand higher-order DCG combinators (star, comma_list, comma_attrs)
     into concrete versions for each specific goal used in the parser
  3. Replace SWI-specific builtins with compat equivalents
  """

  @doc """
  Read the original parser file and return Erlog-compatible source.
  """
  def adapt(parser_path) do
    source = File.read!(parser_path)

    source
    |> strip_directives()
    |> expand_combinators()
    |> strip_combinator_definitions()
    |> append_generated_combinators()
  end

  @doc """
  Write the adapted parser to a file.
  """
  def adapt_to_file(parser_path, output_path) do
    adapted = adapt(parser_path)
    File.write!(output_path, adapted)
    output_path
  end

  # Public wrappers for testing
  def strip_directives_public(source), do: strip_directives(source)
  def expand_combinators_public(source), do: expand_combinators(source)

  # Strip SWI-Prolog directives that Erlog doesn't support
  defp strip_directives(source) do
    source
    |> String.replace(~r/:- module\([^)]*\)\.\n?/, "")
    |> String.replace(~r/:- set_prolog_flag\([^)]*\)\.\n?/, "")
    |> String.replace(~r/:- discontiguous [^\n]*\.\n?/, "")
    |> String.replace(~r/:- meta_predicate [^\n]*\.\n?/, "")
  end

  # All higher-order combinator usages found in the parser
  @star_goals [
    "top_decl_item", "class_member", "control_decl",
    "map_entry_or_module", "field_decl", "of_block",
    "proc_or_routine", "key_decl"
  ]

  @comma_list_goals [
    "map_param", "ident", "proc_param", "expr"
  ]

  @comma_attrs_goals [
    "window_attr", "control_attr", "map_attr",
    "class_attr", "class_method_attr"
  ]

  # Replace star(goal, Var), comma_list(goal, Var), comma_attrs(goal, Var)
  # with star_goal(Var), comma_list_goal(Var), comma_attrs_goal(Var)
  defp expand_combinators(source) do
    source = Enum.reduce(@star_goals, source, fn goal, acc ->
      # Replace "star(goal, X)" with "star_goal(X)" — handle optional space after comma
      Regex.replace(~r/star\(#{Regex.escape(goal)},\s*/, acc, "star_#{goal}(")
    end)

    source = Enum.reduce(@comma_list_goals, source, fn goal, acc ->
      acc
      |> then(&Regex.replace(~r/comma_list_rest\(#{Regex.escape(goal)},\s*/, &1, "comma_list_rest_#{goal}("))
      |> then(&Regex.replace(~r/comma_list\(#{Regex.escape(goal)},\s*/, &1, "comma_list_#{goal}("))
    end)

    Enum.reduce(@comma_attrs_goals, source, fn goal, acc ->
      Regex.replace(~r/comma_attrs\(#{Regex.escape(goal)},\s*/, acc, "comma_attrs_#{goal}(")
    end)
  end

  # Remove the original generic combinator definitions (star/2, comma_list/2, etc.)
  # since we've expanded them into concrete versions
  defp strip_combinator_definitions(source) do
    source
    |> String.replace(
      ~r/^%% star\(\+Goal.*?^star\(\_, \[\]\) --> \[\]\.\n/ms,
      ""
    )
    |> String.replace(
      ~r/^%% comma_list\(\+Goal.*?^comma_list_rest\(\_, \[\]\) --> \[\]\.\n/ms,
      ""
    )
    |> String.replace(
      ~r/^%% comma_attrs\(\+Goal.*?^comma_attrs\(\_, \[\]\) --> \[\]\.\n/ms,
      ""
    )
  end

  # Generate concrete versions of the combinators for each goal
  defp append_generated_combinators(source) do
    star_defs = Enum.map(@star_goals, &generate_star/1) |> Enum.join("\n")
    cl_defs = Enum.map(@comma_list_goals, &generate_comma_list/1) |> Enum.join("\n")
    ca_defs = Enum.map(@comma_attrs_goals, &generate_comma_attrs/1) |> Enum.join("\n")

    """
    #{source}

    %% ==========================================================================
    %% Generated concrete combinators (expanded from higher-order originals)
    %% ==========================================================================

    #{star_defs}

    #{cl_defs}

    #{ca_defs}
    """
  end

  defp generate_star(goal) do
    """
    %% star_#{goal} — zero or more #{goal}, whitespace-separated
    star_#{goal}([X|Xs]) --> #{goal}(X), !, ws, star_#{goal}(Xs).
    star_#{goal}([]) --> [].
    """
  end

  defp generate_comma_list(goal) do
    """
    %% comma_list_#{goal} — comma-separated list of #{goal}
    comma_list_#{goal}([X|Xs]) --> #{goal}(X), ws, comma_list_rest_#{goal}(Xs).
    comma_list_#{goal}([]) --> [].
    comma_list_rest_#{goal}([X|Xs]) --> ",", ws, #{goal}(X), ws, comma_list_rest_#{goal}(Xs).
    comma_list_rest_#{goal}([]) --> [].
    """
  end

  defp generate_comma_attrs(goal) do
    """
    %% comma_attrs_#{goal} — comma-prefixed attribute list of #{goal}
    comma_attrs_#{goal}([A|As]) --> ",", ws, #{goal}(A), !, ws, comma_attrs_#{goal}(As).
    comma_attrs_#{goal}([]) --> [].
    """
  end
end
