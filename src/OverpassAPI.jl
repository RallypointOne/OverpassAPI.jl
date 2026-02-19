module OverpassAPI

using HTTP
using JSON3
using GeoInterface
using Extents: Extents, Extent

const GI = GeoInterface

export query, bbox_string, Node, Way, Relation, Member, LatLon, OverpassResponse,
    nodes, ways, relations, DEFAULT_ENDPOINT

#--------------------------------------------------------------------------------# Constants
#--------------------------------------------------------------------------------

"""
    DEFAULT_ENDPOINT

The default Overpass API endpoint: `"https://overpass-api.de/api/interpreter"`.
"""
const DEFAULT_ENDPOINT = "https://overpass-api.de/api/interpreter"

#--------------------------------------------------------------------------------# Types
#--------------------------------------------------------------------------------

"""
    LatLon(lat, lon)

A lightweight latitude/longitude coordinate pair.  Implements `GeoInterface.PointTrait`.

### Examples
```julia
julia> p = LatLon(40.748, -73.985)
LatLon(40.748, -73.985)

julia> GeoInterface.x(p)
-73.985

julia> GeoInterface.y(p)
40.748
```
"""
@kwdef struct LatLon
    lat::Float64
    lon::Float64
end

"""
    Node

An OpenStreetMap node (point feature).  Implements `GeoInterface.PointTrait`.

# Fields
- `id::Int64`: OSM node ID.
- `lat::Float64`: Latitude.
- `lon::Float64`: Longitude.
- `tags::Dict{String,String}`: Key-value tags.

### Examples
```julia
julia> n = Node(id=1, lat=40.748, lon=-73.985, tags=Dict("name" => "Example"))
Node(1, 40.748, -73.985, Dict("name" => "Example"))
```
"""
@kwdef struct Node
    id::Int64
    lat::Float64
    lon::Float64
    tags::Dict{String,String} = Dict{String,String}()
end

"""
    Member

A member of an OSM relation.

# Fields
- `type::String`: Element type (`"node"`, `"way"`, or `"relation"`).
- `ref::Int64`: OSM ID of the referenced element.
- `role::String`: Role within the relation (e.g. `"outer"`, `"inner"`, `"stop"`).
- `geometry::Vector{LatLon}`: Coordinates (populated when query uses `out geom`).

### Examples
```julia
julia> m = Member(type="way", ref=123, role="outer")
Member("way", 123, "outer", LatLon[])
```
"""
@kwdef struct Member
    type::String
    ref::Int64
    role::String = ""
    geometry::Vector{LatLon} = LatLon[]
end

"""
    Way

An OpenStreetMap way (line or polygon feature).  Implements `GeoInterface.LineStringTrait`
when geometry data is available (query uses `out geom`).

# Fields
- `id::Int64`: OSM way ID.
- `tags::Dict{String,String}`: Key-value tags.
- `node_ids::Vector{Int64}`: Ordered list of constituent node IDs.
- `geometry::Vector{LatLon}`: Coordinates (populated when query uses `out geom`).

### Examples
```julia
julia> w = Way(id=1, tags=Dict("highway" => "residential"), node_ids=[1,2,3],
               geometry=[LatLon(40.0,-74.0), LatLon(40.1,-74.1), LatLon(40.2,-74.2)])
```
"""
@kwdef struct Way
    id::Int64
    tags::Dict{String,String} = Dict{String,String}()
    node_ids::Vector{Int64} = Int64[]
    geometry::Vector{LatLon} = LatLon[]
end

"""
    Relation

An OpenStreetMap relation (a group of elements with roles).

# Fields
- `id::Int64`: OSM relation ID.
- `tags::Dict{String,String}`: Key-value tags.
- `members::Vector{Member}`: Ordered list of members.

### Examples
```julia
julia> r = Relation(id=1, tags=Dict("type" => "multipolygon"),
               members=[Member(type="way", ref=100, role="outer")])
```
"""
@kwdef struct Relation
    id::Int64
    tags::Dict{String,String} = Dict{String,String}()
    members::Vector{Member} = Member[]
end

"""
    Element

Union type for all OSM element types: `Union{Node, Way, Relation}`.
"""
const Element = Union{Node, Way, Relation}

"""
    OverpassResponse

The parsed response from an Overpass API query.

# Fields
- `version::Float64`: API version (typically `0.6`).
- `generator::String`: Generator string from the API.
- `timestamp::String`: OSM data timestamp.
- `elements::Vector{Element}`: All returned elements.

### Examples
```julia
julia> r = query("node[amenity=cafe](35.9,-79.1,36.1,-78.8); out geom;")

julia> nodes(r)  # filter to just Node elements

julia> ways(r)   # filter to just Way elements
```
"""
@kwdef struct OverpassResponse
    version::Float64 = 0.6
    generator::String = ""
    timestamp::String = ""
    elements::Vector{Element} = Element[]
end

