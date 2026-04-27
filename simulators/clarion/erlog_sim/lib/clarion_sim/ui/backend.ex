defprotocol ClarionSim.UI.Backend do
  @moduledoc """
  UI backend protocol — replaces the Logtalk iui_backend protocol.

  Operations work on the UI state struct for each backend type.
  """

  @doc "Initialize the UI backend."
  @spec init(t(), ClarionSim.State.t()) :: {:ok, ClarionSim.State.t()}
  def init(backend, state)

  @doc "Shut down the UI backend."
  @spec shutdown(t(), ClarionSim.State.t()) :: {:ok, ClarionSim.State.t()}
  def shutdown(backend, state)

  @doc "Open a window from a definition."
  @spec open_window(t(), term(), ClarionSim.State.t()) ::
          {:ok, ClarionSim.State.t()} | {:error, term()}
  def open_window(backend, window_def, state)

  @doc "Close the top window."
  @spec close_window(t(), ClarionSim.State.t()) ::
          {:ok, ClarionSim.State.t()} | {:error, term()}
  def close_window(backend, state)

  @doc "Get the value of a control by ID."
  @spec get_control_value(t(), atom(), ClarionSim.State.t()) ::
          {:ok, term()} | {:error, term()}
  def get_control_value(backend, control_id, state)

  @doc "Set the value of a control by ID."
  @spec set_control_value(t(), atom(), term(), ClarionSim.State.t()) ::
          {:ok, ClarionSim.State.t()} | {:error, term()}
  def set_control_value(backend, control_id, value, state)

  @doc "Set a property on a control."
  @spec set_control_prop(t(), atom(), atom(), term(), ClarionSim.State.t()) ::
          {:ok, ClarionSim.State.t()} | {:error, term()}
  def set_control_prop(backend, control_id, prop, value, state)

  @doc "Focus a control."
  @spec select(t(), atom(), ClarionSim.State.t()) ::
          {:ok, ClarionSim.State.t()} | {:error, term()}
  def select(backend, control_id, state)

  @doc "Refresh display (no-op for simulation)."
  @spec display(t(), ClarionSim.State.t()) :: {:ok, ClarionSim.State.t()}
  def display(backend, state)
end
