module Neo4j
using Requests
using JSON

import Requests: get, post, put, delete, options, json

export getgraph, version, createnode, getnode, deletenode, setnodeproperty, getnodeproperty,
       getnodeproperties, updatenodeproperties, deletenodeproperties, deletenodeproperty,
       addnodelabel, addnodelabels, updatenodelabels, deletenodelabel, getnodelabels,
       getnodesforlabel, getlabels, getrel, createrel, deleterel, getrelproperty,
       getrelproperties, updaterelproperties,
       authenticate, updatefewnodeproperties, updatefewrelproperties,
       Connection, Result,
       transaction, rollback, commit

const PROTO = "http"
const HOST = "localhost"
const PORT = 7474
const URI = "/db/data/"
const URL = "$PROTO://$HOST:$PORT$URI"
const USER = ""
const PSWD = ""
const HEADER = Dict{AbstractString,AbstractString}("Accept" => "application/json; charset=UTF-8", "Host" => "$HOST:$PORT")

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
    user::AbstractString
    password::AbstractString
    proto::AbstractString

    url::AbstractString
    header::Dict{AbstractString,AbstractString}
end

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

function Connection(;host="localhost",port=7474,path="/db/data/",user="",password="",proto="http",header=Dict{AbstractString,AbstractString}("Accept" => "application/json; charset=UTF-8", "Host" => "localhost:7474"))
  if user != "" && password != ""
    payload = "$(user):$(password)" |> base64encode
    header["Authorization"] = "Basic $(payload)"
  end
  Connection(host,port,path,user,password,proto,"$proto://$host:$port$path",header)
end


function connurl(c::Connection)
  #"$(c.proto)://$(c.host):$(c.port)$(c.path)"
  c.url
end

function connurl(c::Connection, suffix::AbstractString)
  url = connurl(c)
  "$(url)$(suffix)"
end

function connheaders(c::Connection)
  # headers = Dict(
  #   "Accept" => "application/json; charset=UTF-8",
  #   "Host" => "$(c.host):$(c.port)")
  # if c.user != "" && c.password != ""
  #   payload = "$(c.user):$(c.password)" |> base64encode
  #   headers["Authorization"] = "Basic $(payload)"
  # end
  # headers
  c.header
end

# ----------
# Statements
# ----------

immutable Statement
  statement::AbstractString
  parameters::Dict
end

# -------
# Results
# -------

immutable Result
  results::Vector
  errors::Vector
end

# ------------
# Transactions
# ------------

include("transactions.jl")

# depreciated, not needed
function authenticate(conn::Connection)

    pwdstring = string(conn.user,":",conn.password)
    rqst = string(conn.proto,"://",$pwdstring,"@",conn.host,":",conn.port)
    resp = get(rqst; headers=HEADERS)

    if resp.status == 401
        error("Authorization unsuccessful: $(resp.status)")
    end
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end

    # Append usrname:passwd in Base64 to headers for Basic Authentication
    authstring = base64encode(pwdstring)
    get!(HEADERS,"Authorization","Basic $authstring")
end



function getgraph(conn::Connection)
    resp = get(conn.url; headers=conn.header)
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    Graph(json(resp), conn)
end

function getgraph(user::ASCIIString,password::ASCIIString)
    conn = Connection(user=user,password=password)
    resp = get(conn.url; headers=conn.header)
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    Graph(json(resp), conn)
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

