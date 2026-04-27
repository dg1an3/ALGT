defprotocol ClarionSim.Storage.Backend do
  @moduledoc """
  Storage backend protocol — replaces the Logtalk istorage_backend protocol.

  All operations take a FileState and return an updated FileState.
  Dispatch is based on the storage backend struct type.
  """

  @doc "Open a file for access."
  @spec open(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def open(backend, file_state)

  @doc "Open a file by filename (for file-backed stores)."
  @spec open(t(), String.t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def open(backend, filename, file_state)

  @doc "Close a file."
  @spec close(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def close(backend, file_state)

  @doc "Create a new empty file."
  @spec create(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def create(backend, file_state)

  @doc "Add current buffer as a new record."
  @spec add(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def add(backend, file_state)

  @doc "Search for a record by key."
  @spec get(t(), term(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def get(backend, key_info, file_state)

  @doc "Update the record at current position."
  @spec put(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def put(backend, file_state)

  @doc "Delete the record at current position."
  @spec delete(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def delete(backend, file_state)

  @doc "Advance to the next record."
  @spec next(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def next(backend, file_state)

  @doc "Reset file position to beginning."
  @spec set(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def set(backend, file_state)

  @doc "Get record count."
  @spec records(t(), ClarionSim.Storage.FileState.t()) :: non_neg_integer()
  def records(backend, file_state)

  @doc "Delete all records."
  @spec empty(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def empty(backend, file_state)

  @doc "Clear buffer to default values."
  @spec clear(t(), ClarionSim.Storage.FileState.t()) ::
          {:ok, ClarionSim.Storage.FileState.t()} | {:error, term()}
  def clear(backend, file_state)
end
