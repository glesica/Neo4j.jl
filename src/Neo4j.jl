module Neo4j
using Requests
using JSON

import Requests: get, post, put, delete, options

export getgraph, version, createnode, getnode, deletenode, setnodeproperty, getnodeproperty,
       getnodeproperties, updatenodeproperties, deletenodeproperties, deletenodeproperty,
       addnodelabel, addnodelabels, updatenodelabels, deletenodelabel, getnodelabels,
       getnodesforlabel, getlabels, getrel, createrel, deleterel, getrelproperty,
       getrelproperties, updaterelproperties,
       authenticate, updatefewnodeproperties, updatefewrelproperties

const DEFAULT_HOST = "localhost"
const DEFAULT_PORT = 7474
const DEFAULT_URI = "/db/data/"
const DEFAULT_HEADERS = Dict{AbstractString,AbstractString}("Accept" => "application/json; charset=UTF-8", "Host" => "localhost:7474")

typealias JSONObject Union{Dict{AbstractString,Any},Void}
typealias JSONArray Union{Vector,Void}
typealias JSONData Union{JSONObject,JSONArray,AbstractString,Number,Void}

typealias QueryData Union{Dict{Any,Any},Void}

# -----------------------
# Relationship Directions
# -----------------------

immutable Direction
    dir::AbstractString
end

const inrels = Direction("in")
const outrels = Direction("out")
const bothrels = Direction("both")

# ----------
# Connection
# ----------

immutable Connection
    host::AbstractString
    port::Int
    path::AbstractString
    url::AbstractString

    Connection(host::AbstractString, port::Int, path::AbstractString) = new(host, port, path, "http://$host:$port$path")
end

Connection(host::AbstractString, port::Int) = Connection(host, port, DEFAULT_URI)
Connection(host::AbstractString) = Connection(host, DEFAULT_PORT)
Connection() = Connection(DEFAULT_HOST)

# -----
# Graph
# -----

immutable Graph
    # TODO extensions
    node::AbstractString
    node_index::AbstractString
    relationship_index::AbstractString
    extensions_info::AbstractString
    relationship_types::AbstractString
    batch::AbstractString
    cypher::AbstractString
    indexes::AbstractString
    constraints::AbstractString
    transaction::AbstractString
    node_labels::AbstractString
    version:: AbstractString
    connection::Connection
    relationship::AbstractString # Not in the spec
end

Graph(data::Dict{AbstractString,Any}, conn::Connection) = Graph(data["node"], data["node_index"], data["relationship_index"],
    data["extensions_info"], data["relationship_types"], data["batch"], data["cypher"], data["indexes"],
    data["constraints"], data["transaction"], data["node_labels"], data["neo4j_version"], conn,
    "$(conn.url)relationship")


function authenticate(conn::Connection;usrname="neo4j",pswd="neo4j")

    rqst = string("http://",usrname,":",pswd,"@",conn.host,":",conn.port)
    resp = get(rqst; headers=DEFAULT_HEADERS)

    if resp.status == 401
        error("Authorization unsuccessful: $(resp.status)")
    end
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end

    # Append usrname:passwd in Base64 to headers for Basic Authentication

    # hardcoded the "usr:pswd" in Base64 format. Change this later
    auth_string = base64encode("$usrname:$pswd")
    get!(DEFAULT_HEADERS,"Authorization","Basic bmVvNGo6MXNUZXAxMjM=")
end

function getgraph(conn::Connection)
    resp = get(conn.url; headers=DEFAULT_HEADERS)
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    Graph(Requests.json(resp), conn)
end

function getgraph(usrname::ASCIIString,pswd::ASCIIString)
    conn = Connection()
    authenticate(conn;usrname=usrname,pswd=pswd)
    resp = get(conn.url; headers=DEFAULT_HEADERS)
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    Graph(Requests.json(resp), conn)
end

# ----
# Node
# ----

immutable Node
    # TODO extensions
    paged_traverse::AbstractString
    labels::AbstractString
    outgoing_relationships::AbstractString
    traverse::AbstractString
    all_typed_relationships::AbstractString
    all_relationships::AbstractString
    property::AbstractString
    self::AbstractString
    outgoing_typed_relationships::AbstractString
    properties::AbstractString
    incoming_relationships::AbstractString
    incoming_typed_relationships::AbstractString
    create_relationship::AbstractString
    data::JSONObject
    id::Int
    graph::Graph
end

Node(data::JSONObject, graph::Graph) = Node(data["paged_traverse"], data["labels"],
     data["outgoing_relationships"], data["traverse"], data["all_typed_relationships"],
     data["all_relationships"], data["property"],
     data["self"], data["outgoing_typed_relationships"], data["properties"],
     data["incoming_relationships"], data["incoming_typed_relationships"],
     data["create_relationship"], data["data"],
     split(data["self"], "/")[end] |> int, graph)

# --------
# Requests
# --------

