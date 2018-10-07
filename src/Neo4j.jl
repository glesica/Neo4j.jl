module Neo4j

using HTTP
using JSON
using DocStringExtensions
using Base64

export getgraph, version, createnode, getnode, deletenode, setnodeproperty, getnodeproperty,
       getnodeproperties, updatenodeproperties, deletenodeproperties, deletenodeproperty,
       addnodelabel, addnodelabels, updatenodelabels, deletenodelabel, getnodelabels,
       getnodesforlabel, getlabels, getrel, getrels, getneighbors, createrel, deleterel, getrelproperty,
       getrelproperties, updaterelproperties, cypherQuery
export Connection, Result

const DEFAULT_HOST = "localhost"
const DEFAULT_PORT = 7474
const DEFAULT_URI = "/db/data/"

const JSONObject{T <: AbstractString} = Union{Dict{T,Any},Nothing}  # UTF8String
const JSONArray = Union{Vector,Nothing}
const JSONData{T <: AbstractString} = Union{JSONObject,JSONArray,T,Number,Nothing}

const QueryData = Union{Dict{Any,Any},Nothing}

# ----------
# Connection
# ----------

"""
   Connection()

### Examples
```julia-repl
julia> con = Neo4j.Connection("localhost")
Neo4j.Connection(false, "localhost", 7474, "/db/data/", "http://localhost:7474/db/data/", "", "")
```
"""
struct Connection
   host::AbstractString #UTF8String
   tls::Bool
   port::Int
   path::AbstractString #UTF8String
   url::AbstractString #UTF8String
   user::AbstractString #UTF8String
   password::AbstractString #UTF8String

   Connection(host::T; port = DEFAULT_PORT, path = DEFAULT_URI, tls = false, user = "", password = "") where {T <: AbstractString} =
      new(string(host), tls, port, string(path), string("http://$host:$port$path"), string(user), string(password))
   Connection() = Connection(DEFAULT_HOST)
end

function connurl(c::Connection)
  proto = ifelse(c.tls, "https", "http")
  "$(proto)://$(c.host):$(c.port)$(c.path)"
end

function connurl(c::Connection, suffix::T) where {T <: AbstractString}
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

struct Graph
    # TODO extensions
    node::AbstractString                  #UTF8String
    node_index::AbstractString            #UTF8String
    relationship_index::AbstractString    #UTF8String
    extensions_info::AbstractString       #UTF8String
    relationship_types::AbstractString    #UTF8String
    batch::AbstractString                 #UTF8String
    cypher::AbstractString                #UTF8String
    indexes::AbstractString               #UTF8String
    constraints::AbstractString           #UTF8String
    transaction::AbstractString           #UTF8String
    node_labels::AbstractString           #UTF8String
    version::AbstractString               #UTF8String
    connection::Connection
    relationship::AbstractString          #UTF8String # Not in the spec
end

# UTF8String
Graph(data::Dict{T,Any}, conn::Connection) where {T <: AbstractString} = Graph(data["node"], data["node_index"], data["relationship_index"],
    data["extensions_info"], data["relationship_types"], data["batch"], data["cypher"], data["indexes"],
    data["constraints"], data["transaction"], data["node_labels"], data["neo4j_version"], conn,
    "$(conn.url)relationship")

function getgraph(conn::Connection)
    resp = HTTP.get(conn.url; headers=connheaders(conn))
    if resp.status != 200
        error("Connection to server unsuccessful: $(resp.status)")
    end
    Graph(Dict{AbstractString,Any}(JSON.parse(String(resp.body))), conn) # UTF8String
end

function getgraph()
    getgraph(Connection())
end

# ----
# Node
# ----

struct Node
    # TODO extensions
    paged_traverse::AbstractString #UTF8String
    labels::AbstractString #UTF8String
    outgoing_relationships::AbstractString #UTF8String
    traverse::AbstractString #UTF8String
    all_typed_relationships::AbstractString #UTF8String
    all_relationships::AbstractString #UTF8String
    property::AbstractString #UTF8String
    self::AbstractString #UTF8String
    outgoing_typed_relationships::AbstractString #UTF8String
    properties::AbstractString #UTF8String
    incoming_relationships::AbstractString #UTF8String
    incoming_typed_relationships::AbstractString #UTF8String
    create_relationship::AbstractString #UTF8String
    data::JSONObject
    metadata::Dict{AbstractString, Any} #UTF8String
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
         split(data["self"], "/")[end] |> Meta.parse, graph)
