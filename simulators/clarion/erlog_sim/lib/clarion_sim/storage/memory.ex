defmodule ClarionSim.Storage.Memory do
  @moduledoc """
  In-memory storage backend — replaces Logtalk storage_memory object.
  Uses list of record buffers stored in FileState.records.
  """

  defstruct []

  alias ClarionSim.Storage.{Backend, FileState}

  defimpl Backend do
    def open(_backend, %FileState{} = fs) do
      {:ok, %{fs | position: -1, is_open: true}}
    end

    def open(_backend, _filename, %FileState{} = fs) do
      {:ok, %{fs | position: -1, is_open: true}}
    end

    def close(_backend, %FileState{} = fs) do
      {:ok, %{fs | is_open: false}}
    end

    def create(_backend, %FileState{} = fs) do
      {:ok, fs}
    end

    def add(_backend, %FileState{records: records, buffer: buffer} = fs) do
      {:ok, %{fs | records: records ++ [buffer], position: -1}}
    end

    def get(_backend, {:key_search, key_name, key_fields, search_values}, %FileState{} = fs) do
      case find_record_by_key(fs.keys, fs.fields, key_fields, search_values, fs.records) do
        {:ok, record, pos} ->
          {:ok, %{fs | buffer: record, position: pos}}

        :error ->
          {:error, :not_found}
      end
    end

    def get(_backend, _key_info, _fs), do: {:error, :invalid_key}

    def put(_backend, %FileState{position: pos, records: records, buffer: buffer} = fs)
        when pos >= 0 and pos < length(records) do
      {:ok, %{fs | records: List.replace_at(records, pos, buffer)}}
    end

    def put(_backend, _fs), do: {:error, :invalid_position}

    def delete(_backend, %FileState{position: pos, records: records} = fs)
        when pos >= 0 and pos < length(records) do
      {:ok, %{fs | records: List.delete_at(records, pos), position: -1}}
    end

    def delete(_backend, _fs), do: {:error, :invalid_position}

    def next(_backend, %FileState{position: pos, records: records} = fs) do
      next_pos = pos + 1

      if next_pos < length(records) do
        {:ok, %{fs | buffer: Enum.at(records, next_pos), position: next_pos}}
      else
        {:error, :end_of_file}
      end
    end

    def set(_backend, %FileState{} = fs) do
      {:ok, %{fs | position: -1}}
    end

    def records(_backend, %FileState{records: records}) do
      length(records)
    end

    def empty(_backend, %FileState{} = fs) do
      {:ok, %{fs | records: [], position: -1}}
    end

    def clear(_backend, %FileState{} = fs) do
      {:ok, FileState.clear_buffer(fs)}
    end

    # ── Private helpers ──

    defp find_record_by_key(keys, fields, key_fields, search_values, records) do
      # Verify the key exists
      _key = Enum.find(keys, fn {_name, kf} -> kf == key_fields end)

      records
      |> Enum.with_index()
      |> Enum.find_value(:error, fn {record, idx} ->
        record_values = get_key_values(key_fields, fields, record)

        if record_values == search_values do
          {:ok, record, idx}
        end
      end)
    end

    defp get_key_values(key_fields, fields, record) do
      Enum.map(key_fields, fn key_field ->
        # Handle prefixed field names (strip prefix)
        field_name =
          case String.split(Atom.to_string(key_field), ":") do
            [_prefix, name] -> String.to_atom(name)
            _ -> key_field
          end

        case Enum.find_index(fields, fn {:field, n, _, _} -> n == field_name end) do
          nil -> nil
          idx -> Enum.at(record, idx)
        end
      end)
    end
  end
end
