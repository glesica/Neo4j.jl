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

## via REST

 Connect to Neo4j and create a graph object
```julia
graph = getgraph("user","password")
```
Create a node with some properties
```julia
propnode = createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))
```
Create nodes with some properties
```julia
from = createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))
to = createnode(graph)
```
Add a label to the node
```julia
addnodelabel(from, "A")
```
Create a relationships
```julia
rel = createrel(from, to, "test"; props=Dict{AbstractString,Any}("a" => "A", "b" => 1))
```
Update relationship property
```julia
updaterelproperties(rel,Dict{AbstractString,Any}("a" => "AA","b"=>"BB"))
```

check the tests for more examples
