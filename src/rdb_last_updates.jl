"""
    rdb_last_updates(
        all_updates::Bool = false;
        use_readlines::Bool = DBnomics.use_readlines,
        curl_config::Union{Nothing, Dict, NamedTuple} = DBnomics.curl_config,
        kwargs...
    )

`rdb_last_updates` downloads informations about the last updates from
[DBnomics](https://db.nomics.world/)

By default, the function returns a `DataFrame`
containing the last 100 updates from
[DBnomics](https://db.nomics.world/) with additional informations.

# Arguments
- `all_updates::Bool = false`: If `true`, then the full dataset of the last updates
  is retrieved.
- `use_readlines::Bool = DBnomics.use_readlines`: (default `false`) If `true`, then
  the data are requested and read with the function `readlines`.
- `curl_config::Union{Nothing, Dict, NamedTuple} = DBnomics.curl_config`: (default `nothing`)
  If not `nothing`, it is used to configure a proxy connection. This
  configuration is passed to the keyword arguments of the function `HTTP.get` of
  the package **HTTP.jl**.
- `kwargs...`: Keyword arguments to be passed to `HTTP.get`.

# Examples
```jldoctest
julia> rdb_last_updates();

julia> rdb_last_updates(true);

julia> rdb_last_updates(use_readlines = true);

julia> rdb_last_updates(curl_config = Dict(:proxy => "http://<proxy>:<port>"));

# Regarding the functioning of HTTP.jl, you might need to modify another option
# It will change the url from https:// to http://
# (https://github.com/JuliaWeb/HTTP.jl/pull/390)
julia> DBnomics.options("secure", false);
```
"""
function rdb_last_updates(
    all_updates::Bool = false;
    use_readlines::Bool = DBnomics.use_readlines,
    curl_config::Union{Nothing, Dict, NamedTuple} = DBnomics.curl_config,
    kwargs...
)
    if isa(curl_config, Nothing)
        curl_config = kwargs
    end
    
    api_base_url::String = DBnomics.api_base_url
    api_version::Int64 = DBnomics.api_version
    api_link::String = api_base_url * "/v" * string(api_version) * "/last-updates"
    
    updates = get_data(api_link, use_readlines, 0, nothing, nothing; curl_config...)
    
    num_found::Int64 = updates["datasets"]["num_found"]
    limit::Int64 = updates["datasets"]["limit"]
    
    iter::UnitRange{Int64} = 0:0
    if all_updates
        iter = 0:Int(floor(num_found / limit))
    end
    
    if DBnomics.progress_bar_last_updates
        p = ProgressMeter.Progress(length(iter), 1, "Downloading updates...")
    end
    
    updates = map(iter) do u
        api_link = api_base_url * "/v" * string(api_version) *
            "/last-updates?datasets.offset=" * string(Int(u * limit))
                
        tmp_up = get_data(api_link, use_readlines, 0, nothing, nothing; curl_config...)
        tmp_up = tmp_up["datasets"]["docs"]
        tmp_up = to_dict.(tmp_up)
        tmp_up = concatenate_dict(tmp_up)
        change_type!(tmp_up)
        transform_date_timestamp!(tmp_up)
        
        if DBnomics.progress_bar_last_updates
            ProgressMeter.next!(p)
        end
        
        tmp_up
    end
    
    if DBnomics.progress_bar_last_updates
        ProgressMeter.finish!(p)
    end
    
    if isa(updates, Array)
        updates = concatenate_dict(updates)
        change_type!(updates)
    end
    
    df_return(updates)
end
