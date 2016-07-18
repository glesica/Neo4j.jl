module Neo4j

using Requests
using JSON
import Base.convert

export getgraph, version, createnode, getnode, deletenode, setnodeproperty, getnodeproperty,
       getnodeproperties, updatenodeproperties, deletenodeproperties, deletenodeproperty,
       addnodelabel, addnodelabels, updatenodelabels, deletenodelabel, getnodelabels,
       getnodesforlabel, getlabels, getrel, getrels, getneighbors, createrel, deleterel, getrelproperty,
       getrelproperties, updaterelproperties, convert
export Connection, Result

const DEFAULT_HOST = "localhost"
const DEFAULT_PORT = 7474
const DEFAULT_URI = "/db/data/"

typealias JSONObject Union{Dict{UTF8String,Any},Void}
typealias JSONArray Union{Vector,Void}
typealias JSONData Union{JSONObject,JSONArray,AbstractString,Number,Void}

typealias QueryData Union{Dict{Any,Any},Void}

# ----------
# Connection
# ----------

immutable Connection
  tls::Bool
  host::UTF8String
  port::Int
  path::UTF8String
  url::UTF8String
  user::UTF8String
  password::UTF8String

  Connection(host::AbstractString; port=DEFAULT_PORT, path=DEFAULT_URI, tls=false, user="", password="") = new(tls, utf8(host), port, utf8(path), utf8("http://$host:$port$path"), utf8(user), utf8(password))
  Connection() = new(DEFAULT_HOST)
end

function connurl(c::Connection)
  proto = ifelse(c.tls, "https", "http")
  "$(proto)://$(c.host):$(c.port)$(c.path)"
end

function connurl(c::Connection, suffix::AbstractString)
  url = connurl(c)
  "$(url)$(suffix)"
end

function connheaders(c::Connection)
  headers = Dict(
    "Accept" => "application/json; charset=UTF-8",
    "Host" => "$(c.host):$(c.port)")
  if c.user != "" && c.password != ""
    payload = "$(c.user):$(c.password)" |> base64encode
    headers["Authorization"] = "Basic $(payload)"
  end
  headers
end

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
    resp = get(conn.url; headers=connheaders(conn))
    if resp.status !== 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    #Note the Requests lib returns UTF8String, so lets just use that as a standard for REST calls [GearsAD]
    # @show typeof(Requests.json(resp))
    Graph(Dict{UTF8String,Any}(Requests.json(resp)), conn)
end

function getgraph()
    getgraph(Connection())
end

# ----
# Node
# ----

immutable Node
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
    metadata::Dict{UTF8String,Any}
    id::Int64
    graph::Graph

    #Constructors
    Node() = new()
    Node(data::JSONObject, graph::Graph) = new(data["paged_traverse"], data["labels"],
         data["outgoing_relationships"], data["traverse"], data["all_typed_relationships"],
         data["all_relationships"], data["property"],
         data["self"], data["outgoing_typed_relationships"], data["properties"],
         data["incoming_relationships"], data["incoming_typed_relationships"],
         data["create_relationship"], data["data"], data["metadata"],
         split(data["self"], "/")[end] |> parse, graph)
end

function convert(::Type{Union{Dict{UTF8String,Any},Void}}, d::Dict{AbstractString,Any})
  return Dict{UTF8String, Any}(d)
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

include("transaction.jl")

# --------
# Requests
# --------

