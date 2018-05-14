

function cypherQuery(
      conn::Connection, 
      cypher::AbstractString, 
      params::Pair...;
      elTypes::Vector{Type} = Vector{Type}(),
      nRowsElTypeCheck::Int = 0)
   
   url = connurl(conn, "transaction/commit")
   headers = connheaders(conn)
   body = Dict("statements" => [Statement(cypher, Dict(params))])
 
   resp = Requests.post(url; headers=headers, json=body)
 
   if resp.status != 200
     error("Failed to commit transaction ($(resp.status)): $(txn)\n$(resp)")
   end
   respdata = Requests.json(resp)
 
   # parse results into data sink
   result = parseResults(respdata["results"][1], nRowsElTypeCheck);
   # Result(respdata["results"], respdata["errors"])

   return result;
end

# Currently only supports DataFrames.DataFrame objects
#  -> Future: Allow different data sink types, such as tables from JuliaDB
function parseResults(res::Dict{String, Any}, nRows::Int)
   # Get elementary types from a column where there is no NA value (nothing)
   elTypes = getElTypes(res["data"], nRows);
   colNames = collect(Symbol, res["columns"]);
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

function getElTypes(x::Vector{Any}, nRows::Int)
   nRecords = length(x);
   elTypes::Vector{Type} = Type[Union{Void, Missings.Missing} for i in 1:length(x[1]["row"])];
   elTypes = Type[Union{Void, Missings.Missing} for i in 1:length(x[1]["row"])];
   # for now simple, later maybe for each column individually
   nMaxRows = (nRows != 0 && nRows < nMaxRows) ? nRows : nRecords;
   checkIdx = trues(length(x[1]["row"]));
   for i in 1:nMaxRows
      # if !any(map(i->i == nothing, x[i]["row"]))
         # check each column individually
         for el in find(checkIdx)
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
         # elTypes = map(i->Union{typeof(i)}, x[i]["row"]);
         if isempty(find(checkIdx))
            break;
         end
      # end
   end
   # if any(getfield.(elTypes, :a) .=== Void)
   #    # warn("one or more columns only contain NA values");
   #    elTypes = map(i->Union{typeof(i),Missings.Missing}, x[1]["row"]);
   #    elTypes[elTypes .== Void] = Union{Void, Missings.Missing};
   # end
   return elTypes;
end