using Neo4j, DataFrames
using Test

@testset "Module imports" begin
    @test (@isdefined Neo4j) == true
    @test typeof(Neo4j) == Module
end

# defaults for testing
global username = "neo4j"
global passwd = "neo5j"

global graph = nothing
global conn = nothing
@testset "Creating a connection to localhost" begin
    try
      global graph = getgraph()
    catch
      @info "[TEST] Anonymous connection failed! Creating a Neo4j connection to localhost:7474 with neo4j:$(passwd) credentials..."
      #Trying with security.
      global conn = Neo4j.Connection("localhost"; user=username, password=passwd);
      global graph = getgraph(conn);
    end
    global conn = graph.connection;
end

@testset "Checking version of connected graph = Neo4j $(ascii(graph.version))..." begin
    # Have to account for newer Neo4j! Using version text - ref: http://docs.julialang.org/en/release-0.4/manual/strings/
    @test VersionNumber(graph.version) > v"2.0.0" # convert(VersionNumber, graph.version) >  v"2.0.0"
    # Check that
    @test graph.node == "http://localhost:7474/db/data/node"
end

global barenode = nothing
global propnode = nothing
@testset "Nodes: CRUD, properties, and labels..." begin
    global barenode = Neo4j.createnode(graph)
    @test barenode.self == "http://localhost:7474/db/data/node/$(barenode.id)"

    global propnode = Neo4j.createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))  #UTF8String
    @test propnode.data["a"] == "A"
    @test propnode.data["b"] == 1

    global gotnode = getnode(graph, propnode.id)
    @test gotnode.id == propnode.id
    @test gotnode.data["a"] == "A"
    @test gotnode.data["b"] == 1

    setnodeproperty(barenode, "a", "A")
    global barenode = getnode(barenode)
    @test barenode.data["a"] == "A"

    global props = getnodeproperties(propnode)
    @test props["a"] == "A"
    @test props["b"] == 1
    @test length(props) == 2

    updatenodeproperties(barenode, Dict{AbstractString,Any}("a" => 1, "b" => "A"))  #UTF8String
    global barenode = getnode(barenode)
    @test barenode.data["a"] == 1
    @test barenode.data["b"] == "A"

    deletenodeproperties(barenode)
    global barenode = getnode(barenode)
    @test length(barenode.data) == 0

    deletenodeproperty(propnode, "b")
    global propnode = getnode(propnode)
    @test length(propnode.data) == 1
    @test propnode.data["a"] == "A"

    addnodelabel(barenode, "A")
    global barenode = getnode(barenode)
    @test getnodelabels(barenode) == ["A"]

    addnodelabels(barenode, ["B", "C"])
    global barenode = getnode(barenode)
    global labels = getnodelabels(barenode)
    @test "A" in labels
    @test "B" in labels
    @test "C" in labels
    @test length(labels) == 3

    updatenodelabels(barenode, ["D", "E", "F"])
    global barenode = getnode(barenode)
    global labels = getnodelabels(barenode)
    @test "D" in labels
    @test "E" in labels
    @test "F" in labels
    @test length(labels) == 3

    deletenodelabel(barenode, "D")
    global barenode = getnode(barenode)
    global labels = getnodelabels(barenode)
    @test "E" in labels
    @test "F" in labels
    @test length(labels) == 2

    global nodes = getnodesforlabel(graph, "E")
    @test length(nodes) > 0
    @test barenode.id in [n.id for n = nodes]

    global labels = getlabels(graph)
end

