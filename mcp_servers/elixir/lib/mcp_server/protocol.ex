defmodule McpServer.Protocol do
  @moduledoc """
  JSON-RPC 2.0 protocol handling for MCP server.

  Handles reading/writing JSON-RPC messages over stdio with
  Content-Length framing as required by MCP.
  """

  # JSON-RPC 2.0 Error Codes
  @parse_error -32700
  @invalid_request -32600
  @method_not_found -32601
  @invalid_params -32602
  @internal_error -32603

  def parse_error, do: @parse_error
  def invalid_request, do: @invalid_request
  def method_not_found, do: @method_not_found
  def invalid_params, do: @invalid_params
  def internal_error, do: @internal_error

  @doc """
  Read a JSON-RPC message from stdin.
  Messages are framed with Content-Length headers.
  """
  @spec read_message() :: {:ok, map()} | {:error, term()} | :eof
  def read_message do
    case read_headers() do
      :eof ->
        :eof

      {:error, reason} ->
        {:error, reason}

      headers ->
        case Keyword.get(headers, :content_length) do
          nil ->
            {:error, :missing_content_length}

          length ->
            case IO.read(:stdio, length) do
              :eof ->
                :eof

              {:error, reason} ->
                {:error, reason}

              data ->
                case Jason.decode(data) do
                  {:ok, json} -> {:ok, json}
                  {:error, error} -> {:error, {:json_parse_error, error}}
                end
            end
        end
    end
  end

  @doc """
  Read HTTP-style headers until empty line.
  """
  @spec read_headers() :: keyword() | :eof | {:error, term()}
  defp read_headers(acc \\ []) do
    case IO.read(:stdio, :line) do
      :eof ->
        :eof

      {:error, reason} ->
        {:error, reason}

      line ->
        trimmed = String.trim(line)

        case trimmed do
          "" ->
            acc

          _ ->
            case parse_header(trimmed) do
              {:ok, header} -> read_headers([header | acc])
              :ignore -> read_headers(acc)
            end
        end
    end
  end

  @doc """
  Parse a single header line.
  """
  @spec parse_header(String.t()) :: {:ok, {atom(), term()}} | :ignore
  defp parse_header(line) do
    case String.split(String.downcase(line), ":", parts: 2) do
      ["content-length", value] ->
        case Integer.parse(String.trim(value)) do
          {length, ""} -> {:ok, {:content_length, length}}
          _ -> :ignore
        end

      _ ->
        :ignore
    end
  end

  @doc """
  Write a JSON-RPC response to stdout.
  """
  @spec write_response(map()) :: :ok
  def write_response(response) do
    json = Jason.encode!(response)
    length = byte_size(json)
    IO.write(:stdio, "Content-Length: #{length}\r\n\r\n#{json}")
    :ok
  end

  @doc """
  Write a JSON-RPC error response.
  """
  @spec write_error(term(), integer(), String.t()) :: :ok
  def write_error(id, code, message) do
    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }

    write_response(response)
  end

  @doc """
  Write a JSON-RPC notification.
  """
  @spec write_notification(String.t(), map()) :: :ok
  def write_notification(method, params) do
    notification = %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    }

    write_response(notification)
  end

  @doc """
  Create an error response map.
  """
  @spec error_response(term(), integer(), String.t()) :: map()
  def error_response(id, code, message) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => code,
        "message" => message
      }
    }
  end
end
