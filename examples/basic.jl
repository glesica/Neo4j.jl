include("../src/neo4j.jl")

c = Connection(false, "localhost", "neo4j", "password")

t = start(c, cypher("MATCH (n:Person) RETURN n LIMIT {lim}", "lim" => 3))
println(t.results)

t = execute(t, cypher("MATCH (n:Movie) RETURN n LIMIT {lim}", "lim" => 10))
println(t.results)

r = commit(t)

println(r)

