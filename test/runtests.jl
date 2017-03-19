using Neo4j
using Base.Test

@test isdefined(:Neo4j) == true
@test typeof(Neo4j) == Module

graph = nothing
try
  print("[TEST] Creating a Neo4j connection to localhost:7474 with no credentials...");
  graph = getgraph()
catch
  print("[TEST] Anonymous connection failed! Creating a Neo4j connection to localhost:7474 with neo4j:neo5j credentials...");
  #Trying with security.
  conn = Neo4j.Connection("localhost"; user="neo4j", password="neo5j");
  graph = getgraph(conn);
end
conn = graph.connection;
println("Success!");

print("[TEST] Checking version of connected graph = Neo4j ", ascii(graph.version), "...")
# Have to account for newer Neo4j! Using version text - ref: http://docs.julialang.org/en/release-0.4/manual/strings/
@test convert(VersionNumber, graph.version) >  v"2.0.0"
# Check that
@test graph.node == "http://localhost:7474/db/data/node"
println("Success!");

print("[TEST] Creating a node...");
barenode = Neo4j.createnode(graph)
@test barenode.self == "http://localhost:7474/db/data/node/$(barenode.id)"
println("Success!");

print("[TEST] Creating a node with properties...");
propnode = Neo4j.createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))  #UTF8String
@test propnode.data["a"] == "A"
@test propnode.data["b"] == 1
println("Success!");

print("[TEST] Retrieving the created node...");
gotnode = getnode(graph, propnode.id)
@test gotnode.id == propnode.id
@test gotnode.data["a"] == "A"
@test gotnode.data["b"] == 1
println("Success!");

print("[TEST] Setting node properties...");
setnodeproperty(barenode, "a", "A")
barenode = getnode(barenode)
@test barenode.data["a"] == "A"
println("Success!");

print("[TEST] Getting node properties...");
props = getnodeproperties(propnode)
@test props["a"] == "A"
@test props["b"] == 1
@test length(props) == 2
println("Success!");

print("[TEST] Updating node properties...");
updatenodeproperties(barenode, Dict{AbstractString,Any}("a" => 1, "b" => "A"))  #UTF8String
barenode = getnode(barenode)
@test barenode.data["a"] == 1
@test barenode.data["b"] == "A"
println("Success!");

print("[TEST] Deleting node properties...");
deletenodeproperties(barenode)
barenode = getnode(barenode)
@test length(barenode.data) == 0
println("Success!");

print("[TEST] Deleting a specific property...");
deletenodeproperty(propnode, "b")
propnode = getnode(propnode)
@test length(propnode.data) == 1
@test propnode.data["a"] == "A"
println("Success!");

print("[TEST] Adding a node label...")
addnodelabel(barenode, "A")
barenode = getnode(barenode)
@test getnodelabels(barenode) == ["A"]
println("Success!");

print("[TEST] Adding multiple node labels...")
addnodelabels(barenode, ["B", "C"])
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "A" in labels
@test "B" in labels
@test "C" in labels
@test length(labels) == 3
println("Success!");

print("[TEST] Updating node labels...")
updatenodelabels(barenode, ["D", "E", "F"])
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "D" in labels
@test "E" in labels
@test "F" in labels
@test length(labels) == 3
println("Success!");

print("[TEST] Deleting a node label...")
deletenodelabel(barenode, "D")
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "E" in labels
@test "F" in labels
@test length(labels) == 2
println("Success!");

print("[TEST] Getting nodes for a given label...")
nodes = getnodesforlabel(graph, "E")
@test length(nodes) > 0
@test barenode.id in [n.id for n = nodes]
println("Success!");

print("[TEST] Getting all labels...")
labels = getlabels(graph)
# TODO Can't really test this because there might be other crap in the local DB
println("Success!");

print("[TEST] Creating a relationship...")
rel1 = createrel(barenode, propnode, "test"; props=Dict{AbstractString,Any}("a" => "A", "b" => 1)); #UTF8String
rel1alt = getrel(graph, rel1.id);
@test rel1.reltype == "TEST"
@test rel1.data["a"] == "A"
@test rel1.data["b"] == 1
@test rel1.id == rel1alt.id
println("Success!");

