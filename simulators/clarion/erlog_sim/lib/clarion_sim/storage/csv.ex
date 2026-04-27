defmodule ClarionSim.Storage.Csv do
  @moduledoc """
  CSV file-backed storage backend — replaces Logtalk storage_csv object.
  Reads/writes records as CSV files on disk.
  """

  defstruct []

  alias ClarionSim.Storage.{Backend, FileState}

  defimpl Backend do
    def open(_backend, %FileState{} = fs) do
      {:ok, %{fs | position: -1, is_open: true}}
    end

    def open(_backend, filename, %FileState{fields: fields} = fs) do
      records =
        case File.read(filename) do
          {:ok, content} ->
            content
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(fn line ->
              values = String.split(line, ",")

              Enum.zip(fields, values)
              |> Enum.map(fn {{:field, _name, type, _size}, val} ->
                parse_csv_value(val, type)
              end)
            end)

          {:error, _} ->
            []
        end

      {:ok, %{fs | records: records, position: -1, is_open: true}}
    end

    def close(_backend, %FileState{} = fs) do
      {:ok, %{fs | is_open: false}}
    end

    def create(_backend, %FileState{} = fs) do
      {:ok, %{fs | records: []}}
    end

    def add(_backend, %FileState{records: records, buffer: buffer} = fs) do
      {:ok, %{fs | records: records ++ [buffer], position: -1}}
    end

    def get(_backend, {:key_search, _key_name, key_fields, search_values}, %FileState{} = fs) do
      case find_record(fs.fields, key_fields, search_values, fs.records) do
        {:ok, record, pos} -> {:ok, %{fs | buffer: record, position: pos}}
        :error -> {:error, :not_found}
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

    def set(_backend, %FileState{} = fs), do: {:ok, %{fs | position: -1}}

    def records(_backend, %FileState{records: records}), do: length(records)

    def empty(_backend, %FileState{} = fs), do: {:ok, %{fs | records: [], position: -1}}

    def clear(_backend, %FileState{} = fs), do: {:ok, FileState.clear_buffer(fs)}

    defp parse_csv_value(val, type) do
      case type do
        t when t in [:LONG, :SHORT, :BYTE, :DECIMAL, :PDECIMAL, :DATE, :TIME] ->
          case Integer.parse(String.trim(val)) do
            {n, _} -> n
            :error -> 0
          end

        t when t in [:REAL, :SREAL] ->
          case Float.parse(String.trim(val)) do
            {f, _} -> f
            :error -> 0.0
          end

        _ ->
          String.trim(val)
      end
    end

    defp find_record(fields, key_fields, search_values, records) do
      records
      |> Enum.with_index()
      |> Enum.find_value(:error, fn {record, idx} ->
        values =
          Enum.map(key_fields, fn kf ->
            case Enum.find_index(fields, fn {:field, n, _, _} -> n == kf end) do
              nil -> nil
              i -> Enum.at(record, i)
            end
          end)

        if values == search_values, do: {:ok, record, idx}
      end)
    end
  end
end
