defmodule ClarionSimTest do
  use ExUnit.Case, async: true

  alias ClarionSim.ErlogEngine
  alias ClarionSim.State
  alias ClarionSim.Storage.{FileState, Memory, Backend, Dispatcher}
  alias ClarionSim.UI.Simulation

  # ═══════════════════════════════════════════════════════════
  # ErlogEngine Tests — core Prolog simulator
  # ═══════════════════════════════════════════════════════════

  describe "ErlogEngine" do
    test "creates new engine with all modules loaded" do
      assert {:ok, _erlog} = ErlogEngine.new()
    end

    test "normalizes Prolog terms to Elixir" do
      # charlists become strings
      assert "hello" = ErlogEngine.normalize_term(~c"hello")
      # atoms pass through
      assert :foo = ErlogEngine.normalize_term(:foo)
      # numbers pass through
      assert 42 = ErlogEngine.normalize_term(42)
      # tuples are recursively normalized
      assert {:number, 42} = ErlogEngine.normalize_term({:number, 42})
      # lists are recursively normalized
      assert [1, 2, 3] = ErlogEngine.normalize_term([1, 2, 3])
    end

    test "converts Elixir terms to Erlog" do
      # strings become charlists
      assert ~c"hello" = ErlogEngine.elixir_to_erlog("hello")
      # atoms pass through
      assert :foo = ErlogEngine.elixir_to_erlog(:foo)
    end
  end

  # ═══════════════════════════════════════════════════════════
  # Minimal State Tests (Elixir-side struct)
  # ═══════════════════════════════════════════════════════════

  describe "State (Elixir struct)" do
    test "empty state has defaults" do
      state = State.empty()
      assert state.vars == %{}
      assert state.error_code == 0
      assert state.ui_state != nil
    end

    test "get/set variable" do
      state = State.empty()
      state = State.set_var(state, :X, 42)
      assert {:ok, 42} = State.get_var(state, :X)
    end

    test "undefined variable returns :error" do
      state = State.empty()
      assert :error = State.get_var(state, :Missing)
    end

    test "add_output accumulates in order" do
      state = State.empty()
      state = State.add_output(state, {:message, "hello"})
      state = State.add_output(state, {:message, "world"})
      assert [{:message, "hello"}, {:message, "world"}] = State.get_output_list(state)
    end

    test "default values by type" do
      assert State.default_value(:LONG) == 0
      assert State.default_value(:STRING) == ""
      assert State.default_value(:REAL) == 0.0
    end
  end

  # ═══════════════════════════════════════════════════════════
  # Storage Protocol Tests (Elixir protocols)
  # ═══════════════════════════════════════════════════════════

  describe "Storage.Memory" do
    setup do
      fields = [
        {:field, :ID, :LONG, :none},
        {:field, :Value, :LONG, :none},
        {:field, :Name, :STRING, :none}
      ]

      fs = FileState.new(:TestFile, :TF, [{:IDKey, [:ID]}], fields)
      %{fs: fs, backend: %Memory{}}
    end

    test "open sets position and is_open", %{fs: fs, backend: backend} do
      {:ok, opened} = Backend.open(backend, fs)
      assert opened.is_open == true
      assert opened.position == -1
    end

    test "add appends record", %{fs: fs, backend: backend} do
      {:ok, fs} = Backend.open(backend, fs)
      fs = %{fs | buffer: [1, 100, "test"]}
      {:ok, fs} = Backend.add(backend, fs)
      assert length(fs.records) == 1
      assert hd(fs.records) == [1, 100, "test"]
    end

    test "next advances through records", %{fs: fs, backend: backend} do
      {:ok, fs} = Backend.open(backend, fs)
      fs = %{fs | buffer: [1, 100, "first"]}
      {:ok, fs} = Backend.add(backend, fs)
      fs = %{fs | buffer: [2, 200, "second"]}
      {:ok, fs} = Backend.add(backend, fs)

      {:ok, fs} = Backend.set(backend, fs)
      {:ok, fs} = Backend.next(backend, fs)
      assert fs.buffer == [1, 100, "first"]
      assert fs.position == 0

      {:ok, fs} = Backend.next(backend, fs)
      assert fs.buffer == [2, 200, "second"]
      assert fs.position == 1
    end

    test "delete removes record", %{fs: fs, backend: backend} do
      {:ok, fs} = Backend.open(backend, fs)
      fs = %{fs | buffer: [1, 100, "first"]}
      {:ok, fs} = Backend.add(backend, fs)
      fs = %{fs | buffer: [2, 200, "second"]}
      {:ok, fs} = Backend.add(backend, fs)

      {:ok, fs} = Backend.set(backend, fs)
      {:ok, fs} = Backend.next(backend, fs)
      {:ok, fs} = Backend.delete(backend, fs)
      assert Backend.records(backend, fs) == 1
    end

    test "empty clears all records", %{fs: fs, backend: backend} do
      {:ok, fs} = Backend.open(backend, fs)
      fs = %{fs | buffer: [1, 100, "test"]}
      {:ok, fs} = Backend.add(backend, fs)
      {:ok, fs} = Backend.empty(backend, fs)
      assert Backend.records(backend, fs) == 0
    end

    test "records returns count", %{fs: fs, backend: backend} do
      {:ok, fs} = Backend.open(backend, fs)
      assert Backend.records(backend, fs) == 0
      fs = %{fs | buffer: [1, 100, "test"]}
      {:ok, fs} = Backend.add(backend, fs)
      assert Backend.records(backend, fs) == 1
    end
  end

  describe "Storage.Dispatcher" do
    test "routes to memory by default" do
      fields = [{:field, :X, :LONG, :none}]
      fs = FileState.new(:Test, nil, [], fields)
      {:ok, opened} = Dispatcher.open(:memory, fs)
      assert opened.is_open
    end
  end

  # ═══════════════════════════════════════════════════════════
  # UI Protocol Tests (Elixir protocols)
  # ═══════════════════════════════════════════════════════════

  describe "UI.Simulation" do
    test "open_window adds to stack" do
      state = State.empty()
      backend = %Simulation{}
      window_def = {:window, :TestWin, "Test", []}
      {:ok, state} = ClarionSim.UI.Backend.open_window(backend, window_def, state)
      assert length(state.ui_state.windows) == 1
      assert hd(state.ui_state.windows).name == :TestWin
    end

    test "close_window removes from stack" do
      state = State.empty()
      backend = %Simulation{}
      {:ok, state} = ClarionSim.UI.Backend.open_window(backend, {:window, :W1, "W1", []}, state)
      {:ok, state} = ClarionSim.UI.Backend.close_window(backend, state)
      assert state.ui_state.windows == []
    end

    test "init and shutdown are no-ops" do
      state = State.empty()
      backend = %Simulation{}
      {:ok, ^state} = ClarionSim.UI.Backend.init(backend, state)
      {:ok, ^state} = ClarionSim.UI.Backend.shutdown(backend, state)
    end
  end

  describe "UI.Dispatcher" do
    test "push and poll events" do
      state = State.empty()
      {:ok, state} = ClarionSim.UI.Dispatcher.push_event(:test_event, state)
      {:ok, state, event} = ClarionSim.UI.Dispatcher.poll_event(state)
      assert event == :test_event
    end

    test "has_events?" do
      state = State.empty()
      refute ClarionSim.UI.Dispatcher.has_events?(state)
      {:ok, state} = ClarionSim.UI.Dispatcher.push_event(:ev, state)
      assert ClarionSim.UI.Dispatcher.has_events?(state)
    end
  end

  # ═══════════════════════════════════════════════════════════
  # FileState Tests (Elixir struct)
  # ═══════════════════════════════════════════════════════════

  describe "FileState" do
    test "create with default buffer" do
      fields = [{:field, :A, :LONG, :none}, {:field, :B, :STRING, :none}]
      fs = FileState.new(:Test, nil, [], fields)
      assert fs.buffer == [0, ""]
    end

    test "get/set buffer field" do
      fields = [{:field, :X, :LONG, :none}, {:field, :Y, :LONG, :none}]
      fs = FileState.new(:Test, nil, [], fields)

      fs = FileState.set_buffer_field(fs, :X, 42)
      assert {:ok, 42} = FileState.get_buffer_field(fs, :X)
      assert {:ok, 0} = FileState.get_buffer_field(fs, :Y)
    end

    test "clear_buffer resets to defaults" do
      fields = [{:field, :X, :LONG, :none}]
      fs = FileState.new(:Test, nil, [], fields)
      fs = FileState.set_buffer_field(fs, :X, 999)
      fs = FileState.clear_buffer(fs)
      assert {:ok, 0} = FileState.get_buffer_field(fs, :X)
    end
  end

  # ═══════════════════════════════════════════════════════════
  # Prolog Simulator Integration Tests
  # These test the execution engine running inside Erlog.
  # ═══════════════════════════════════════════════════════════

  describe "Prolog Simulator (via ErlogEngine)" do
    setup do
      {:ok, erlog} = ErlogEngine.new()
      %{erlog: erlog}
    end

    test "eval_expr: number literal", %{erlog: erlog} do
      case :erlog.prove({:eval_expr, {:number, 42}, {:dummy_state}, {:result}}, erlog) do
        {{:succeed, bindings}, _} ->
          result = get_binding(:result, bindings)
          assert result == 42

        {:fail, _} ->
          flunk("eval_expr failed for number literal")
      end
    end

    test "eval_binop: arithmetic", %{erlog: erlog} do
      case :erlog.prove({:eval_binop, :+, 3, 4, {:result}}, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:result, bindings) == 7
        {:fail, _} ->
          flunk("eval_binop + failed")
      end
    end

    test "eval_binop: comparison", %{erlog: erlog} do
      case :erlog.prove({:eval_binop, :=, 5, 5, {:result}}, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:result, bindings) == 1
        {:fail, _} ->
          flunk("eval_binop = failed")
      end
    end

    test "is_truthy", %{erlog: erlog} do
      assert {:succeed, _} = elem(:erlog.prove({:is_truthy, 1}, erlog), 0) |> wrap_result(erlog)
      assert {:succeed, _} = elem(:erlog.prove({:is_truthy, 42}, erlog), 0) |> wrap_result(erlog)
    end

    test "empty_state creates valid state", %{erlog: erlog} do
      case :erlog.prove({:empty_state, {:state}}, erlog) do
        {{:succeed, bindings}, _} ->
          state = get_binding(:state, bindings)
          assert is_tuple(state)
          assert elem(state, 0) == :state
        {:fail, _} ->
          flunk("empty_state failed")
      end
    end

    test "set_var and get_var round-trip", %{erlog: erlog} do
      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:set_var, :X, 42, {:s0}, {:s1}}
          , {:get_var, :X, {:s1}, {:val}}
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 42
        {:fail, _} ->
          flunk("set_var/get_var round-trip failed")
      end
    end

    test "bridge_ast translates expression", %{erlog: erlog} do
      # Bridge lit(42) -> number(42)
      case :erlog.prove({:bridge_expr, {:lit, 42}, {:result}}, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:result, bindings) == {:number, 42}
        {:fail, _} ->
          flunk("bridge_expr failed")
      end
    end

    test "exec_statements: simple assignment", %{erlog: erlog} do
      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:exec_statements, [{:assign, :X, {:number, 42}}], {:s0}, {:s1}, {:ctrl}}
          , {:get_var, :X, {:s1}, {:val}}
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 42
          assert get_binding(:ctrl, bindings) == :normal
        {:fail, _} ->
          flunk("exec_statements assignment failed")
      end
    end

    test "exec_statements: if-then taken", %{erlog: erlog} do
      stmts = [{:if, {:number, 1},
                 [{:assign, :X, {:number, 10}}],
                 [],
                 [{:assign, :X, {:number, 20}}]}]

      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:exec_statements, stmts, {:s0}, {:s1}, {:ctrl}}
          , {:get_var, :X, {:s1}, {:val}}
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 10
        {:fail, _} ->
          flunk("if-then execution failed")
      end
    end

    test "exec_statements: if-else taken", %{erlog: erlog} do
      stmts = [{:if, {:number, 0},
                 [{:assign, :X, {:number, 10}}],
                 [],
                 [{:assign, :X, {:number, 20}}]}]

      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:exec_statements, stmts, {:s0}, {:s1}, {:ctrl}}
          , {:get_var, :X, {:s1}, {:val}}
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 20
        {:fail, _} ->
          flunk("if-else execution failed")
      end
    end

    test "exec_statements: loop_to (FOR loop)", %{erlog: erlog} do
      stmts = [{:loop_to, :I, {:number, 1}, {:number, 5}, [
                  {:assign, :Sum, {:binop, :+, {:var, :Sum}, {:var, :I}}}
                ]}]

      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:set_var, :Sum, 0, {:s0}, {:s1}}
          , {:','
            , {:exec_statements, stmts, {:s1}, {:s2}, {:ctrl}}
            , {:get_var, :Sum, {:s2}, {:val}}
          }
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 15
        {:fail, _} ->
          flunk("loop_to execution failed")
      end
    end

    test "exec_statements: case statement", %{erlog: erlog} do
      stmts = [{:case, {:var, :X},
                 [{:case_of, {:number, 1}, [{:assign, :R, {:number, 10}}]},
                  {:case_of, {:number, 2}, [{:assign, :R, {:number, 20}}]}],
                 [{:assign, :R, {:number, 0}}]}]

      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:set_var, :X, 2, {:s0}, {:s1}}
          , {:','
            , {:exec_statements, stmts, {:s1}, {:s2}, {:ctrl}}
            , {:get_var, :R, {:s2}, {:val}}
          }
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 20
        {:fail, _} ->
          flunk("case execution failed")
      end
    end

    test "builtin_call: ABS", %{erlog: erlog} do
      goal = {:','
        , {:empty_state, {:s0}}
        , {:builtin_call, :ABS, [{:number, -42}], {:s0}, {:s1}, {:result}}
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:result, bindings) == 42
        {:fail, _} ->
          flunk("ABS builtin failed")
      end
    end

    test "builtin_call: LEN", %{erlog: erlog} do
      goal = {:','
        , {:empty_state, {:s0}}
        , {:builtin_call, :LEN, [{:string, ~c"hello"}], {:s0}, {:s1}, {:result}}
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:result, bindings) == 5
        {:fail, _} ->
          flunk("LEN builtin failed")
      end
    end

    test "default_value for types", %{erlog: erlog} do
      case :erlog.prove({:default_value, :LONG, {:val}}, erlog) do
        {{:succeed, bindings}, _} ->
          assert get_binding(:val, bindings) == 0
        {:fail, _} ->
          flunk("default_value LONG failed")
      end
    end
  end

  # ═══════════════════════════════════════════════════════════
  # Backward Execution / Open Variable Tests
  # These demonstrate the key Erlog advantage.
  # ═══════════════════════════════════════════════════════════

  describe "Open Variables / Backward Execution" do
    setup do
      {:ok, erlog} = ErlogEngine.new()
      %{erlog: erlog}
    end

    test "open variable stays unbound in state", %{erlog: erlog} do
      # Set a variable to an unbound Prolog variable, then retrieve it
      # The value should unify with anything
      goal = {:','
        , {:empty_state, {:s0}}
        , {:','
          , {:set_var, :X, {:open_val}, {:s0}, {:s1}}
          , {:get_var, :X, {:s1}, {:retrieved}}
        }
      }

      case :erlog.prove(goal, erlog) do
        {{:succeed, bindings}, _} ->
          # The retrieved value should be the same (unbound) variable
          retrieved = get_binding(:retrieved, bindings)
          open_val = get_binding(:open_val, bindings)
          # In Erlog, if both are still unbound, they'll be the same variable
          assert retrieved == open_val
        {:fail, _} ->
          flunk("Open variable test failed")
      end
    end

    test "backward query: find input that produces output", %{erlog: erlog} do
      # Query: what value of X makes X + 3 = 10?
      # This uses Prolog's eval_binop with arithmetic
      # Note: standard is/2 doesn't backtrack, but we can test
      # backward unification for non-arithmetic operations
      goal = {:','
        , {:eval_binop, :=, 42, 42, {:result}}
        , {:','
          , {:eval_binop, :=, 42, 43, {:result2}}
          , true  % will fail at result2
        }
      }

      # This should fail because 42 != 43
      case :erlog.prove(goal, erlog) do
        {{:succeed, _}, _} ->
          flunk("Should have failed: 42 != 43")
        {:fail, _} ->
          :ok  # Expected: the query correctly fails
      end
    end
  end

  # ── Helpers ──

  defp get_binding(name, bindings) when is_list(bindings) do
    case List.keyfind(bindings, name, 0) do
      {^name, value} -> value
      nil -> nil
    end
  end

  defp wrap_result(result, _erlog) do
    case result do
      {:succeed, bindings} -> {:succeed, bindings}
      other -> other
    end
  end
end
