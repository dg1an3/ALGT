defmodule ClarionSim.Storage.Dispatcher do
  @moduledoc """
  Routes storage operations to the appropriate backend based on DRIVER attribute.

  Replaces the Logtalk storage_dispatcher object.
  """

  alias ClarionSim.Storage.{Backend, Memory, Csv, Odbc}

  @doc "Get the backend struct for a given driver atom."
  def backend_for(driver) do
    case driver do
      d when d in [:ODBC, :ADO, :odbc, :ado] -> %Odbc{}
      d when d in [:ASCII, :BASIC, :ascii, :basic] -> %Csv{}
      _ -> %Memory{}
    end
  end

  # Delegate all operations through the protocol

  def open(driver, filename, fs) do
    backend = backend_for(driver)
    Backend.open(backend, filename, fs)
  end

  def open(driver, fs) do
    backend = backend_for(driver)
    Backend.open(backend, fs)
  end

  def close(driver, fs), do: Backend.close(backend_for(driver), fs)
  def create(driver, fs), do: Backend.create(backend_for(driver), fs)
  def add(driver, fs), do: Backend.add(backend_for(driver), fs)
  def get(driver, key_info, fs), do: Backend.get(backend_for(driver), key_info, fs)
  def put(driver, fs), do: Backend.put(backend_for(driver), fs)
  def delete(driver, fs), do: Backend.delete(backend_for(driver), fs)
  def next(driver, fs), do: Backend.next(backend_for(driver), fs)
  def set(driver, fs), do: Backend.set(backend_for(driver), fs)
  def records(driver, fs), do: Backend.records(backend_for(driver), fs)
  def empty(driver, fs), do: Backend.empty(backend_for(driver), fs)
  def clear(driver, fs), do: Backend.clear(backend_for(driver), fs)
end
