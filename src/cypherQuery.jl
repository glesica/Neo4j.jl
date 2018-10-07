
using DataFrames, Missings;

"""
   $(SIGNATURES)

Retrieve molecular identifier from other databases, `targetDb`, for single or mulitple query IDs, `queryId`,
and moreover information on Ensembl gene, transcript and peptide IDs, such as ID and genomic loation.

### Arguments
- `conn::Neo4j.Connection` : a valid connection to a Neo4j graph DB instance.
- `cypher::String` : Cypher `MATCH` query returning tabular data.
- `params::Pair` : parameters which are passed on to the cypher query.
- `elTypes::Vector{Type}` : column types can be provided manually as a Vector{Type}
- `nRowsElTypeCheck::Int` : Number of rows which are used to determine column datatypes (defaults to 1000)

### Examples
```julia-repl
julia> cypherQuery(
         Neo4j.Connection("localhost"),
         "MATCH (p :Person {name: {name}}) RETURN p.name AS Name, p.age AS Age;",
         "name" => "John Doe")

```
"""
function cypherQuery(
      conn::Connection,
      cypher::AbstractString,
      params::Pair...;
      elTypes::Vector{DataType} = Vector{DataType}(),
      nRowsElTypeCheck::Int = 1000)::DataFrames.DataFrame

   url = connurl(conn, "transaction/commit")
   headers = connheaders(conn)
   body = Dict("statements" => [Statement(cypher, Dict(params))])

   resp = HTTP.post(url; headers=headers, body=JSON.json(body))

   if resp.status != 200
     error("Failed to commit transaction ($(resp.status)): $(txn)\n$(resp)")
   end
   respdata = JSON.parse(String(resp.body))

   if !isempty(respdata["errors"])
      error(join(map(i -> (i * ": " * respdata["errors"][1][i]), keys(respdata["errors"][1])), "\n"));
   end
   # parse results into data sink
   # Result(respdata["results"], respdata["errors"])
   if !isempty(respdata["results"][1]["data"])
      return parseResults(respdata["results"][1], elTypes = elTypes, nRowsElTypeCheck = nRowsElTypeCheck);
   else
      return DataFrames.DataFrame();
   end
end

# Currently only supports DataFrames.DataFrame objects
#  -> Future: Allow different data sink types, such as tables from JuliaDB
function parseResults(res::Dict{String, Any}; elTypes::Vector{DataType} = Vector(), nRowsElTypeCheck::Int = 100)::DataFrames.DataFrame
   # Get elementary types from a column where there is no NA value (nothing)
   if isempty(elTypes)
      elTypes = getElTypes(res["data"], nRowsElTypeCheck);
   end
   colNames = Symbol.(collect(res["columns"])) # collect(Symbol, res["columns"]);
   nRows = length(res["data"]);

   x = DataFrames.DataFrame(elTypes, colNames, nRows);

   for (rowIdx, rowVal) in enumerate(res["data"])
      for (colIdx,colVal) in enumerate(rowVal["row"])
         if colVal != nothing
            x[rowIdx,colIdx] = colVal;
         end
      end
   end

   return x;
end

function getElTypes(x::Vector{Any}, nRowsElTypeCheck::Int = 0)::Vector{Type}
   nRecords = length(x);
   elTypes::Vector{Type} = Type[Union{Nothing, Missings.Missing} for i in 1:length(x[1]["row"])];
   nMaxRows = nRecords;
   # elTypes = Type[Union{Nothing, Missings.Missing} for i in 1:length(x[1]["row"])];
   nMaxRows = (nRowsElTypeCheck != 0 && nRowsElTypeCheck <= nMaxRows) ? nRowsElTypeCheck : nRecords;
   checkIdx = trues(length(x[1]["row"]));
   for i in 1:nMaxRows
      # check each column individually
      for el in findall(checkIdx)
         if !(x[i]["row"][el] == nothing)
            if !(typeof(x[i]["row"][el]) === Array{Any,1})
               elTypes[el] = i > 1 ?
                     Union{typeof(x[i]["row"][el]), Missings.Missing} :
                     typeof(x[i]["row"][el]);
            else
               elTypes[el] = i > 1 ?
                     Union{Vector{typeof(x[i]["row"][el][1])}, Missings.Missing} :
                     Vector{typeof(x[i]["row"][el][1])};
            end
            checkIdx[el] = false;
         end
      end
      if isempty(findall(checkIdx))
         break;
      end
   end

   return elTypes;
end
