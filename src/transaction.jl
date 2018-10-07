# Transactions
# A transaction is the primary type through which the database is accessed. A
# transaction can be a single request, or it can be held open through many
# requests as a means of batching jobs together.

export transaction, rollback, commit

struct Transaction
  conn::Connection
  commit::AbstractString
  location::AbstractString
  statements::Vector{Statement}
end

# TODO: Provide a version that accepts statements.
function transaction(conn::Connection)::Transaction
  url = connurl(conn, "transaction")
  headers = connheaders(conn)
  body = Dict("statements" => [ ])

  resp = HTTP.post(url; headers=headers, body=JSON.json(body))
  if resp.status != 201
    error("Failed to connect to database ($(resp.status)): $(conn)\n$(resp)")
  end
  respdata = JSON.parse(String(resp.body))
  # Get the header with entry "Location"
  location = filter(h->h[1]=="Location", resp.headers)
  if length(location) == 0
      error("Could not header with key 'Location' in response body of the transaction.")
  end

  return Transaction(conn, respdata["commit"], location[1][2], Statement[])
end

function (txn::Transaction)(cypher::AbstractString, params::Pair...;
    submit::Bool=false)
  append!(txn.statements, [Statement(cypher, Dict(params))])
  if submit
    url = txn.location
    headers = connheaders(txn.conn)
    body = Dict("statements" => txn.statements)

    resp = HTTP.post(url; headers=headers, body=JSON.json(body))
    if resp.status != 200
      error("Failed to submit transaction ($(resp.status)): $(txn)\n$(resp)")
    end
    respdata = JSON.parse(String(resp.body))

    empty!(txn.statements)
    result = Result(respdata["results"], respdata["errors"])

    return result
  end
end

function commit(txn::Transaction)::Result
  url = txn.commit
  headers = connheaders(txn.conn)
  body = Dict("statements" => txn.statements)

  resp = HTTP.post(url; headers=headers, body=JSON.json(body))

  if resp.status != 200
    error("Failed to commit transaction ($(resp.status)): $(txn)\n$(resp)")
  end
  respdata = JSON.parse(String(resp.body))

  return Result(respdata["results"], respdata["errors"])
end

function rollback(txn::Transaction)::HTTP.Response
  url = txn.location
  headers = connheaders(txn.conn)

  resp = HTTP.delete(url; headers=headers)
  if resp.status != 200
    error("Failed to rollback transaction ($(resp.status)): $(txn)\n$(resp)")
  end
  return resp
end
