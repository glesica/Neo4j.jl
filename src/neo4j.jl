# Basic Neo4j database driver that uses the HTTP Cypher API.

import Requests: get, post, delete, json

export Connection, Result

const PATH = "/db/data/"
const PORT = 7474

# -----------
# Connection
# -----------

immutable Connection
  tls::Bool
  host::AbstractString
  port::Int
  path::AbstractString
  user::AbstractString
  password::AbstractString
end

Connection(host; port=PORT, path=PATH, tls=false, user="", password="") =
    Connection(tls, host, port, path, user, password)

function connurl(c::Connection)
  proto = ifelse(c.tls, "https", "http")
  "$(proto)://$(c.host):$(c.port)$(c.path)"
end

function connurl(c::Connection, suffix::AbstractString)
  url = connurl(c)
  "$(url)$(suffix)"
end

function connheaders(c::Connection)
  headers = Dict(
    "Accept" => "application/json; charset=UTF-8",
    "Host" => "$(c.host):$(c.port)")
  if c.user != "" && c.password != ""
    payload = "$(c.user):$(c.password)" |> base64encode
    headers["Authorization"] = "Basic $(payload)"
  end
  headers
end

# ----------
# Statements
# ----------

immutable Statement
  statement::AbstractString
  parameters::Dict
end

# -------
# Results
# -------

immutable Result
  results::Vector
  errors::Vector
end

# ------------
# Transactions
# ------------

include("transaction.jl")

