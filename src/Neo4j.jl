module Neo4j

using Requests
using JSON

export getgraph, version, createnode

const DEFAULT_HOST = "localhost"
const DEFAULT_PORT = 7474
const DEFAULT_URI = "/db/data/"
const DEFAULT_HEADERS = {"Accept" => "application/json; charset=UTF-8", "Host" => "localhost:7474"}

# ----------
# Connection
# ----------

immutable Connection
    host::String
    port::Int
    path::String
    url::String

    Connection(host::String, port::Int, path::String) = new(host, port, path, "http://$host:$port$path")
end

Connection(host::String, port::Int) = Connection(host, port, DEFAULT_URI)
Connection(host::String) = Connection(host, DEFAULT_PORT)
Connection() = Connection(DEFAULT_HOST)

# -----
# Graph
# -----

immutable Graph
    # TODO extensions
    node::String
    node_index::String
    relationship_index::String
    extensions_info::String
    relationship_types::String
    batch::String
    cypher::String
    indexes::String
    constraints::String
    transaction::String
    node_labels::String
    version:: String
end

Graph(data::Dict{String,Any}) = Graph(data["node"], data["node_index"], data["relationship_index"],
    data["extensions_info"], data["relationship_types"], data["batch"], data["cypher"], data["indexes"],
    data["constraints"], data["transaction"], data["node_labels"], data["neo4j_version"])

function getgraph(conn::Connection)
    resp = get(conn.url; headers=DEFAULT_HEADERS)
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    Graph(resp.data |> JSON.parse)
end

function getgraph()
    getgraph(Connection())
end

# ----
# Node
# ----

immutable Node
    # TODO extensions
    paged_traverse::String
    labels::String
    outgoing_relationships::String
    traverse::String
    all_typed_relationships::String
    all_relationships::String
    property::String
    self::String
    outgoing_typed_relationships::String
    properties::String
    incoming_relationships::String
    incoming_typed_relationships::String
    create_relationship::String
    data::Dict{String,Any}
    id::Int
end

Node(data::Dict{String,Any}) = Node(data["paged_traverse"], data["labels"], data["outgoing_relationships"],
    data["traverse"], data["all_typed_relationships"], data["all_relationships"], data["property"],
    data["self"], data["outgoing_typed_relationships"], data["properties"], data["incoming_relationships"],
    data["incoming_typed_relationships"], data["create_relationship"], data["data"],
    split(data["self"], "/")[end] |> int)

function createnode(graph::Graph)
    resp = post(graph.node; headers=DEFAULT_HEADERS)
    if resp.status !== 201
        error("Node creation unsuccessful: $(resp.status)")
    end
    Node(resp.data |> JSON.parse)
end

end # module
