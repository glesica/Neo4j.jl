using Neo4j
using Base.Test

c = Connection("localhost"; user="neo4j", password="neo4j")

loadtx = transaction(c)

function createnode(txn, name, age)
  q = "CREATE (n:Neo4jjl) SET n.name = {name}, n.age = {age}"
  txn(q, "name" => name, "age" => age)
end

@test length(loadtx.statements) == 0

createnode(loadtx, "John Doe", 20)

@test length(loadtx.statements) == 1

createnode(loadtx, "Jane Doe", 20)

@test length(loadtx.statements) == 2

people = loadtx("MATCH (n:Neo4jjl) WHERE n.age = {age} RETURN n.name", "age" => 20; submit=true)

@test length(loadtx.statements) == 0
@test length(people.results) == 3
@test length(people.errors) == 0

matchresult = people.results[3]
@test matchresult["columns"][1] == "n.name"
@test "John Doe" in [row["row"][1] for row = matchresult["data"]]
@test "Jane Doe" in [row["row"][1] for row = matchresult["data"]]

loadresult = commit(loadtx)

@test length(loadresult.results) == 0
@test length(loadresult.errors) == 0

deletetx = transaction(c)

deletetx("MATCH (n:Neo4jjl) WHERE n.age = {age} DELETE n", "age" => 20)

deleteresult = commit(deletetx)

@test length(deleteresult.results) == 1
@test length(deleteresult.results[1]["columns"]) == 0
@test length(deleteresult.results[1]["data"]) == 0
@test length(deleteresult.errors) == 0