print("[TEST] Getting relationships from nodes...")
endnode = Neo4j.createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))  # UTF8String
rel2 = createrel(propnode, endnode, "test"; props=Dict{AbstractString,Any}("a" => "A", "b" => 1));  # UTF8String
@test length(Neo4j.getrels(endnode)) == 1
@test length(Neo4j.getrels(propnode)) == 2
@test length(Neo4j.getrels(barenode)) == 1
@test length(Neo4j.getrels(endnode, incoming=true, outgoing=false)) == 1
@test length(Neo4j.getrels(endnode, incoming=false, outgoing=true)) == 0
@test length(Neo4j.getrels(propnode, incoming=true, outgoing=false)) == 1
@test length(Neo4j.getrels(propnode, incoming=false, outgoing=true)) == 1
println("Success!")

print("[TEST] Getting neighbors...")
neighbors = Neo4j.getneighbors(propnode)
@test length(neighbors) == 2
neighbors = Neo4j.getneighbors(propnode, incoming=true, outgoing=false)
@test length(neighbors) == 1
@test neighbors[1].metadata["id"] == barenode.metadata["id"]
neighbors = Neo4j.getneighbors(propnode, incoming=false, outgoing=true)
@test length(neighbors) == 1
@test neighbors[1].metadata["id"] == endnode.metadata["id"]
println("Success!")

print("[TEST] Getting relationship properties...")
rel1prop = getrelproperties(rel1);
@test rel1prop["a"] == "A"
@test rel1prop["b"] == 1
@test length(rel1prop) == 2
@test getrelproperty(rel1, "a") == "A"
@test getrelproperty(rel1, "b") == 1
println("Success!");

print("[TEST] Deleting a relationship...")
deleterel(rel1)
deleterel(rel2)
@test_throws ErrorException getrel(graph, rel1.id)
@test_throws ErrorException getrel(graph, rel2.id)
println("Success!");

print("[TEST] Deleting a node...")
deletenode(graph, barenode.id)
deletenode(graph, propnode.id)
@test_throws ErrorException getnode(graph, barenode.id)
@test_throws ErrorException getnode(graph, propnode.id)
println("Success!");

# --- New transaction code from Glesica source ---

print("[TEST] Creating a transaction and nodes with the new Glesica transaction framework...")
loadtx = transaction(conn)

function createnode(txn, name, age; submit=false)
  q = "CREATE (n:Neo4jjl) SET n.name = {name}, n.age = {age}"
  txn(q, "name" => name, "age" => age; submit=submit)
end

@test length(loadtx.statements) == 0

createnode(loadtx, "John Doe", 20)

@test length(loadtx.statements) == 1

createnode(loadtx, "Jane Doe", 20)

@test length(loadtx.statements) == 2
println("Success!")

query = "MATCH (n:Neo4jjl) WHERE n.age = {age} RETURN n.name";
print("[TEST] Doing a match query '", query, "'...")
people = loadtx(query, "age" => 20; submit=true)

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
println("Success!")

query = "MATCH (n:Neo4jjl) WHERE n.age = {age} DELETE n"
print("[TEST] Deleting nodes '", query, "'...")

deletetx = transaction(conn)
deletetx(query, "age" => 20)

deleteresult = commit(deletetx)

@test length(deleteresult.results) == 1
@test length(deleteresult.results[1]["columns"]) == 0
@test length(deleteresult.results[1]["data"]) == 0
@test length(deleteresult.errors) == 0
println("Success!")

print("[TEST] Rolling back transactions...")

rolltx = transaction(conn)

person = createnode(rolltx, "John Doe", 20; submit=true)

@test length(rolltx.statements) == 0
@test length(person.results) == 1
@test length(person.errors) == 0

rollback(rolltx)

rolltx = transaction(conn)
rollresult = rolltx("MATCH (n:Neo4jjl) WHERE n.name = 'John Doe' RETURN n"; submit=true)

@test length(rollresult.results) == 1
@test length(rollresult.results[1]["columns"]) == 1
@test length(rollresult.results[1]["data"]) == 0
@test length(rollresult.errors) == 0

println("Success!");
println("--- All tests passed!");
