# Neo4j.jl

[![Build Status](https://travis-ci.org/glesica/Neo4j.jl.png)](https://travis-ci.org/glesica/Neo4j.jl)

A [Julia](http://julialang.org) client for the [Neo4j](http://neo4j.org) graph
database.

## Basic Usage

```julia
c = Connection("localhost"; user="neo4j", password="neo4j")
tx = transaction(c)
tx("CREATE (n:Lang) SET n.name = '{name}'", "name" => "Julia")
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

