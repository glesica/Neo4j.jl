# Basic Neo4j database driver that uses the HTTP Cypher API.

import Requests: get, post, json

export Conn, defaultconn, Statement, Query, submit

const PATH = "/db/data/"
const PORT = 7474

# -----------
# Connections
# -----------

immutable Conn
  tls::Bool
  host::AbstractString
  port::Int
  path::AbstractString
  user::AbstractString
  password::AbstractString
end

Conn(tls::Bool, host, port::Int, path) = Conn(tls, host, port, path, "", "")

Conn(tls::Bool, host, user, pass) = Conn(tls, host, PORT, PATH, user, pass)

Conn(tls::Bool, host) = Conn(tls, host, PORT, PATH, "", "")

const defaultconn = Conn(false, "localhost", PORT, PATH)

function connurl(c::Conn)
  proto = ifelse(c.tls, "https", "http")
  "$(proto)://$(c.host):$(c.port)$(c.path)"
end

function connurl(c::Conn, suffix::AbstractString)
  url = connurl(c)
  "$(url)$(suffix)"
end

function connheaders(c::Conn)
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

function submit(c::Conn, query::Query)
  resp = post(connurl(c, "transaction/commit");
      headers=connheaders(c),
      json=query)
  json(resp)
end

submit(c::Conn, stmt::Statement) = submit(c, Query([stmt]))

