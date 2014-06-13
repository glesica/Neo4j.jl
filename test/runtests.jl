using Neo4j
using Base.Test

@test isdefined(:Neo4j) == true
@test typeof(Neo4j) == Module

graph = getgraph()
@test beginswith(graph.version, "2") == true
@test graph.node == "http://localhost:7474/db/data/node"

node = createnode(graph)
id = node.id
@test node.self == "http://localhost:7474/db/data/node/$id"
