# ForgeLab

Hands on lab for Forge Framework.

## Installation

Required environements:
  1. Erlang/OTP 22
  2. Elixir 1.9
  3. forge-cli 1.0.2 or higher
  
## Usage

### Create a Chain
`
  forge chain:create --defaults
  cp ./resources/forge_release.toml ~/.forge_chains/forge_my-chain/
  forge chain:start
`

### Connect Sdk to the chain

`
  mix deps.get
  mix compile
  iex -S mix
  ForgeLab.connect()
`

