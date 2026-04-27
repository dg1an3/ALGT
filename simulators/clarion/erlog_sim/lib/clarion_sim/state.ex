defmodule ClarionSim.State do
  @moduledoc """
  Minimal Elixir-side state struct for protocol compatibility.

  During execution, the actual state lives in Prolog/Erlog as a
  compound term (state/9). This module provides a thin struct
  for Elixir Storage/UI protocol implementations.
  """

  alias ClarionSim.UI.Types

  defstruct vars: %{},
            procs: %{},
            output: [],
            files: %{},
            error_code: 0,
            classes: %{},
            self: nil,
            ui_state: nil,
            continuation: nil

  @type t :: %__MODULE__{}

  def empty do
    %__MODULE__{
      ui_state: %Types.UIState{}
    }
  end

  def get_var(%__MODULE__{vars: vars}, name) do
    case Map.fetch(vars, name) do
      {:ok, value} -> {:ok, value}
      :error -> :error
    end
  end

  def set_var(%__MODULE__{vars: vars} = state, name, value) do
    %{state | vars: Map.put(vars, name, value)}
  end

  def add_output(%__MODULE__{output: output} = state, msg) do
    %{state | output: output ++ [msg]}
  end

  def get_output_list(%__MODULE__{output: output}), do: output

  def set_error(%__MODULE__{} = state, code) do
    %{state | error_code: code}
  end

  def set_ui_state(%__MODULE__{} = state, ui_state) do
    %{state | ui_state: ui_state}
  end

  @doc "Default value for a Clarion type."
  def default_value(:LONG), do: 0
  def default_value(:SHORT), do: 0
  def default_value(:BYTE), do: 0
  def default_value(:REAL), do: 0.0
  def default_value(:SREAL), do: 0.0
  def default_value(:STRING), do: ""
  def default_value(:CSTRING), do: ""
  def default_value(:PSTRING), do: ""
  def default_value(:DATE), do: 0
  def default_value(:TIME), do: 0
  def default_value(:DECIMAL), do: 0
  def default_value(:PDECIMAL), do: 0
  def default_value(:void), do: 0
  def default_value(_), do: 0
end
