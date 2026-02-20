[![CI](https://github.com/RallypointOne/OverpassAPI.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/RallypointOne/OverpassAPI.jl/actions/workflows/CI.yml)
[![Docs Build](https://github.com/RallypointOne/OverpassAPI.jl/actions/workflows/Docs.yml/badge.svg)](https://github.com/RallypointOne/OverpassAPI.jl/actions/workflows/Docs.yml)
[![Stable Docs](https://img.shields.io/badge/docs-stable-blue)](https://RallypointOne.github.io/OverpassAPI.jl/stable/)
[![Dev Docs](https://img.shields.io/badge/docs-dev-blue)](https://RallypointOne.github.io/OverpassAPI.jl/dev/)

# OverpassAPI.jl

A Julia interface to the [Overpass API](https://overpass-api.de/) for querying [OpenStreetMap](https://www.openstreetmap.org/) data. Results are returned as typed Julia structs with [GeoInterface.jl](https://github.com/JuliaGeo/GeoInterface.jl) and [Extents.jl](https://github.com/rafaqz/Extents.jl) support.

## Quick Example

```julia
using OverpassAPI, Extents

# Query with raw Overpass QL
r = query("node[amenity=cafe](35.9,-79.1,36.1,-78.8); out geom;")

# Or use the OQL query builder
r = query(OQL.node[amenity = "cafe"],
          bbox=Extent(X=(-79.1, -78.8), Y=(35.9, 36.1)))

# Access results
for n in nodes(r)
    println(n["name"])
end
```
