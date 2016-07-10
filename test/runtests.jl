using Neo4j
using Base.Test

@test isdefined(:Neo4j) == true
@test typeof(Neo4j) == Module

graph = nothing
try
  print("[TEST] Creating a Neo4j connection to localhost:7474 with no credentials...");
  graph = getgraph()
catch
  print("[TEST] Creating a Neo4j connection to localhost:7474 with neo4j:neo5j credentials...");
  #Trying with security.
  conn = Neo4j.Connection("localhost"; user="neo4j", password="neo5j");
  graph = getgraph(conn);
end
println("Success!");

print("[TEST] Checking version of connected graph = Neo4j ", ascii(graph.version), "...")
# Have to account for newer Neo4j! Using version text - ref: http://docs.julialang.org/en/release-0.4/manual/strings/
@test convert(VersionNumber, graph.version) >  v"2.0.0"
# Check that
@test graph.node == "http://localhost:7474/db/data/node"
println("Success!");

print("[TEST] Creating a node...");
barenode = createnode(graph)
@test barenode.self == "http://localhost:7474/db/data/node/$(barenode.id)"
println("Success!");

print("[TEST] Creating a node with properties...");
propnode = createnode(graph, Dict{UTF8String,Any}("a" => "A", "b" => 1))
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
updatenodeproperties(barenode, Dict{UTF8String,Any}("a" => 1, "b" => "A"))
barenode = getnode(barenode)
@test barenode.data["a"] == 1
@test barenode.data["b"] == "A"

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
rel1 = createrel(barenode, propnode, "test"; props=Dict{UTF8String,Any}("a" => "A", "b" => 1));
rel1alt = getrel(graph, rel1.id);
@test rel1.reltype == "TEST"
@test rel1.data["a"] == "A"
@test rel1.data["b"] == 1
@test rel1.id == rel1alt.id
println("Success!");

print("[TEST] Getting relationships from nodes...")
endnode = createnode(graph, Dict{UTF8String,Any}("a" => "A", "b" => 1))
rel2 = createrel(propnode, endnode, "test"; props=Dict{UTF8String,Any}("a" => "A", "b" => 1));
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