function request(url::AbstractString, method::Function, exp_code::Int,
                 headers::Dict{AbstractString,AbstractString}=DEFAULT_HEADERS; json::JSONData=nothing,
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
        respdata = json(resp)
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
    header = graph.connection.header
    resp = request(graph.node, post, 201,header; json=props)
    Node(json(resp), graph)
end

function getnode(graph::Graph, id::Int)
    header = graph.connection.header
    url = "$(graph.node)/$id"
    resp = request(url, get, 200,header)
    Node(json(resp), graph)
end

function getnode(node::Node)
    getnode(node.graph, node.id)
end

function deletenode(node::Node)
    header = node.graph.connection.header
    request(node.self, delete, 204,header)
end

function deletenode(graph::Graph, id::Int)
    node = getnode(graph, id)
    deletenode(node)
end

function setnodeproperty(node::Node, name::AbstractString, value::Any)
    header = node.graph.connection.header
    url = replace(node.property, "{key}", name)
    request(url, put, 204,header; json=value)
end

function setnodeproperty(graph::Graph, id::Int, name::AbstractString, value::Any)
    node = getnode(graph, id)
    setnodeproperty(node, name, value)
end


function updatefewnodeproperties(graph::Graph, id::Int, props::JSONObject)
  header =  graph.connection.header
  node = getnode(graph,id)
  for prop in keys(props)
    url = replace(node.property, "{key}", prop)
    request(url, put, 204,header; json=props[prop])
  end
end

function updatefewnodeproperties(node::Node, props::JSONObject)
  header =  node.graph.connection.header
  for prop in keys(props)
    url = replace(node.property, "{key}", prop)
    request(url, put, 204,header; json=props[prop])
  end
end


function updatenodeproperties(node::Node, props::JSONObject)
    # it is an overwrite: this will erase all old properties and writes new ones
    # Neo4j API specifies the same:
    header =  node.graph.connection.header
    resp = request(node.properties, put, 204,header; json=props)
end

function getnodeproperty(node::Node, name::AbstractString)
    header =  node.graph.connection.header
    url = replace(node.property, "{key}", name)
    resp = request(url, get, 200,header)
    json(resp)
end

function getnodeproperties(node::Node)
    header =  node.graph.connection.header
    resp = request(node.properties, get, 200,header)
    json(resp)
end

function getnodeproperties(graph::Graph, id::Int)
    node = getnode(graph, id)
    getnodeproperties(node)
end

function deletenodeproperties(node::Node)
    header =  node.graph.connection.header
    request(node.properties, delete, 204,header)
end

function deletenodeproperty(node::Node, name::AbstractString)
    header =  node.graph.connection.header
    url = replace(node.property, "{key}", name)
    request(url, delete, 204,header)
end

function addnodelabel(node::Node, label::AbstractString)
    header =  node.graph.connection.header
    request(node.labels, post, 204,header; json=label)
end

function addnodelabels(node::Node, labels::JSONArray)
    header =  node.graph.connection.header
    request(node.labels, post, 204,header; json=labels)
end

function updatenodelabels(node::Node, labels::JSONArray)
    header =  node.graph.connection.header
    request(node.labels, put, 204,header; json=labels)
end

function deletenodelabel(node::Node, label::AbstractString)
    header =  node.graph.connection.header
    url = "$(node.labels)/$label"
    request(url, delete, 204,header)
end

function getnodelabels(node::Node)
    header =  node.graph.connection.header
    resp = request(node.labels, get, 200,header)
    json(resp)
end

function getnodesforlabel(graph::Graph, label::AbstractString, props::JSONObject=nothing)
    # TODO Shouldn't this url be available in the api somewhere?
    header =  graph.connection.header
    url = "$(graph.connection.url)label/$label/nodes"
    resp = request(url, get, 200,header; query=props)
    [Node(nodedata, graph) for nodedata = json(resp)]
end

function getlabels(graph::Graph)
    header =  graph.connection.header
    resp = request(graph.node_labels, get, 200,header)
    json(resp)
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
    header =  graph.connection.header
    url = "$(graph.relationship)/$id"
    resp = request(url, get, 200,header)
    Relationship(json(resp), graph)
end

function createrel(from::Node, to::Node, reltype::AbstractString; props::JSONObject=nothing)
    body = Dict{AbstractString,Any}("to" => to.self, "type" => uppercase(reltype))
    if props !== nothing
        body["data"] = props
    end
    header =  from.graph.connection.header
    resp = request(from.create_relationship, post, 201,header; json=body)
    Relationship(json(resp), from.graph)
end

function deleterel(rel::Relationship)
    header =  rel.graph.connection.header
    request(rel.self, delete, 204,header)
end

function getrelproperty(rel::Relationship, name::AbstractString)
    header =  rel.graph.connection.header
    url = replace(rel.property, "{key}", name)
    resp = request(url, get, 200,header)
    json(resp)
end

function getrelproperties(rel::Relationship)
    header =  rel.graph.connection.header
    resp = request(rel.properties, get, 200,header)
    json(resp)
end

# TBD
function updatefewrelproperties(rel::Relationship, props::JSONObject)
    # loop through all properties one at-a-time and update each of them
    header =  rel.graph.connection.header
    for prop in keys(props)
      url = replace(rel.property, "{key}", prop)
      request(url, put, 204,header; json=props[prop])
    end
end

function updaterelproperties(rel::Relationship, props::JSONObject)
    # the following is basically overwrite (a misnomer and Neo4j API calls it the same way).
    # ALL old property fields will be erased and new ones are written back
    header =  rel.graph.connection.header
    request(rel.properties, put, 204,header; json=props)
end



end # module
