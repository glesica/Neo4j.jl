# Neo4j.jl

A [Julia](http://julialang.org) client for the [Neo4j](http://neo4j.org) graph
database.

Really easy to use, have a look at ```test/runtests.jl``` for the available methods.

## Basic Usage

```julia
c = Connection("localhost"; user="neo4j", password="neo4j")
tx = transaction(c)
tx("CREATE (n:Lang) SET n.name = \$name", "name" => "Julia")
tx("MATCH (n:Lang) RETURN n LIMIT {limit}", "limit" => 10)
results = commit(tx)
```

You can also submit a transaction to the server without committing it. This
will return a result set but will keep the transaction open both on the client
and server:

```julia
results = tx("MATCH (n) RETURN n"; submit=true)
```

Rollbacks are also supported:

```julia
rollback(tx)
```

If the goal is to simply run a MATCH query and having the result in the form of a 
`DataFrames.DataFrame` object, the `cypherQuery` function can be used.
The `cypherQuery` implementation performs the query in a single trnsaction which 
automatically opens and closes the transaction:

```julia
results = cypherQuery("MATCH (n) RETURN n.property AS Property")
```
