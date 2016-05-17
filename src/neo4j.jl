# Basic Neo4j database driver that uses the HTTP Cypher API.

import Requests: get, post, delete, json

export Connection, defaultconn, Statement, Query, start, rollback, execute, commit, submit, cypher

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

Connection(tls::Bool, host, port::Int, path) = Connection(tls, host, port, path, "", "")

Connection(tls::Bool, host, user, pass) = Connection(tls, host, PORT, PATH, user, pass)

Connection(tls::Bool, host) = Connection(tls, host, PORT, PATH, "", "")

const defaultconn = Connection(false, "localhost", PORT, PATH)

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

# ------------------------
# Queries and transactions
# ------------------------

immutable Statement
  statement::AbstractString
  parameters::Dict
end

immutable Query
  statements::Vector{Statement}
end

function cypher(stmt::AbstractString, params::Pair...)
  Statement(stmt, Dict(params))
end

immutable Results
  results::Vector
  errors::Vector
end

Results(raw::Dict) = Results(raw["results"], raw["errors"])

immutable Transaction
  connection::Connection
  commit::AbstractString
  location::AbstractString
  results::Results
end

function start(c::Connection, q::Query)
  resp = post(connurl(c, "transaction");
      headers=connheaders(c),
      json=q)
  if resp.status != 201
    warn("Failed to start transaction: $(resp.status)")
  end
  raw = json(resp)
  Transaction(c, raw["commit"], resp.headers["Location"], Results(raw))
end

start(c::Connection, s::Statement) = start(c, Query([s]))

function start(c::Connection)
  q = Query([])
  start(c, q)
end

function execute(t::Transaction, q::Query)
  resp = post(t.location;
      headers=connheaders(t.connection),
      json=q)
  if resp.status != 200
    warn("Failed to continue transaction: $(resp.status)")
  end
  raw = json(resp)
  Transaction(c, raw["commit"], t.location, Results(raw))
end

execute(t::Transaction, s::Statement) = execute(t, Query([s]))

function commit(t::Transaction, q::Query)
  resp = post(t.location;
      headers=connheaders(t.connection),
      json=q)
  if resp.status != 200
    warn("Failed to commit transaction: $(resp.status)")
  end
  raw = json(resp)
  Results(raw)
end

commit(t::Transaction, s::Statement) = commit(t, Query([s]))
commit(t::Transaction) = commit(t, Query([]))

function rollback(t::Transaction)
  resp = delete(t.location; headers=connheaders(t.connection))
  if resp.status != 200
    warn("Failed to rollback transaction: $(resp.status)")
  end
  raw = json(resp)
  Results(raw)
end

function submit(c::Connection, q::Query)
  resp = post(connurl(c, "transaction/commit");
      headers=connheaders(c),
      json=q)
  if resp.status != 200
    warn("Request failed: $(resp.status)")
  end
  raw = json(resp)
  Request(raw)
end

submit(c::Connection, s::Statement) = submit(c, Query([s]))

