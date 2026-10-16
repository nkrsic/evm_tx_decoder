# How the app runs

Elixir apps don't have a `main()` function. The entry point is a line in [mix.exs](mix.exs), and from there the OTP runtime starts and supervises everything.

## The entry point: `mod:` in mix.exs

```elixir
def application do
  [
    extra_applications: [:logger],
    mod: {EvmTxDecoder.Application, []}
  ]
end
```

`mod:` tells the runtime: "when this application starts, call `EvmTxDecoder.Application.start/2`." That's the entry point.

## Startup sequence

When you run `iex -S mix` or `mix run --no-halt`:

1. **Compile-time config**: [config/config.exs](config/config.exs) sets `poll_interval_ms: 30_000`.
2. **Runtime config**: [config/runtime.exs](config/runtime.exs) runs at boot. It loads `.env` with Dotenvy and sets `:ethereumex, url:` from `MONAD_RPC_URL`.
3. **Dependencies start first**: `:logger`, `:ethers` and `:ethereumex` are started before this app. Ethereumex reads the URL from step 2.
4. **The app starts**: `start/2` in [application.ex](lib/evm_tx_decoder/application.ex) builds a list of child processes and starts a **Supervisor**. Its only child is `EvmTxDecoder.Poller`.
5. **The Supervisor starts the Poller** by calling `Poller.start_link(interval_ms: 30000)`, which spawns a GenServer process.

## What actually runs the fetch: the Poller

[poller.ex](lib/evm_tx_decoder/poller.ex) is a GenServer, a long-lived process with its own state and mailbox:

```
init/1 ──send(self(), :poll)──► mailbox
                                   │
                                   ▼
                     handle_info(:poll, state)
                       ├─ poll_chain() → EvmTxDecoder.fetch_tx(hash)
                       ├─ Logger.info / Logger.warning
                       └─ Process.send_after(self(), :poll, 30_000) ──┐
                                   ▲                                  │
                                   └──────────── 30s later ───────────┘
```

- `init/1` sends itself a `:poll` message right away. This keeps `init` fast, so the supervisor isn't blocked waiting on a network call.
- `handle_info(:poll, ...)` does the work, then schedules the next `:poll` 30 seconds later. That's the loop. There's no `while` anywhere; the loop comes from the process messaging itself.
- `poll_chain/0` calls `EvmTxDecoder.fetch_tx/1` in [evm_tx_decoder.ex](lib/evm_tx_decoder.ex) with a hardcoded hash. That calls `Ethers.get_transaction/1`, which uses Ethereumex's HTTP client to make a JSON-RPC call to `MONAD_RPC_URL`.

If the Poller crashes (for example, from an unexpected exception), the Supervisor restarts it under the `:one_for_one` strategy, and `init` kicks off polling again.

## Module roles

| Module | Role |
|---|---|
| `EvmTxDecoder.Application` | OTP entry point that starts the supervision tree |
| `EvmTxDecoder.Poller` | The worker process that runs the timed fetch loop |
| `EvmTxDecoder` | Plain functions (`fetch_tx`, `decode_tx`) with no process of their own |
| `EvmTxDecoder.Transaction` | A struct, not used anywhere yet |

## Things to watch out for

- **`mix run` alone exits immediately.** It starts the app and then halts. Use `mix run --no-halt` or `iex -S mix` to keep the poller running.
- **`mix test` also starts the app.** The Poller will make real RPC calls during tests, and `runtime.exs` will fail if `MONAD_RPC_URL` isn't set.
- **The existing test is broken.** [test/evm_tx_decoder_test.exs](test/evm_tx_decoder_test.exs) calls `EvmTxDecoder.hello()`, which no longer exists.