end

# ----------
# Statements
# ----------

struct Statement
  statement::AbstractString
  parameters::Dict
end

# -------
# Results
# -------

struct Result
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
                 headers::Dict{T, T}; jsonDict::JSONData = nothing,
                 query::QueryData = nothing)::AbstractString where {T <: AbstractString}
    resp = nothing
    try
        # Simplified to a single call
        body = jsonDict != nothing ? JSON.json(jsonDict) : ""
        resp = method(url; headers = headers, body=body, query=query)
    catch ex
        # Handle status errors specifically.
        if ex isa HTTP.ExceptionRequest.StatusError
            resp = ex.response
        else
            rethrow(ex)
        end
    finally
        if resp.status != exp_code
            respdata = JSON.parse(String(resp.body))
            if respdata !== nothing && "message" in keys(respdata)
                error("Neo4j error: $(respdata["message"])")
            else
                error("Neo4j error: $(url) returned $(resp.status)")
            end
        end
        # Great, return the response body
        return String(resp.body)
    end
end

# -----------------
# External requests
# -----------------

function createnode(graph::Graph, props::JSONData = nothing)
    resp = request(graph.node, HTTP.post, 201, connheaders(graph.connection); jsonDict=props)
    jsrsp = Dict{AbstractString,Any}(JSON.parse(resp)) # UTF8String
    # @show typeof(jsrsp)
    Node(jsrsp, graph)
end

function getnode(graph::Graph, id::Int)
    url = "$(graph.node)/$id"
    resp = request(url, HTTP.get, 200, connheaders(graph.connection))
    Node(Dict{AbstractString,Any}(JSON.parse(resp)), graph) # UTF8String
end

function getnode(node::Node)
    getnode(node.graph, node.id)
end

function deletenode(node::Node)
    request(node.self, HTTP.delete, 204, connheaders(node.graph.connection))
end

function deletenode(graph::Graph, id::Int)
    node = getnode(graph, id)
    deletenode(node)
end

function setnodeproperty(node::Node, name::T, value::Any) where {T <: AbstractString}
    url = replace(node.property, "{key}" => name)
    request(url, HTTP.put, 204, connheaders(node.graph.connection); jsonDict=value)
end

function setnodeproperty(graph::Graph, id::Int, name::T, value::Any) where {T <: AbstractString}
    node = getnode(graph, id)
    setnodeproperty(node, name, value)
end

function updatenodeproperties(node::Node, props::JSONObject)
    resp = request(node.properties, HTTP.put, 204, connheaders(node.graph.connection); jsonDict=props)
end

function getnodeproperty(node::Node, name::T) where {T <: AbstractString}
    url = replace(node.property, "{key}" => name)
    resp = request(url, HTTP.get, 200, connheaders(node.graph.connection))
    JSON.parse(resp)
end

function getnodeproperties(node::Node)
    resp = request(node.properties, HTTP.get, 200, connheaders(node.graph.connection))
    JSON.parse(resp)
end

function getnodeproperties(graph::Graph, id::Int)
    node = getnode(graph, id)
    getnodeproperties(node)
end

function deletenodeproperties(node::Node)
    request(node.properties, HTTP.delete, 204, connheaders(node.graph.connection))
end

function deletenodeproperty(node::Node, name::T) where {T <: AbstractString}
    url = replace(node.property, "{key}" => name)
    request(url, HTTP.delete, 204, connheaders(node.graph.connection))
end

function addnodelabel(node::Node, label::T) where {T <: AbstractString}
    request(node.labels, HTTP.post, 204, connheaders(node.graph.connection); jsonDict=label)
end

function addnodelabels(node::Node, labels::JSONArray)
    request(node.labels, HTTP.post, 204, connheaders(node.graph.connection); jsonDict=labels)
end

function updatenodelabels(node::Node, labels::JSONArray)
    request(node.labels, HTTP.put, 204, connheaders(node.graph.connection); jsonDict=labels)
end

function deletenodelabel(node::Node, label::T) where {T <: AbstractString}
    url = "$(node.labels)/$label"
    request(url, HTTP.delete, 204, connheaders(node.graph.connection))
end

function getnodelabels(node::Node)
    resp = request(node.labels, HTTP.get, 200, connheaders(node.graph.connection))
    JSON.parse(resp)
