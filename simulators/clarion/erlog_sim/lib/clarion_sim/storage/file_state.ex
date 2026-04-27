defmodule ClarionSim.Storage.FileState do
  @moduledoc """
  File state struct — mirrors the Prolog file_state/8 tuple:
    file_state(Name, Prefix, Keys, Fields, Records, Buffer, Position, IsOpen)
  """

  defstruct name: nil,
            prefix: nil,
            keys: [],
            fields: [],
            records: [],
            buffer: [],
            position: -1,
            is_open: false

  @type t :: %__MODULE__{
          name: atom(),
          prefix: atom() | nil,
          keys: [key()],
          fields: [field()],
          records: [buffer()],
          buffer: buffer(),
          position: integer(),
          is_open: boolean()
        }

  @type key :: {atom(), [atom()]}
  @type field :: {:field, atom(), atom(), term()}
  @type buffer :: [term()]

  @doc "Create a file state with default buffer from field definitions."
  def new(name, prefix, keys, fields) do
    buffer = create_default_buffer(fields)

    %__MODULE__{
      name: name,
      prefix: prefix,
      keys: keys,
      fields: fields,
      buffer: buffer
    }
  end

  @doc "Get a field value from the current buffer by field name."
  def get_buffer_field(%__MODULE__{fields: fields, buffer: buffer}, field_name) do
    case field_index(fields, field_name) do
      {:ok, idx} -> {:ok, Enum.at(buffer, idx)}
      :error -> :error
    end
  end

  @doc "Set a field value in the current buffer by field name."
  def set_buffer_field(%__MODULE__{fields: fields, buffer: buffer} = fs, field_name, value) do
    case field_index(fields, field_name) do
      {:ok, idx} -> %{fs | buffer: List.replace_at(buffer, idx, value)}
      :error -> fs
    end
  end

  @doc "Create a default buffer with type-appropriate zero values."
  def create_default_buffer(fields) do
    Enum.map(fields, fn {:field, _name, type, _size} ->
      ClarionSim.State.default_value(type)
    end)
  end

  @doc "Clear buffer to defaults."
  def clear_buffer(%__MODULE__{fields: fields} = fs) do
    %{fs | buffer: create_default_buffer(fields)}
  end

  defp field_index(fields, name) do
    case Enum.find_index(fields, fn {:field, n, _, _} -> n == name end) do
      nil -> :error
      idx -> {:ok, idx}
    end
  end
end