#--------------------------------------------------------------------------------# Accessors
#--------------------------------------------------------------------------------

"""
    nodes(response::OverpassResponse) -> Vector{Node}

Return all `Node` elements from an `OverpassResponse`.
"""
nodes(r::OverpassResponse) = Node[e for e in r.elements if e isa Node]

"""
    ways(response::OverpassResponse) -> Vector{Way}

Return all `Way` elements from an `OverpassResponse`.
"""
ways(r::OverpassResponse) = Way[e for e in r.elements if e isa Way]

"""
    relations(response::OverpassResponse) -> Vector{Relation}

Return all `Relation` elements from an `OverpassResponse`.
"""
relations(r::OverpassResponse) = Relation[e for e in r.elements if e isa Relation]

# --- Tag access via getindex ---
Base.getindex(n::Node, key::AbstractString) = n.tags[key]
Base.getindex(w::Way, key::AbstractString) = w.tags[key]
Base.getindex(r::Relation, key::AbstractString) = r.tags[key]
Base.get(n::Node, key::AbstractString, default) = get(n.tags, key, default)
Base.get(w::Way, key::AbstractString, default) = get(w.tags, key, default)
Base.get(r::Relation, key::AbstractString, default) = get(r.tags, key, default)
Base.haskey(n::Node, key::AbstractString) = haskey(n.tags, key)
Base.haskey(w::Way, key::AbstractString) = haskey(w.tags, key)
Base.haskey(r::Relation, key::AbstractString) = haskey(r.tags, key)
Base.keys(n::Node) = keys(n.tags)
Base.keys(w::Way) = keys(w.tags)
Base.keys(r::Relation) = keys(r.tags)

# --- OverpassResponse iteration and length ---
Base.length(r::OverpassResponse) = length(r.elements)
Base.iterate(r::OverpassResponse, args...) = iterate(r.elements, args...)
Base.eltype(::Type{OverpassResponse}) = Element

#--------------------------------------------------------------------------------# JSON Parsing
#--------------------------------------------------------------------------------

function parse_tags(obj)::Dict{String,String}
    haskey(obj, :tags) ? Dict{String,String}(String(k) => String(v) for (k, v) in pairs(obj.tags)) : Dict{String,String}()
end

function parse_latlon(obj)::LatLon
    LatLon(lat=Float64(obj.lat), lon=Float64(obj.lon))
end

function parse_geometry(obj)::Vector{LatLon}
    haskey(obj, :geometry) ? LatLon[parse_latlon(p) for p in obj.geometry] : LatLon[]
end

function parse_node(obj)::Node
    Node(
        id = Int64(obj.id),
        lat = Float64(obj.lat),
        lon = Float64(obj.lon),
        tags = parse_tags(obj),
    )
end

function parse_member(obj)::Member
    Member(
        type = String(obj.type),
        ref = Int64(obj.ref),
        role = haskey(obj, :role) ? String(obj.role) : "",
        geometry = parse_geometry(obj),
    )
end

function parse_way(obj)::Way
    Way(
        id = Int64(obj.id),
        tags = parse_tags(obj),
        node_ids = haskey(obj, :nodes) ? Int64[Int64(n) for n in obj.nodes] : Int64[],
        geometry = parse_geometry(obj),
    )
end

function parse_relation(obj)::Relation
    Relation(
        id = Int64(obj.id),
        tags = parse_tags(obj),
        members = haskey(obj, :members) ? Member[parse_member(m) for m in obj.members] : Member[],
    )
end

function parse_element(obj)::Element
    t = String(obj.type)
    if t == "node"
        parse_node(obj)
    elseif t == "way"
        parse_way(obj)
    elseif t == "relation"
        parse_relation(obj)
    else
        error("Unknown OSM element type: $t")
    end
end

function parse_response(json::JSON3.Object)::OverpassResponse
    osm3s = haskey(json, :osm3s) ? json.osm3s : nothing
    OverpassResponse(
        version = haskey(json, :version) ? Float64(json.version) : 0.6,
        generator = haskey(json, :generator) ? String(json.generator) : "",
        timestamp = !isnothing(osm3s) && haskey(osm3s, :timestamp_osm_base) ? String(osm3s.timestamp_osm_base) : "",
        elements = Element[parse_element(e) for e in json.elements],
    )
end

#--------------------------------------------------------------------------------# Query
#--------------------------------------------------------------------------------

"""
    bbox_string(ext::Extent) -> String

Convert an `Extents.Extent` to an Overpass bbox string `"(south,west,north,east)"`.

### Examples
```julia
julia> bbox_string(Extent(X=(-79.1, -78.8), Y=(35.9, 36.1)))
"(35.9,-79.1,36.1,-78.8)"
```
"""
function bbox_string(ext::Extent)
    x = ext.X
    y = ext.Y
    "($(y[1]),$(x[1]),$(y[2]),$(x[2]))"
end

