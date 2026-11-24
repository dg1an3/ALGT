defmodule ClarionReader.Display do
  @moduledoc """
  Pretty-prints a Clarion AST as a readable tree.

  Handles both the raw Erlog term format and the converted Elixir format
  from ClarionReader.Engine.erlog_to_elixir/1.
  """

  @doc """
  Format an AST as a readable string.
  """
  def format(ast) do
    format_node(ast, 0)
  end

  @doc """
  Print an AST to stdout.
  """
  def print(ast) do
    IO.puts(format(ast))
  end

  # Program node — the top-level AST
  defp format_node({:program, [files, groups, globals, map_entries, procedures]}, indent) do
    parts = [
      line(indent, "PROGRAM"),
      format_section(indent + 1, "Files", files),
      format_section(indent + 1, "Groups", groups),
      format_section(indent + 1, "Globals", globals),
      format_section(indent + 1, "MAP", map_entries),
      format_section(indent + 1, "Procedures", procedures)
    ]
    Enum.join(parts, "\n")
  end

  # Procedure
  defp format_node({:procedure, [name, params, ret_type, locals, body]}, indent) do
    header = "PROCEDURE #{format_atom(name)}(#{format_params(params)}) -> #{format_atom(ret_type)}"
    parts = [
      line(indent, header),
      format_section(indent + 1, "Locals", locals),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  # Routine
  defp format_node({:routine, [name, body]}, indent) do
    parts = [
      line(indent, "ROUTINE #{format_atom(name)}"),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  # MAP entry
  defp format_node({:map_entry, [name, params, ret_type, attrs]}, indent) do
    attr_str = if attrs == [], do: "", else: " [#{format_list_inline(attrs)}]"
    line(indent, "MAP_ENTRY #{format_atom(name)}(#{format_params(params)}) -> #{format_atom(ret_type)}#{attr_str}")
  end

  # Module entry
  defp format_node({:module_entry, [mod_name, entries]}, indent) do
    parts = [
      line(indent, "MODULE('#{format_atom(mod_name)}')"),
      format_section(indent + 1, "Entries", entries)
    ]
    Enum.join(parts, "\n")
  end

  # File declaration
  defp format_node({:file, [name, prefix, attrs, fields]}, indent) do
    parts = [
      line(indent, "FILE #{format_atom(name)}, PRE(#{format_atom(prefix)}) #{format_list_inline(attrs)}"),
      format_section(indent + 1, "Fields", fields)
    ]
    Enum.join(parts, "\n")
  end

  # Group
  defp format_node({:group, [name, prefix, fields]}, indent) do
    parts = [
      line(indent, "GROUP #{format_atom(name)}, PRE(#{format_atom(prefix)})"),
      format_section(indent + 1, "Fields", fields)
    ]
    Enum.join(parts, "\n")
  end

  # Queue
  defp format_node({:queue, [name, fields]}, indent) do
    parts = [
      line(indent, "QUEUE #{format_atom(name)}"),
      format_section(indent + 1, "Fields", fields)
    ]
    Enum.join(parts, "\n")
  end

  # Field
  defp format_node({:field, [name, type]}, indent) do
    line(indent, "#{format_atom(name)} #{format_type(type)}")
  end

  # Class
  defp format_node({:class, [name, parent, attrs, members]}, indent) do
    parts = [
      line(indent, "CLASS #{format_atom(name)} (#{format_atom(parent)}) #{format_list_inline(attrs)}"),
      format_section(indent + 1, "Members", members)
    ]
    Enum.join(parts, "\n")
  end

  # Window (4-arg)
  defp format_node({:window, [name, title, attrs, controls]}, indent) do
    parts = [
      line(indent, "WINDOW #{format_atom(name)} '#{format_atom(title)}' #{format_list_inline(attrs)}"),
      format_section(indent + 1, "Controls", controls)
    ]
    Enum.join(parts, "\n")
  end

  # Window (2-arg)
  defp format_node({:window, [name, title]}, indent) do
    line(indent, "WINDOW #{format_atom(name)} '#{format_atom(title)}'")
  end

  # Equate
  defp format_node({:equate, [name, value]}, indent) do
    line(indent, "#{format_atom(name)} EQUATE(#{value})")
  end

  # Local variable
  defp format_node({:local, [name, type, init]}, indent) do
    line(indent, "#{format_atom(name)} #{format_type(type)}(#{init})")
  end

  # Global variable
  defp format_node({:global, [name, type, init]}, indent) do
    line(indent, "#{format_atom(name)} #{format_type(type)}(#{init})")
  end

  # Array
  defp format_node({:array, [name, type, size]}, indent) do
    line(indent, "#{format_atom(name)} #{format_type(type)},DIM(#{size})")
  end

  # Instance variable
  defp format_node({:instance_var, [name, class_name]}, indent) do
    line(indent, "#{format_atom(name)} #{format_atom(class_name)}")
  end

  # --- Statements ---

  defp format_node({:if, [cond, then_body, else_body]}, indent) do
    parts = [
      line(indent, "IF #{format_expr(cond)}"),
      format_section(indent + 1, "THEN", then_body),
      format_section(indent + 1, "ELSE", else_body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:loop, [body]}, indent) do
    parts = [
      line(indent, "LOOP"),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:loop_for, [var, start, end_expr, body]}, indent) do
    parts = [
      line(indent, "LOOP #{format_atom(var)} = #{format_expr(start)} TO #{format_expr(end_expr)}"),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:loop_while, [cond, body]}, indent) do
    parts = [
      line(indent, "LOOP WHILE #{format_expr(cond)}"),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:loop_until, [cond, body]}, indent) do
    parts = [
      line(indent, "LOOP UNTIL #{format_expr(cond)}"),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:case, [expr, ofs, else_body]}, indent) do
    parts = [
      line(indent, "CASE #{format_expr(expr)}"),
      format_section(indent + 1, "OF", ofs),
      format_section(indent + 1, "ELSE", else_body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:of, [range, stmts]}, indent) do
    parts = [
      line(indent, "OF #{format_expr(range)}"),
      format_section(indent + 1, "Stmts", stmts)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:accept, [body]}, indent) do
    parts = [
      line(indent, "ACCEPT"),
      format_section(indent + 1, "Body", body)
    ]
    Enum.join(parts, "\n")
  end

  defp format_node({:assign, [target, expr]}, indent) do
    line(indent, "#{format_expr(target)} = #{format_expr(expr)}")
  end

  defp format_node({:call, [name, args]}, indent) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    line(indent, "#{format_atom(name)}(#{args_str})")
  end

  defp format_node({:method_call, [obj, method, args]}, indent) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    line(indent, "#{format_atom(obj)}.#{format_atom(method)}(#{args_str})")
  end

  defp format_node({:self_call, [method, args]}, indent) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    line(indent, "SELF.#{format_atom(method)}(#{args_str})")
  end

  defp format_node({:self_assign, [prop, expr]}, indent) do
    line(indent, "SELF.#{format_atom(prop)} = #{format_expr(expr)}")
  end

  defp format_node({:parent_call, [method, args]}, indent) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    line(indent, "PARENT.#{format_atom(method)}(#{args_str})")
  end

  defp format_node({:prop_assign, [file, prop, expr]}, indent) do
    line(indent, "#{format_expr(file)}{PROP:#{format_atom(prop)}} = #{format_expr(expr)}")
  end

  defp format_node({:return, [expr]}, indent) do
    line(indent, "RETURN #{format_expr(expr)}")
  end

  defp format_node(:return, indent), do: line(indent, "RETURN")
  defp format_node(:break, indent), do: line(indent, "BREAK")
  defp format_node(:cycle, indent), do: line(indent, "CYCLE")
  defp format_node(:exit, indent), do: line(indent, "EXIT")
  defp format_node(:display, indent), do: line(indent, "DISPLAY")

  defp format_node({:do, [name]}, indent) do
    line(indent, "DO #{format_atom(name)}")
  end

  # Param
  defp format_node({:param, [name, type]}, indent) do
    line(indent, "#{format_type(type)} #{format_atom(name)}")
  end

  defp format_node({:param, [name, type, :optional]}, indent) do
    line(indent, "<#{format_type(type)} #{format_atom(name)}>")
  end

  # Method/property members
  defp format_node({:method, [name, params, ret_type, attrs]}, indent) do
    attr_str = if attrs == [], do: "", else: " [#{format_list_inline(attrs)}]"
    line(indent, "#{format_atom(name)} PROCEDURE(#{format_params(params)}) -> #{format_atom(ret_type)}#{attr_str}")
  end

  defp format_node({:property, [name, type, size]}, indent) do
    size_str = case size do
      :none -> ""
      {:size, [s]} -> "(#{s})"
      {:size, [s, p]} -> "(#{s},#{p})"
      _ -> ""
    end
    line(indent, "#{format_atom(name)} #{format_atom(type)}#{size_str}")
  end

  # Control declarations
  defp format_node({:button, [text, attrs, use_ref]}, indent) do
    line(indent, "BUTTON('#{format_atom(text)}') USE(#{format_expr(use_ref)}) #{format_list_inline(attrs)}")
  end

  defp format_node({:entry, [format, attrs, use_var]}, indent) do
    line(indent, "ENTRY(#{format_atom(format)}) USE(#{format_expr(use_var)}) #{format_list_inline(attrs)}")
  end

  defp format_node({:prompt, [text, attrs]}, indent) do
    line(indent, "PROMPT('#{format_atom(text)}') #{format_list_inline(attrs)}")
  end

  defp format_node({:check, [text, attrs, use_var]}, indent) do
    line(indent, "CHECK('#{format_atom(text)}') USE(#{format_expr(use_var)}) #{format_list_inline(attrs)}")
  end

  defp format_node({:string_ctl, [text, attrs, use_var]}, indent) do
    line(indent, "STRING('#{text}') USE(#{format_expr(use_var)}) #{format_list_inline(attrs)}")
  end

  defp format_node({:list_ctl, [attrs, use_ref, drop, items]}, indent) do
    line(indent, "LIST USE(#{format_expr(use_ref)}) DROP(#{drop}) #{format_list_inline(attrs)} FROM(#{inspect(items)})")
  end

  # Catch-all for atoms (bare statements like break, return, etc.)
  defp format_node(atom, indent) when is_atom(atom) do
    line(indent, Atom.to_string(atom) |> String.upcase())
  end

  # Catch-all for unrecognized compound terms
  defp format_node({functor, args}, indent) when is_atom(functor) and is_list(args) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    line(indent, "#{functor}(#{args_str})")
  end

  defp format_node(other, indent) do
    line(indent, inspect(other))
  end

  # --- Expression formatting ---

  def format_expr({:lit, [val]}), do: inspect(val)
  def format_expr({:number, [val]}), do: "#{val}"
  def format_expr({:var, [name]}), do: format_atom(name)
  def format_expr({:var, name}) when is_atom(name), do: Atom.to_string(name)
  def format_expr({:array_ref, [name, index]}), do: "#{format_atom(name)}[#{format_expr(index)}]"
  def format_expr({:equate, [name]}), do: "?#{format_atom(name)}"

  def format_expr({:add, [a, b]}), do: "(#{format_expr(a)} + #{format_expr(b)})"
  def format_expr({:sub, [a, b]}), do: "(#{format_expr(a)} - #{format_expr(b)})"
  def format_expr({:mul, [a, b]}), do: "(#{format_expr(a)} * #{format_expr(b)})"
  def format_expr({:div, [a, b]}), do: "(#{format_expr(a)} / #{format_expr(b)})"
  def format_expr({:modulo, [a, b]}), do: "(#{format_expr(a)} % #{format_expr(b)})"
  def format_expr({:concat, [a, b]}), do: "(#{format_expr(a)} & #{format_expr(b)})"
  def format_expr({:eq, [a, b]}), do: "(#{format_expr(a)} = #{format_expr(b)})"
  def format_expr({:neq, [a, b]}), do: "(#{format_expr(a)} <> #{format_expr(b)})"
  def format_expr({:lt, [a, b]}), do: "(#{format_expr(a)} < #{format_expr(b)})"
  def format_expr({:lte, [a, b]}), do: "(#{format_expr(a)} <= #{format_expr(b)})"
  def format_expr({:gt, [a, b]}), do: "(#{format_expr(a)} > #{format_expr(b)})"
  def format_expr({:gte, [a, b]}), do: "(#{format_expr(a)} >= #{format_expr(b)})"
  def format_expr({:and, [a, b]}), do: "(#{format_expr(a)} AND #{format_expr(b)})"
  def format_expr({:or, [a, b]}), do: "(#{format_expr(a)} OR #{format_expr(b)})"
  def format_expr({:not, [e]}), do: "NOT #{format_expr(e)}"

  def format_expr({:call, [name, args]}) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    "#{format_atom(name)}(#{args_str})"
  end

  def format_expr({:method_call, [obj, method, args]}) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    "#{format_atom(obj)}.#{format_atom(method)}(#{args_str})"
  end

  def format_expr({:self_access, [prop]}), do: "SELF.#{format_atom(prop)}"
  def format_expr({:self_call, [method, args]}) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    "SELF.#{format_atom(method)}(#{args_str})"
  end

  def format_expr({:parent_call, [method, args]}) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    "PARENT.#{format_atom(method)}(#{args_str})"
  end

  def format_expr({:prop_access, [file, prop]}), do: "#{format_expr(file)}{PROP:#{format_atom(prop)}}"
  def format_expr({:single, [val]}), do: format_expr(val)
  def format_expr({:range, [s, e]}), do: "#{format_expr(s)} TO #{format_expr(e)}"
  def format_expr(:omitted), do: "_"

  def format_expr(atom) when is_atom(atom), do: Atom.to_string(atom)
  def format_expr(num) when is_number(num), do: "#{num}"
  def format_expr(list) when is_list(list), do: "[#{Enum.map(list, &format_expr/1) |> Enum.join(", ")}]"
  def format_expr({functor, args}) when is_atom(functor) and is_list(args) do
    args_str = args |> Enum.map(&format_expr/1) |> Enum.join(", ")
    "#{functor}(#{args_str})"
  end
  def format_expr(other), do: inspect(other)

  # --- Helpers ---

  defp format_section(_indent, _label, []), do: ""
  defp format_section(indent, label, items) when is_list(items) do
    header = line(indent, "#{label}:")
    children = items |> Enum.map(&format_node(&1, indent + 1)) |> Enum.join("\n")
    "#{header}\n#{children}"
  end
  defp format_section(indent, label, item) do
    line(indent, "#{label}: #{format_expr(item)}")
  end

  defp format_atom(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp format_atom({:ref, [type]}), do: "*#{format_type(type)}"
  defp format_atom(other), do: format_expr(other)

  defp format_type({:cstring, [size]}), do: "CSTRING(#{size})"
  defp format_type({:pstring, [size]}), do: "PSTRING(#{size})"
  defp format_type({:string, [size]}), do: "STRING(#{size})"
  defp format_type({:decimal, [size, prec]}), do: "DECIMAL(#{size},#{prec})"
  defp format_type({:decimal, [size]}), do: "DECIMAL(#{size})"
  defp format_type({:ref, [type]}), do: "*#{format_type(type)}"
  defp format_type(atom) when is_atom(atom), do: Atom.to_string(atom) |> String.upcase()
  defp format_type(other), do: format_expr(other)

  defp format_params(params) when is_list(params) do
    params |> Enum.map(&format_param/1) |> Enum.join(", ")
  end
  defp format_params(_), do: ""

  defp format_param({:param, [name, type]}), do: "#{format_type(type)} #{format_atom(name)}"
  defp format_param({:param, [name, type, :optional]}), do: "<#{format_type(type)} #{format_atom(name)}>"
  defp format_param(other), do: format_expr(other)

  defp format_list_inline(items) when is_list(items) do
    items |> Enum.map(&format_expr/1) |> Enum.join(", ")
  end
  defp format_list_inline(_), do: ""

  defp line(indent, text) do
    prefix = String.duplicate("  ", indent)
    "#{prefix}#{text}"
  end
end