function request(url::AbstractString, method::Function, exp_code::Int;
                 headers::Dict{AbstractString,AbstractString}=DEFAULT_HEADERS, json::JSONData=nothing,
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
    resp = request(graph.node, post, 201; json=props)
    Node(Requests.json(resp), graph)
end

function getnode(graph::Graph, id::Int)
    url = "$(graph.node)/$id"
    resp = request(url, get, 200)
    Node(Requests.json(resp), graph)
end

function getnode(node::Node)
    getnode(node.graph, node.id)
end

function deletenode(node::Node)
    request(node.self, delete, 204)
end

function deletenode(graph::Graph, id::Int)
    node = getnode(graph, id)
    deletenode(node)
end

function setnodeproperty(node::Node, name::AbstractString, value::Any)
    url = replace(node.property, "{key}", name)
    request(url, put, 204; json=value)
end

function setnodeproperty(graph::Graph, id::Int, name::AbstractString, value::Any)
    node = getnode(graph, id)
    setnodeproperty(node, name, value)
end


function updatefewnodeproperties(graph::Graph, id::Int, props::JSONObject)
  node = getnode(g,id)
  for prop in keys(props)
    url = replace(node.property, "{key}", prop)
    request(url, put, 204; json=props[prop])
  end
end

function updatefewnodeproperties(node::Node, props::JSONObject)
  for prop in keys(props)
    url = replace(node.property, "{key}", prop)
    request(url, put, 204; json=props[prop])
  end
end


function updatenodeproperties(node::Node, props::JSONObject)
    # it is an overwrite: this will erase all old properties and writes new ones
    # Neo4j API specifies the same:
    resp = request(node.properties, put, 204; json=props)
end

function getnodeproperty(node::Node, name::AbstractString)
    url = replace(node.property, "{key}", name)
    resp = request(url, get, 200)
    Requests.json(resp)
end

function getnodeproperties(node::Node)
    resp = request(node.properties, get, 200)
    Requests.json(resp)
end

function getnodeproperties(graph::Graph, id::Int)
    node = getnode(graph, id)
    getnodeproperties(node)
end

function deletenodeproperties(node::Node)
    request(node.properties, delete, 204)
end

function deletenodeproperty(node::Node, name::AbstractString)
    url = replace(node.property, "{key}", name)
    request(url, delete, 204)
end

function addnodelabel(node::Node, label::AbstractString)
    request(node.labels, post, 204; json=label)
end

function addnodelabels(node::Node, labels::JSONArray)
    request(node.labels, post, 204; json=labels)
end

function updatenodelabels(node::Node, labels::JSONArray)
    request(node.labels, put, 204; json=labels)
end

function deletenodelabel(node::Node, label::AbstractString)
    url = "$(node.labels)/$label"
    request(url, delete, 204)
end

function getnodelabels(node::Node)
    resp = request(node.labels, get, 200)
    Requests.json(resp)
end

function getnodesforlabel(graph::Graph, label::AbstractString, props::JSONObject=nothing)
    # TODO Shouldn't this url be available in the api somewhere?
    url = "$(graph.connection.url)label/$label/nodes"
    resp = request(url, get, 200; query=props)
    [Node(nodedata, graph) for nodedata = Requests.json(resp)]
end

function getlabels(graph::Graph)
    resp = request(graph.node_labels, get, 200)
    Requests.json(resp)
end

# -------------
# Relationships
# -------------

immutable Relationship
    relstart::AbstractString
    property::AbstractString
    self::AbstractString
    properties::AbstractString
    reltype::AbstractString
    relend::AbstractString
    data::JSONObject
    id::Int
    graph::Graph
end

Relationship(data::JSONObject, graph::Graph) = Relationship(data["start"], data["property"],
        data["self"], data["properties"], data["type"], data["end"], data["data"],
        split(data["self"], "/")[end] |> int, graph)

function getnoderels(node::Node; reldir::Direction=bothrels)

end

function getrel(graph::Graph, id::Int)
    url = "$(graph.relationship)/$id"
    resp = request(url, get, 200)
    Relationship(Requests.json(resp), graph)
end

function createrel(from::Node, to::Node, reltype::AbstractString; props::JSONObject=nothing)
    body = Dict{AbstractString,Any}("to" => to.self, "type" => uppercase(reltype))
    if props !== nothing
        body["data"] = props
    end
    resp = request(from.create_relationship, post, 201, json=body)
    Relationship(Requests.json(resp), from.graph)
end

function deleterel(rel::Relationship)
    request(rel.self, delete, 204)
end

function getrelproperty(rel::Relationship, name::AbstractString)
    url = replace(rel.property, "{key}", name)
    resp = request(url, get, 200)
    Requests.json(resp)
end

function getrelproperties(rel::Relationship)
    resp = request(rel.properties, get, 200)
    Requests.json(resp)
end

# TBD
function updatefewrelproperties(rel::Relationship, props::JSONObject)
    # loop through all properties one at-a-time and update each of them
    for prop in keys(props)
      url = replace(rel.property, "{key}", prop)
      request(url, put, 204; json=props[prop])
    end
end

function updaterelproperties(rel::Relationship, props::JSONObject)
    # the following is basically overwrite (a misnomer and Neo4j API calls it the same way).
    # ALL old property fields will be erased and new ones are written back
    request(rel.properties, put, 204; json=props)
end


end # module
