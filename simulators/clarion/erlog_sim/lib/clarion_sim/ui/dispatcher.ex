defmodule ClarionSim.UI.Dispatcher do
  @moduledoc """
  Routes UI operations to the appropriate backend and manages shared
  event queue operations.

  Replaces the Logtalk ui_dispatcher object.
  """

  alias ClarionSim.UI.{Backend, Simulation}
  alias ClarionSim.State

  @doc "Get the backend struct for the current UI state."
  def backend_for(backend_type) do
    case backend_type do
      :simulation -> %Simulation{}
      _ -> %Simulation{}
    end
  end

  # ── Delegated operations (via protocol) ──

  def init(state) do
    backend = backend_for(state.ui_state.backend)
    Backend.init(backend, state)
  end

  def shutdown(state) do
    backend = backend_for(state.ui_state.backend)
    Backend.shutdown(backend, state)
  end

  def open_window(window_def, state) do
    backend = backend_for(state.ui_state.backend)
    Backend.open_window(backend, window_def, state)
  end

  def close_window(state) do
    backend = backend_for(state.ui_state.backend)
    Backend.close_window(backend, state)
  end

  def get_control_value(control_id, state) do
    backend = backend_for(state.ui_state.backend)
    Backend.get_control_value(backend, control_id, state)
  end

  def set_control_value(control_id, value, state) do
    backend = backend_for(state.ui_state.backend)
    Backend.set_control_value(backend, control_id, value, state)
  end

  def set_control_prop(control_id, prop, value, state) do
    backend = backend_for(state.ui_state.backend)
    Backend.set_control_prop(backend, control_id, prop, value, state)
  end

  def select(control_id, state) do
    backend = backend_for(state.ui_state.backend)
    Backend.select(backend, control_id, state)
  end

  def display(state) do
    backend = backend_for(state.ui_state.backend)
    Backend.display(backend, state)
  end

  # ── Shared event queue operations (not dispatched) ──

  @doc "Push an event onto the event queue."
  def push_event(event, %State{ui_state: ui} = state) do
    new_ui = %{ui | event_queue: ui.event_queue ++ [event]}
    {:ok, State.set_ui_state(state, new_ui)}
  end

  @doc "Poll the next event from the queue."
  def poll_event(%State{ui_state: ui} = state) do
    case ui.event_queue do
      [event | rest] ->
        new_ui = %{ui | event_queue: rest, current_event: event}
        {:ok, State.set_ui_state(state, new_ui), event}

      [] ->
        {:empty, state}
    end
  end

  @doc "Check if there are pending events."
  def has_events?(%State{ui_state: ui}), do: ui.event_queue != []

  @doc "Get the current event being processed."
  def get_current_event(%State{ui_state: ui}), do: ui.current_event

  @doc "Set the current event."
  def set_current_event(event, %State{ui_state: ui} = state) do
    {:ok, State.set_ui_state(state, %{ui | current_event: event})}
  end

  @doc "Set the execution mode."
  def set_mode(mode, %State{ui_state: ui} = state) do
    {:ok, State.set_ui_state(state, %{ui | mode: mode})}
  end

  @doc "Get the execution mode."
  def get_mode(%State{ui_state: ui}), do: ui.mode
end
