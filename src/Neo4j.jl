module Neo4j

using Requests
using JSON

export getgraph, version, createnode, getnode, deletenode, setnodeproperty, getnodeproperty,
       getnodeproperties, updatenodeproperties, deletenodeproperties, deletenodeproperty,
       addnodelabel, addnodelabels, updatenodelabels, deletenodelabel, getnodelabels,
       getnodesforlabel, getlabels, getrel, createrel, deleterel, getrelproperty,
       getrelproperties, updaterelproperties

const DEFAULT_HOST = "localhost"
const DEFAULT_PORT = 7474
const DEFAULT_URI = "/db/data/"
const DEFAULT_HEADERS = Dict{Any, Any}("Accept" => "application/json; charset=UTF-8", "Host" => "localhost:7474")

typealias JSONObject Union{Dict{UTF8String,Any},Void}
typealias JSONArray Union{Vector,Void}
typealias JSONData Union{JSONObject,JSONArray,AbstractString,Number,Void}

typealias QueryData Union{Dict{Any,Any},Void}

# -----------------------
# Relationship Directions
# -----------------------

immutable Direction
    dir::UTF8String
end

const inrels = Direction("in")
const outrels = Direction("out")
const bothrels = Direction("both")

# ----------
# Connection
# ----------

immutable Connection
    host::UTF8String
    port::Int
    path::UTF8String
    url::UTF8String

    Connection(host::AbstractString, port::Int, path::AbstractString) = new(utf8(host), port, utf8(path), utf8("http://$host:$port$path"))
end

Connection(host::AbstractString, port::Int) = Connection(host, port, DEFAULT_URI)
Connection(host::AbstractString) = Connection(host, DEFAULT_PORT)
Connection() = Connection(DEFAULT_HOST)

# -----
# Graph
# -----

immutable Graph
    # TODO extensions
    node::UTF8String
    node_index::UTF8String
    relationship_index::UTF8String
    extensions_info::UTF8String
    relationship_types::UTF8String
    batch::UTF8String
    cypher::UTF8String
    indexes::UTF8String
    constraints::UTF8String
    transaction::UTF8String
    node_labels::UTF8String
    version::UTF8String
    connection::Connection
    relationship::UTF8String # Not in the spec
end

Graph(data::Dict{UTF8String,Any}, conn::Connection) = Graph(data["node"], data["node_index"], data["relationship_index"],
    data["extensions_info"], data["relationship_types"], data["batch"], data["cypher"], data["indexes"],
    data["constraints"], data["transaction"], data["node_labels"], data["neo4j_version"], conn,
    "$(conn.url)relationship")

function getgraph(conn::Connection)
    resp = get(conn.url; headers=DEFAULT_HEADERS)
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    #Note the Requests lib returns UTF8String, so lets just use that as a standard for REST calls [GearsAD]
    Graph(Requests.json(resp), conn)
end

function getgraph()
    getgraph(Connection())
end

# ----
# Node
# ----

type Node
    # TODO extensions
    paged_traverse::UTF8String
    labels::UTF8String
    outgoing_relationships::UTF8String
    traverse::UTF8String
    all_typed_relationships::UTF8String
    all_relationships::UTF8String
    property::UTF8String
    self::UTF8String
    outgoing_typed_relationships::UTF8String
    properties::UTF8String
    incoming_relationships::UTF8String
    incoming_typed_relationships::UTF8String
    create_relationship::UTF8String
    data::JSONObject
    id::Int64
    graph::Graph

    #Constructors
    Node() = new()
    Node(data::JSONObject, graph::Graph) = new(data["paged_traverse"], data["labels"],
         data["outgoing_relationships"], data["traverse"], data["all_typed_relationships"],
         data["all_relationships"], data["property"],
         data["self"], data["outgoing_typed_relationships"], data["properties"],
         data["incoming_relationships"], data["incoming_typed_relationships"],
         data["create_relationship"], data["data"],
         split(data["self"], "/")[end] |> parse, graph)
end


# --------
# Requests
# --------

function request(url::AbstractString, method::Function, exp_code::Int;
                 headers::Dict{Any,Any}=DEFAULT_HEADERS, json::JSONData=nothing,
                 query::QueryData=nothing)
    if json == nothing && query == nothing
        resp = method(url; headers=headers)
    elseif json == nothing
        resp = method(url; headers=headers, query=query)
    elseif query == nothing
        resp = method(url; headers=headers, json=json)
    else
        # TODO Figure out if this should ever occur and change it to an error if not
        resp = method(url; headers=headers, json=json, query=query)
    end
    if resp.status !== exp_code
        respdata = Requests.json(resp)
        if respdata !== nothing && "message" in keys(respdata)
            error("Neo4j error: $(respdata["message"])")
        else
            error("Neo4j error: $(url) returned $(resp.status)")
        end
    end
    resp