@testset "Relationships: CRUD, neighbors" begin
    global rel1 = createrel(barenode, propnode, "test"; props=Dict{AbstractString,Any}("a" => "A", "b" => 1)); #UTF8String
    global rel1alt = getrel(graph, rel1.id);
    @test rel1.reltype == "TEST"
    @test rel1.data["a"] == "A"
    @test rel1.data["b"] == 1
    @test rel1.id == rel1alt.id

    global endnode = Neo4j.createnode(graph, Dict{AbstractString,Any}("a" => "A", "b" => 1))  # UTF8String
    global rel2 = createrel(propnode, endnode, "test"; props=Dict{AbstractString,Any}("a" => "A", "b" => 1));  # UTF8String
    @test length(Neo4j.getrels(endnode)) == 1
    @test length(Neo4j.getrels(propnode)) == 2
    @test length(Neo4j.getrels(barenode)) == 1
    @test length(Neo4j.getrels(endnode, incoming=true, outgoing=false)) == 1
    @test length(Neo4j.getrels(endnode, incoming=false, outgoing=true)) == 0
    @test length(Neo4j.getrels(propnode, incoming=true, outgoing=false)) == 1
    @test length(Neo4j.getrels(propnode, incoming=false, outgoing=true)) == 1

    global neighbors = Neo4j.getneighbors(propnode)
    @test length(neighbors) == 2
    global neighbors = Neo4j.getneighbors(propnode, incoming=true, outgoing=false)
    @test length(neighbors) == 1
    @test neighbors[1].metadata["id"] == barenode.metadata["id"]
    global neighbors = Neo4j.getneighbors(propnode, incoming=false, outgoing=true)
    @test length(neighbors) == 1
    @test neighbors[1].metadata["id"] == endnode.metadata["id"]

    global rel1prop = getrelproperties(rel1);
    @test rel1prop["a"] == "A"
    @test rel1prop["b"] == 1
    @test length(rel1prop) == 2
    @test getrelproperty(rel1, "a") == "A"
    @test getrelproperty(rel1, "b") == 1

    deleterel(rel1)
    deleterel(rel2)
    @test_throws ErrorException getrel(graph, rel1.id)
    @test_throws ErrorException getrel(graph, rel2.id)
end

@testset "Nodes: Deleting nodes (cleaning up)" begin
    deletenode(graph, barenode.id)
    deletenode(graph, propnode.id)
    @test_throws ErrorException getnode(graph, barenode.id)
    @test_throws ErrorException getnode(graph, propnode.id)
end

# --- New transaction code from Glesica source ---
function createnode(txn, name, age; submit=false)
  q = "CREATE (n:Neo4jjl) SET n.name = {name}, n.age = {age}"
  txn(q, "name" => name, "age" => age; submit=submit)
end

@testset "Transactions" begin
    global loadtx = transaction(conn)

    @test length(loadtx.statements) == 0

    createnode(loadtx, "John Doe", 20)

    @test length(loadtx.statements) == 1

    createnode(loadtx, "Jane Doe", 20)

    @test length(loadtx.statements) == 2

    global query = "MATCH (n:Neo4jjl) WHERE n.age = {age} RETURN n.name";
    global people = loadtx(query, "age" => 20; submit=true)

    @test length(loadtx.statements) == 0
    @test length(people.results) == 3
    @test length(people.errors) == 0

    global matchresult = people.results[3]
    @test matchresult["columns"][1] == "n.name"
    @test "John Doe" in [row["row"][1] for row = matchresult["data"]]
    @test "Jane Doe" in [row["row"][1] for row = matchresult["data"]]

    global loadresult = commit(loadtx)

    @test length(loadresult.results) == 0
    @test length(loadresult.errors) == 0

    global query = "MATCH (n:Neo4jjl) WHERE n.age = {age} DELETE n"

    global deletetx = transaction(conn)
    deletetx(query, "age" => 20)

    global deleteresult = commit(deletetx)

    @test length(deleteresult.results) == 1
    @test length(deleteresult.results[1]["columns"]) == 0
    @test length(deleteresult.results[1]["data"]) == 0
    @test length(deleteresult.errors) == 0

    global rolltx = transaction(conn)

    global person = createnode(rolltx, "John Doe", 20; submit=true)

    @test length(rolltx.statements) == 0
    @test length(person.results) == 1
    @test length(person.errors) == 0

    rollback(rolltx)

    global rolltx = transaction(conn)
    global rollresult = rolltx("MATCH (n:Neo4jjl) WHERE n.name = 'John Doe' RETURN n"; submit=true)

    @test length(rollresult.results) == 1
    @test length(rollresult.results[1]["columns"]) == 1
    @test length(rollresult.results[1]["data"]) == 0
    @test length(rollresult.errors) == 0

end

# --- New cypherQuery using transaction/commit endpoint ---

@testset "DataFrames with cypherQuery()" begin

    # Open transaction and create node
    global loadtx = transaction(conn)
    createnode(loadtx, "John Doe", 20; submit=true)
    Neo4j.commit(loadtx)

    global matchresult = cypherQuery(conn,
                      "MATCH (n:Neo4jjl {name: {name}}) RETURN n.name AS Name, n.age AS Age;",
                      "name" => "John Doe")
    @test DataFrames.DataFrame(Name = "John Doe", Age = 20) == matchresult

    # Cleanup
    global deletetx = transaction(conn)
    global query = "MATCH (n:Neo4jjl) WHERE n.age = {age} DELETE n"
    deletetx(query, "age" => 20)
    global deleteresult = commit(deletetx)
end
