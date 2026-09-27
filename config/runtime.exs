import Config
import Dotenvy

source!([
  Path.expand("../.env", __DIR__),
  System.get_env()
])

config :ethereumex,
  url: env!("MONAD_RPC_URL")