end

# -----------------
# External requests
# -----------------

function createnode(graph::Graph, props::JSONData=nothing)
    resp = request(graph.node, Requests.post, 201; json=props)
    Node(Requests.json(resp), graph)
end

function getnode(graph::Graph, id::Int)
    url = "$(graph.node)/$id"
    resp = request(url, Requests.get, 200)
    Node(Requests.json(resp), graph)
end

function getnode(node::Node)
    getnode(node.graph, node.id)
end

function deletenode(node::Node)
    request(node.self, Requests.delete, 204)
end

function deletenode(graph::Graph, id::Int)
    node = getnode(graph, id)
    deletenode(node)
end

function setnodeproperty(node::Node, name::AbstractString, value::Any)
    url = replace(node.property, "{key}", name)
    request(url, Requests.put, 204; json=value)
end

function setnodeproperty(graph::Graph, id::Int, name::AbstractString, value::Any)
    node = getnode(graph, id)
    setnodeproperty(node, name, value)
end

function updatenodeproperties(node::Node, props::JSONObject)
    resp = request(node.properties, Requests.put, 204; json=props)
end

function getnodeproperty(node::Node, name::AbstractString)
    url = replace(node.property, "{key}", name)
    resp = request(url, Requests.get, 200)
    Requests.json(resp)
end

function getnodeproperties(node::Node)
    resp = request(node.properties, Requests.get, 200)
    Requests.json(resp)
end

function getnodeproperties(graph::Graph, id::Int)
    node = getnode(graph, id)
    getnodeproperties(node)
end

function deletenodeproperties(node::Node)
    request(node.properties, Requests.delete, 204)
end

function deletenodeproperty(node::Node, name::AbstractString)
    url = replace(node.property, "{key}", name)
    request(url, Requests.delete, 204)
end

function addnodelabel(node::Node, label::AbstractString)
    request(node.labels, Requests.post, 204; json=label)
end

function addnodelabels(node::Node, labels::JSONArray)
    request(node.labels, Requests.post, 204; json=labels)
end

function updatenodelabels(node::Node, labels::JSONArray)
    request(node.labels, Requests.put, 204; json=labels)
end

function deletenodelabel(node::Node, label::AbstractString)
    url = "$(node.labels)/$label"
    request(url, Requests.delete, 204)
end

function getnodelabels(node::Node)
    resp = request(node.labels, Requests.get, 200)
    Requests.json(resp)
end

function getnodesforlabel(graph::Graph, label::AbstractString, props::JSONObject=nothing)
    # TODO Shouldn't this url be available in the api somewhere?
    url = "$(graph.connection.url)label/$label/nodes"
    resp = request(url, Requests.get, 200; query=props)
    [Node(nodedata, graph) for nodedata = Requests.json(resp)]
end

function getlabels(graph::Graph)
    resp = request(graph.node_labels, Requests.get, 200)
    Requests.json(resp)
end

# -------------
# Relationships
# -------------

immutable Relationship
    relstart::UTF8String
    property::UTF8String
    self::UTF8String
    properties::UTF8String
    reltype::UTF8String
    relend::UTF8String
    data::JSONObject
    id::Int
    graph::Graph
end

Relationship(data::JSONObject, graph::Graph) = Relationship(data["start"], data["property"],
        data["self"], data["properties"], data["type"], data["end"], data["data"],
        split(data["self"], "/")[end] |> parse, graph)

function getnoderels(node::Node; reldir::Direction=bothrels)

end

function getrel(graph::Graph, id::Int)
    url = "$(graph.relationship)/$id"
    resp = request(url, Requests.get, 200)
    Relationship(Requests.json(resp), graph)
end

function createrel(from::Node, to::Node, reltype::AbstractString; props::JSONObject=nothing)
    body = Dict{UTF8String, Any}("to" => to.self, "type" => uppercase(reltype))
    if props !== nothing
        body["data"] = props
    end
    resp = request(from.create_relationship, Requests.post, 201, json=body)
    Relationship(Requests.json(resp), from.graph)
end

function deleterel(rel::Relationship)
    request(rel.self, Requests.delete, 204)
end

function getrelproperty(rel::Relationship, name::AbstractString)
    url = replace(rel.property, "{key}", name)
    resp = request(url, Requests.get, 200)
    Requests.json(resp)
end

function getrelproperties(rel::Relationship)
    resp = request(rel.properties, Requests.get, 200)
    Requests.json(resp)
end

function updaterelproperties(rel::Relationship, props::JSONObject)
    request(rel.properties, Requests.put, 204; json=props)
end

end # module