"""
    query(ql::String; bbox=nothing, endpoint=DEFAULT_ENDPOINT) -> OverpassResponse

Execute an Overpass QL query and return the parsed response.

`[out:json]` is automatically prepended if not already present in the query.

If `bbox` is provided as an `Extents.Extent`, a global `[bbox:south,west,north,east]` setting
is prepended to the query, applying the bounding box to all statements.

### Examples
```julia
julia> using Extents

julia> r = query("node[amenity=cafe]; out geom;",
                  bbox=Extent(X=(-79.1, -78.8), Y=(35.9, 36.1)))

julia> r = query("node[amenity=cafe](35.9,-79.1,36.1,-78.8); out geom;")
```
"""
function query(ql::String; bbox::Union{Extent, Nothing}=nothing, endpoint::String=DEFAULT_ENDPOINT)
    q = contains(ql, "[out:json]") ? ql : "[out:json];" * ql
    if !isnothing(bbox)
        x = bbox.X
        y = bbox.Y
        q = "[bbox:$(y[1]),$(x[1]),$(y[2]),$(x[2])];" * q
    end
    resp = HTTP.post(endpoint, [], HTTP.Form(Dict("data" => q)))
    if resp.status != 200
        error("Overpass API error (HTTP $(resp.status)): $(String(resp.body))")
    end
    json = JSON3.read(resp.body)
    parse_response(json)
end

#--------------------------------------------------------------------------------# GeoInterface
#--------------------------------------------------------------------------------

# --- LatLon ---
GI.isgeometry(::Type{LatLon}) = true
GI.geomtrait(::LatLon) = GI.PointTrait()
GI.ncoord(::GI.PointTrait, ::LatLon) = 2
GI.getcoord(::GI.PointTrait, p::LatLon, i::Integer) = i == 1 ? p.lon : p.lat

# --- Node ---
GI.isgeometry(::Type{Node}) = true
GI.geomtrait(::Node) = GI.PointTrait()
GI.ncoord(::GI.PointTrait, ::Node) = 2
GI.getcoord(::GI.PointTrait, n::Node, i::Integer) = i == 1 ? n.lon : n.lat

# --- Way ---
GI.isgeometry(::Type{Way}) = true
GI.geomtrait(w::Way) = isempty(w.geometry) ? nothing : GI.LineStringTrait()
GI.ncoord(::GI.LineStringTrait, ::Way) = 2
GI.ngeom(::GI.LineStringTrait, w::Way) = length(w.geometry)
GI.getgeom(::GI.LineStringTrait, w::Way, i::Integer) = w.geometry[i]

#--------------------------------------------------------------------------------# Extents
#--------------------------------------------------------------------------------

Extents.extent(p::LatLon) = Extent(X=(p.lon, p.lon), Y=(p.lat, p.lat))
Extents.extent(n::Node) = Extent(X=(n.lon, n.lon), Y=(n.lat, n.lat))

function Extents.extent(w::Way)
    isempty(w.geometry) && error("Way $(w.id) has no geometry data. Use `out geom` in your query.")
    lons = (p.lon for p in w.geometry)
    lats = (p.lat for p in w.geometry)
    Extent(X=extrema(lons), Y=extrema(lats))
end

#--------------------------------------------------------------------------------# Show Methods
#--------------------------------------------------------------------------------

function Base.show(io::IO, p::LatLon)
    print(io, "LatLon($(p.lat), $(p.lon))")
end

function Base.show(io::IO, n::Node)
    print(io, "Node($(n.id), $(n.lat), $(n.lon)")
    isempty(n.tags) || print(io, ", ", length(n.tags), " tags")
    print(io, ")")
end

function Base.show(io::IO, w::Way)
    print(io, "Way($(w.id)")
    isempty(w.tags) || print(io, ", ", length(w.tags), " tags")
    isempty(w.node_ids) || print(io, ", ", length(w.node_ids), " nodes")
    isempty(w.geometry) || print(io, ", ", length(w.geometry), " coords")
    print(io, ")")
end

function Base.show(io::IO, m::Member)
    print(io, "Member($(m.type), ref=$(m.ref), role=$(repr(m.role)))")
end

function Base.show(io::IO, r::Relation)
    print(io, "Relation($(r.id)")
    isempty(r.tags) || print(io, ", ", length(r.tags), " tags")
    isempty(r.members) || print(io, ", ", length(r.members), " members")
    print(io, ")")
end

function Base.show(io::IO, r::OverpassResponse)
    nn = count(e -> e isa Node, r.elements)
    nw = count(e -> e isa Way, r.elements)
    nr = count(e -> e isa Relation, r.elements)
    parts = String[]
    nn > 0 && push!(parts, "$nn nodes")
    nw > 0 && push!(parts, "$nw ways")
    nr > 0 && push!(parts, "$nr relations")
    print(io, "OverpassResponse(", join(parts, ", "), ")")
end

end # module
