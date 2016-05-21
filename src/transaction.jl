# Transactions
# A transaction is the primary type through which the database is accessed. A
# transaction can be a single request, or it can be held open through many
# requests as a means of batching jobs together.

import Base.call

export transaction, rollback, commit

immutable Transaction
  conn::Connection
  commit::AbstractString
  location::AbstractString
  statements::Vector{Statement}
end

# TODO: Provide a version that accepts statements.
function transaction(conn::Connection)
  url = connurl(conn, "transaction")
  headers = connheaders(conn)
  body = Dict("statements" => [])

  resp = post(url; headers=headers, json=body)
  if resp.status != 201
    error("Failed to connect to database ($(resp.status)): $(conn)")
  end
  respdata = json(resp)
  
  Transaction(conn, respdata["commit"], resp.headers["Location"], Statement[])
end

function call(txn::Transaction, cypher::AbstractString, params::Pair...;
    submit::Bool=false)
  append!(txn.statements, [Statement(cypher, Dict(params))])
  if submit
    url = txn.location
    headers = connheaders(txn.conn)
    body = Dict("statements" => txn.statements)

    resp = post(url; headers=headers, json=body)

    if resp.status != 200
      error("Failed to submit transaction ($(resp.status)): $(txn)")
    end
    respdata = json(resp)

    empty!(txn.statements)
    result = Result(respdata["results"], respdata["errors"])

    result
  end
end

function commit(txn::Transaction)
  url = txn.commit
  headers = connheaders(txn.conn)
  body = Dict("statements" => txn.statements)

  resp = post(url; headers=headers, json=body)
  
  if resp.status != 200
    error("Failed to commit transaction ($(resp.status)): $(txn)")
  end
  respdata = json(resp)

  Result(respdata["results"], respdata["errors"])
end

function rollback(txn::Transaction)
  url = txn.location
  headers = connheaders(txn.conn)

  resp = delete(url; headers=headers)
  if resp.status != 200
    error("Failed to rollback transaction ($(resp.status)): $(txn)")
  end
end

