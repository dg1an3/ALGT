defmodule ClarionSim.UI.Types do
  @moduledoc """
  Type definitions for UI state, windows, and controls.
  """

  defmodule ControlState do
    @moduledoc "State of a single UI control."
    defstruct id: nil,
              type: :unknown,
              text: "",
              value: "",
              binding: nil,
              props: %{}

    @type t :: %__MODULE__{
            id: atom() | nil,
            type: atom(),
            text: String.t(),
            value: term(),
            binding: atom() | nil,
            props: map()
          }
  end

  defmodule WindowState do
    @moduledoc "State of a single window."
    defstruct name: :anonymous,
              title: "",
              controls: [],
              focus: nil,
              is_open: true

    @type t :: %__MODULE__{
            name: atom(),
            title: String.t(),
            controls: [ControlState.t()],
            focus: atom() | nil,
            is_open: boolean()
          }
  end

  defmodule UIState do
    @moduledoc "Overall UI state with window stack and event queue."
    defstruct backend: :simulation,
              windows: [],
              event_queue: [],
              current_event: nil,
              mode: :sync

    @type t :: %__MODULE__{
            backend: atom(),
            windows: [WindowState.t()],
            event_queue: [term()],
            current_event: term() | nil,
            mode: :sync | :async
          }
  end

  @type ui_state :: UIState.t()

  def empty_ui_state do
    %UIState{}
  end
end
