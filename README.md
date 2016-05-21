# Neo4j.jl

[![Build Status](https://travis-ci.org/glesica/Neo4j.jl.png)](https://travis-ci.org/glesica/Neo4j.jl)

A [Julia](http://julialang.org) client for the [Neo4j](http://neo4j.org) graph
database.

## Basic Usage

```julia
c = Connection("localhost"; user="neo4j", password="neo4j")
tx = transaction(c)
tx = tx("MATCH (n) RETURN n LIMIT {limit}", "limit" => 10)
results = commit(tx)
```

You can also submit a transaction to the server without committing it:

```julia
tx, results = tx("MATCH (n) RETURN n"; submit=true)
```

Rollbacks are also supported:

```julia
rollback(tx)
```
