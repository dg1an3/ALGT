defmodule ClarionSim.UI.Simulation do
  @moduledoc """
  Headless UI backend for testing — replaces Logtalk ui_simulation object.
  Provides in-memory window/control state and event injection.
  """

  defstruct []

  alias ClarionSim.UI.{Backend, Types}
  alias ClarionSim.State

  defimpl Backend do
    def init(_backend, state), do: {:ok, state}
    def shutdown(_backend, state), do: {:ok, state}

    def open_window(_backend, window_def, %State{} = state) do
      window_state = build_window_state(window_def)
      ui = state.ui_state
      new_ui = %{ui | windows: [window_state | ui.windows]}
      {:ok, State.set_ui_state(state, new_ui)}
    end

    def close_window(_backend, %State{} = state) do
      ui = state.ui_state

      case ui.windows do
        [_ | rest] ->
          {:ok, State.set_ui_state(state, %{ui | windows: rest})}

        [] ->
          {:error, :no_window}
      end
    end

    def get_control_value(_backend, control_id, %State{} = state) do
      case find_control_in_top_window(state, control_id) do
        {:ok, control} -> {:ok, control.value}
        :error -> {:error, :control_not_found}
      end
    end

    def set_control_value(_backend, control_id, value, %State{} = state) do
      update_control_in_top_window(state, control_id, fn ctrl ->
        %{ctrl | value: value}
      end)
    end

    def set_control_prop(_backend, control_id, prop, value, %State{} = state) do
      update_control_in_top_window(state, control_id, fn ctrl ->
        %{ctrl | props: Map.put(ctrl.props, prop, value)}
      end)
    end

    def select(_backend, control_id, %State{} = state) do
      ui = state.ui_state

      case ui.windows do
        [top | rest] ->
          new_top = %{top | focus: control_id}
          {:ok, State.set_ui_state(state, %{ui | windows: [new_top | rest]})}

        [] ->
          {:error, :no_window}
      end
    end

    def display(_backend, state), do: {:ok, state}

    # ── Private helpers ──

    defp build_window_state({:window, name, title, controls}) do
      control_states = Enum.map(controls, &build_control_state/1)

      %Types.WindowState{
        name: name,
        title: title,
        controls: control_states,
        focus: nil,
        is_open: true
      }
    end

    defp build_window_state(_) do
      %Types.WindowState{}
    end

    defp build_control_state({:control, type, text, attrs}) do
      id = extract_control_id(attrs)
      binding = extract_control_binding(attrs)

      %Types.ControlState{
        id: id,
        type: type,
        text: text,
        value: "",
        binding: binding,
        props: %{}
      }
    end

    defp build_control_state({type, text}) when type in [:button, :entry, :prompt, :string] do
      %Types.ControlState{type: type, text: text, value: ""}
    end

    defp build_control_state(_), do: %Types.ControlState{}

    defp extract_control_id(attrs) do
      Enum.find_value(attrs, nil, fn
        {:use, {:control_ref, id}} -> id
        _ -> nil
      end)
    end

    defp extract_control_binding(attrs) do
      Enum.find_value(attrs, nil, fn
        {:use, {:var_ref, binding}} -> binding
        _ -> nil
      end)
    end

    defp find_control_in_top_window(%State{ui_state: ui}, control_id) do
      case ui.windows do
        [top | _] ->
          case Enum.find(top.controls, &(&1.id == control_id)) do
            nil -> :error
            ctrl -> {:ok, ctrl}
          end

        [] ->
          :error
      end
    end

    defp update_control_in_top_window(%State{ui_state: ui} = state, control_id, update_fn) do
      case ui.windows do
        [top | rest] ->
          new_controls =
            Enum.map(top.controls, fn ctrl ->
              if ctrl.id == control_id, do: update_fn.(ctrl), else: ctrl
            end)

          new_top = %{top | controls: new_controls}
          {:ok, State.set_ui_state(state, %{ui | windows: [new_top | rest]})}

        [] ->
          {:error, :no_window}
      end
    end
  end
end
