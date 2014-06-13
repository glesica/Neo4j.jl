using Neo4j
using Base.Test

@test isdefined(:Neo4j) == true
@test typeof(Neo4j) == Module