end

function getnodesforlabel(graph::Graph, label::T, props::JSONObject=nothing) where {T <: AbstractString}
    # TODO Shouldn't this url be available in the api somewhere?
    url = "$(graph.connection.url)label/$label/nodes"
    resp = request(url, HTTP.get, 200, connheaders(graph.connection); query=props)
    [Node(Dict{AbstractString,Any}(nodedata), graph) for nodedata = JSON.parse(resp)]
end

function getlabels(graph::Graph)
    resp = request(graph.node_labels, HTTP.get, 200, connheaders(graph.connection))
    JSON.parse(resp)
end

# -------------
# Relationships
# -------------

struct Relationship
    relstart::AbstractString #UTF8String
    property::AbstractString #UTF8String
    self::AbstractString #UTF8String
    properties::AbstractString #UTF8String
    metadata::Dict{AbstractString ,Any} #UTF8String
    reltype::AbstractString #UTF8String
    relend::AbstractString #UTF8String
    data::JSONObject
    id::Int
    graph::Graph
end

Relationship(data::JSONObject, graph::Graph) = Relationship(data["start"], data["property"],
        data["self"], data["properties"], data["metadata"], data["type"], data["end"], data["data"],
        split(data["self"], "/")[end] |> Meta.parse, graph)

function getrels(node::Node; incoming::Bool = true, outgoing::Bool = true)
  rels = Vector{Relationship}()
  if(incoming)
    resp = request(node.incoming_relationships, HTTP.get, 200, connheaders(node.graph.connection))
    for rel=JSON.parse(resp)
      push!(rels, Relationship(Dict{AbstractString,Any}(rel), node.graph)) #UTF8String
    end
  end
  if(outgoing)
    resp = request(node.outgoing_relationships, HTTP.get, 200, connheaders(node.graph.connection))
    for rel=JSON.parse(resp)
      push!(rels, Relationship(Dict{AbstractString,Any}(rel), node.graph)) #UTF8String
    end
  end
  rels
end

function getneighbors(node::Node; incoming::Bool = true, outgoing::Bool = true)
  neighbors = Vector{Node}()

  # Do incoming
  if(incoming)
    rels = getrels(node, incoming = true, outgoing = false)
    for rel=rels
      resp = request(rel.relstart, HTTP.get, 200, connheaders(node.graph.connection))
      push!(neighbors, Node(Dict{AbstractString,Any}(JSON.parse(resp)), node.graph))  # UTF8String
    end
  end
  if(outgoing)
    rels = getrels(node, incoming = false, outgoing = true)
    for rel=rels
      resp = request(rel.relend, HTTP.get, 200, connheaders(node.graph.connection))
      push!(neighbors, Node(Dict{AbstractString,Any}(JSON.parse(resp)), node.graph))  # UTF8String
    end
  end
  neighbors
end

function getrel(graph::Graph, id::Int)
    url = "$(graph.relationship)/$id"
    resp = request(url, HTTP.get, 200, connheaders(graph.connection))
    Relationship(Dict{AbstractString,Any}(JSON.parse(resp)), graph)  # UTF8String
end

function createrel(from::Node, to::Node, reltype::AbstractString; props::JSONObject=nothing)
    body = Dict{AbstractString, Any}("to" => to.self, "type" => uppercase(reltype)) # UTF8String
    if props !== nothing
        body["data"] = props
    end
    resp = request(from.create_relationship, HTTP.post, 201, connheaders(from.graph.connection), jsonDict=body)
    Relationship(Dict{AbstractString,Any}(JSON.parse(resp)), from.graph) # UTF8String
end

function deleterel(rel::Relationship)
    request(rel.self, HTTP.delete, 204, connheaders(rel.graph.connection))
end

function getrelproperty(rel::Relationship, name::AbstractString)
    url = replace(rel.property, "{key}" => name)
    resp = request(url, HTTP.get, 200, connheaders(rel.graph.connection))
    JSON.parse(resp)
end

function getrelproperties(rel::Relationship)
    resp = request(rel.properties, HTTP.get, 200, connheaders(rel.graph.connection))
    JSON.parse(resp)
end

function updaterelproperties(rel::Relationship, props::JSONObject)
    request(rel.properties, HTTP.put, 204, connheaders(rel.graph.connection); jsonDict=props)
end

# ------------
# Cypher query
# ------------
include("cypherQuery.jl")

end # module
