# `config.exs` and `runtime.exs`

Yes — `config/config.exs` and `config/runtime.exs` are special, recognized by name by both Mix and Elixir's `Config` module, and each plays a distinct role in when configuration gets loaded relative to compilation and boot.

## `config/config.exs` — compile-time configuration

This is the main config entry point that Mix automatically loads when you run `mix compile`, `mix test`, etc. It runs **at compile time**, before your application's code is compiled. Its defining characteristic: any value you set here gets baked into the compiled BEAM files via `Application.compile_env/2,3` if you read it that way, or into the application environment (`Application.get_env/2,3`) at compile time otherwise.

```elixir
# config/config.exs
import Config

config :evm_tx_decoder,
  rpc_url: "https://mainnet.example.com",
  chain_id: 1

# You can import environment-specific overrides:
import_config "#{config_env()}.exs"   # e.g. dev.exs, test.exs, prod.exs
```

Because it runs at compile time, anything sensitive or environment-dependent (API keys, database URLs, secrets that differ between your dev machine and production) is a poor fit here — it gets frozen into the build artifact, which is a problem the moment you build a release once and deploy it to multiple environments.

## `config/runtime.exs` — runtime configuration

This file is special-cased by Mix releases (and by `mix run`/`iex -S mix` as of recent Elixir versions) to run **just before your application starts, at runtime**, not compile time. This is the correct place for anything that should be read fresh when the app actually boots — environment variables, secrets, host-specific values:

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :evm_tx_decoder,
    rpc_url: System.fetch_env!("RPC_URL"),
    database_url: System.fetch_env!("DATABASE_URL")
end
```

This matters enormously for Mix releases specifically: a release is compiled once and can be deployed to many machines/environments, so anything environment-specific *must* go through `runtime.exs` (or be read via `System.get_env` inside your supervision tree directly) rather than `config.exs`, since `config.exs` values are locked in at build time and identical across every deployment of that release.

## Where to read the actual docs

**Primary doc: the `Config` module**

The `Config` module is described as a simple keyword-based configuration API, most commonly used to define application configuration in `config/config.exs`. It explains that `import Config` gives you access to `config/2`, `config/3`, `config_env/0`, `config_target/0`, and `import_config/1`, and that once Mix starts, it automatically evaluates the configuration file and persists the values into the application environment, readable via `Application.fetch_env!/2`.

Straight from that same doc, on `runtime.exs` specifically: for runtime configuration, you use the `config/runtime.exs` file, which is executed right before applications start in both Mix and releases assembled with `mix release` — confirming the compile-time vs. runtime split described above.

**Links:**
- [`https://hexdocs.pm/elixir/Config.html`](https://hexdocs.pm/elixir/Config.html) — the `Config` module docs (covers `config.exs`, `import_config/1`, environment-specific files)
- [`https://elixir.hexdocs.pm/main/Config.md`](https://elixir.hexdocs.pm/main/Config.md) — same content, main/dev branch version, includes the `runtime.exs` section explicitly

**A related doc worth reading next**, since it covers the *lifecycle* angle specifically: the [Mix.Release docs](https://hexdocs.pm/mix/Mix.Release.html) and the [Elixir "Releases" guide](https://hexdocs.pm/elixir/releases.html) go into more depth on exactly when `runtime.exs` fires relative to release boot, VM args, and `config_providers` — genuinely useful once you get to packaging an app as a release rather than just running it via `mix run`/`iex -S mix`.

One thing worth flagging from the doc excerpt above too — if you're writing a library for other developers to depend on, it's generally recommended to avoid the application environment, since it's effectively global storage, and a library's own `config/config.exs` is never evaluated when that library is used as a dependency. Not directly relevant if an app is an end application, but worth keeping in mind if any part of it ever gets split into a standalone hex package.