function request(url::AbstractString, method::Function, exp_code::Int,
                 headers::Dict{ASCIIString,ASCIIString}; json::JSONData=nothing,
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
    resp = request(graph.node, Requests.post, 201, connheaders(graph.connection); json=props)
    jsrsp = Dict{UTF8String,Any}(Requests.json(resp))
    # @show typeof(jsrsp)
    Node(jsrsp, graph)
end

function getnode(graph::Graph, id::Int)
    url = "$(graph.node)/$id"
    resp = request(url, Requests.get, 200, connheaders(graph.connection))
    Node(Dict{UTF8String,Any}(Requests.json(resp)), graph)
end

function getnode(node::Node)
    getnode(node.graph, node.id)
end

function deletenode(node::Node)
    request(node.self, Requests.delete, 204, connheaders(node.graph.connection))
end

function deletenode(graph::Graph, id::Int)
    node = getnode(graph, id)
    deletenode(node)
end

function setnodeproperty(node::Node, name::AbstractString, value::Any)
    url = replace(node.property, "{key}", name)
    request(url, Requests.put, 204, connheaders(node.graph.connection); json=value)
end

function setnodeproperty(graph::Graph, id::Int, name::AbstractString, value::Any)
    node = getnode(graph, id)
    setnodeproperty(node, name, value)
end

function updatenodeproperties(node::Node, props::JSONObject)
    resp = request(node.properties, Requests.put, 204, connheaders(node.graph.connection); json=props)
end

function getnodeproperty(node::Node, name::AbstractString)
    url = replace(node.property, "{key}", name)
    resp = request(url, Requests.get, 200, connheaders(node.graph.connection))
    Requests.json(resp)
end

function getnodeproperties(node::Node)
    resp = request(node.properties, Requests.get, 200, connheaders(node.graph.connection))
    Requests.json(resp)
end

function getnodeproperties(graph::Graph, id::Int)
    node = getnode(graph, id)
    getnodeproperties(node)
end

function deletenodeproperties(node::Node)
    request(node.properties, Requests.delete, 204, connheaders(node.graph.connection))
end

function deletenodeproperty(node::Node, name::AbstractString)
    url = replace(node.property, "{key}", name)
    request(url, Requests.delete, 204, connheaders(node.graph.connection))
end

function addnodelabel(node::Node, label::AbstractString)
    request(node.labels, Requests.post, 204, connheaders(node.graph.connection); json=label)
end

function addnodelabels(node::Node, labels::JSONArray)
    request(node.labels, Requests.post, 204, connheaders(node.graph.connection); json=labels)
end

function updatenodelabels(node::Node, labels::JSONArray)
    request(node.labels, Requests.put, 204, connheaders(node.graph.connection); json=labels)
end

function deletenodelabel(node::Node, label::AbstractString)
    url = "$(node.labels)/$label"
    request(url, Requests.delete, 204, connheaders(node.graph.connection))
end

function getnodelabels(node::Node)
    resp = request(node.labels, Requests.get, 200, connheaders(node.graph.connection))
    Requests.json(resp)
end

function getnodesforlabel(graph::Graph, label::AbstractString, props::JSONObject=nothing)
    # TODO Shouldn't this url be available in the api somewhere?
    url = "$(graph.connection.url)label/$label/nodes"
    resp = request(url, Requests.get, 200, connheaders(graph.connection); query=props)
    [Node(Dict{UTF8String,Any}(nodedata), graph) for nodedata = Requests.json(resp)]
end

function getlabels(graph::Graph)
    resp = request(graph.node_labels, Requests.get, 200, connheaders(graph.connection))
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
    metadata::Dict{UTF8String,Any}
    reltype::UTF8String
    relend::UTF8String
    data::JSONObject
    id::Int
    graph::Graph
end

Relationship(data::JSONObject, graph::Graph) = Relationship(data["start"], data["property"],
        data["self"], data["properties"], data["metadata"], data["type"], data["end"], data["data"],
        split(data["self"], "/")[end] |> parse, graph)

function getrels(node::Node; incoming::Bool=true, outgoing::Bool=true)
  rels = Vector{Relationship}()
  if(incoming)
    resp = request(node.incoming_relationships, Requests.get, 200, connheaders(node.graph.connection))
    for rel=Requests.json(resp)
      push!(rels, Relationship(Dict{UTF8String,Any}(rel), node.graph))
    end
  end
  if(outgoing)
    resp = request(node.outgoing_relationships, Requests.get, 200, connheaders(node.graph.connection))
    for rel=Requests.json(resp)
      push!(rels, Relationship(Dict{UTF8String,Any}(rel), node.graph))
    end
  end
  rels
end

function getneighbors(node::Node; incoming::Bool=true, outgoing::Bool=true)
  neighbors = Vector{Node}()

  # Do incoming
  if(incoming)
    rels = getrels(node, incoming=true, outgoing=false)
    for rel=rels
      resp = request(rel.relstart, Requests.get, 200, connheaders(node.graph.connection))
      push!(neighbors, Node(Dict{UTF8String,Any}(Requests.json(resp)), node.graph))
    end
  end
  if(outgoing)
    rels = getrels(node, incoming=false, outgoing=true)
    for rel=rels
      resp = request(rel.relend, Requests.get, 200, connheaders(node.graph.connection))
      push!(neighbors, Node(Dict{UTF8String,Any}(Requests.json(resp)), node.graph))
    end
  end
  neighbors
end

function getrel(graph::Graph, id::Int)
    url = "$(graph.relationship)/$id"
    resp = request(url, Requests.get, 200, connheaders(graph.connection))
    Relationship(Dict{UTF8String,Any}(Requests.json(resp)), graph)
end

function createrel(from::Node, to::Node, reltype::AbstractString; props::JSONObject=nothing)
    body = Dict{UTF8String, Any}("to" => to.self, "type" => uppercase(reltype))
    if props !== nothing
        body["data"] = props
    end
    resp = request(from.create_relationship, Requests.post, 201, connheaders(from.graph.connection), json=body)
    Relationship(Dict{UTF8String,Any}(Requests.json(resp)), from.graph)
end

function deleterel(rel::Relationship)
    request(rel.self, Requests.delete, 204, connheaders(rel.graph.connection))
end

function getrelproperty(rel::Relationship, name::AbstractString)
    url = replace(rel.property, "{key}", name)
    resp = request(url, Requests.get, 200, connheaders(rel.graph.connection))
    Requests.json(resp)
end

function getrelproperties(rel::Relationship)
    resp = request(rel.properties, Requests.get, 200, connheaders(rel.graph.connection))
    Requests.json(resp)
end

function updaterelproperties(rel::Relationship, props::JSONObject)
    request(rel.properties, Requests.put, 204, connheaders(rel.graph.connection); json=props)
end

end # module
