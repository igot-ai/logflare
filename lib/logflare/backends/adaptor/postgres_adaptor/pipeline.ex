defmodule Logflare.Backends.Adaptor.PostgresAdaptor.Pipeline do
  @moduledoc """
  Pipeline for PostgresAdaptor

  This pipeline is responsible for taking log events from the source backend and inserting them into the configured database.
  """
  use Broadway

  alias Broadway.Message
  alias Logflare.Backends.Adaptor.PostgresAdaptor
  alias Logflare.Buffers.BufferProducer

  @spec start_link(PostgresAdaptor.t()) :: {:ok, pid()}
  def start_link(adaptor_state) do
    Broadway.start_link(__MODULE__,
      name: adaptor_state.pipeline_name,
      producer: [
        module:
          {BufferProducer,
           buffer_module: adaptor_state.buffer_module, buffer_pid: adaptor_state.buffer_pid},
        transformer: {__MODULE__, :transform, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 3, min_demand: 1]
      ],
      context: adaptor_state
    )
  end

  # see the implementation for Backends.via_source_backend/2 for how tuples are used to identify child processes
  def process_name({:via, module, {registry, identifier}}, base_name) do
    new_identifier = Tuple.append(identifier, base_name)
    {:via, module, {registry, new_identifier}}
  end

  def handle_message(_processor_name, message, adaptor_state) do
    Message.update_data(message, &process_data(&1, adaptor_state))
  end

  defp process_data(log_event, %{source_backend: source_backend}) do
    PostgresAdaptor.insert_log_event(source_backend, log_event)
  end

  def transform(event, _opts) do
    %Message{
      data: event,
      acknowledger: {__MODULE__, :ack_id, :ack_data}
    }
  end

  def ack(_ack_ref, _successful, _failed) do
    # TODO: re-queue failed
  end
end
