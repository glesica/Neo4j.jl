using Neo4j
using Base.Test

@test isdefined(:Neo4j) == true
@test typeof(Neo4j) == Module

graph = getgraph()
@test beginswith(graph.version, "2") == true
@test graph.node == "http://localhost:7474/db/data/node"

barenode = createnode(graph)
@test barenode.self == "http://localhost:7474/db/data/node/$(barenode.id)"

propnode = createnode(graph, (String=>Any)["a" => "A", "b" => 1])
@test propnode.data["a"] == "A"
@test propnode.data["b"] == 1

gotnode = getnode(graph, propnode.id)
@test gotnode.id == propnode.id
@test gotnode.data["a"] == "A"
@test gotnode.data["b"] == 1

setnodeproperty(barenode, "a", "A")
barenode = getnode(barenode)
@test barenode.data["a"] == "A"

props = getnodeproperties(propnode)
@test props["a"] == "A"
@test props["b"] == 1
@test length(props) == 2

updatenodeproperties(barenode, (String=>Any)["a" => 1, "b" => "A"])
barenode = getnode(barenode)
@test barenode.data["a"] == 1
@test barenode.data["b"] == "A"

deletenodeproperties(barenode)
barenode = getnode(barenode)
@test length(barenode.data) == 0

deletenodeproperty(propnode, "b")
propnode = getnode(propnode)
@test length(propnode.data) == 1
@test propnode.data["a"] == "A"

addnodelabel(barenode, "A")
barenode = getnode(barenode)
@test getnodelabels(barenode) == ["A"]

addnodelabels(barenode, ["B", "C"])
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "A" in labels
@test "B" in labels
@test "C" in labels
@test length(labels) == 3

updatenodelabels(barenode, ["D", "E", "F"])
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "D" in labels
@test "E" in labels
@test "F" in labels
@test length(labels) == 3

deletenodelabel(barenode, "D")
barenode = getnode(barenode)
labels = getnodelabels(barenode)
@test "E" in labels
@test "F" in labels
@test length(labels) == 2

nodes = getnodesforlabel(graph, "E")
@test length(nodes) > 0
@test barenode.id in [n.id for n = nodes]

labels = getlabels(graph)
# TODO Can't really test this because there might be other crap in the local DB

deletenode(graph, barenode.id)
deletenode(graph, propnode.id)
@test_throws ErrorException, getnode(graph, barenode.id)
@test_throws ErrorException, getnode(graph, propnode.id)
