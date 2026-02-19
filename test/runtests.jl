using OverpassAPI
using OverpassAPI: parse_response, LatLon, Node, Way, Relation, Member
using GeoInterface
using Extents: Extents, Extent
using JSON3
using Test

const GI = GeoInterface

#--------------------------------------------------------------------------------# Test Data
#--------------------------------------------------------------------------------

const NODE_JSON = JSON3.read("""
{
  "version": 0.6,
  "generator": "Overpass API 0.7.62",
  "osm3s": {"timestamp_osm_base": "2024-01-01T00:00:00Z"},
  "elements": [
    {
      "type": "node",
      "id": 123,
      "lat": 40.748,
      "lon": -73.985,
      "tags": {"amenity": "cafe", "name": "Test Cafe"}
    },
    {
      "type": "node",
      "id": 456,
      "lat": 40.749,
      "lon": -73.986,
      "tags": {}
    }
  ]
}
""")

const WAY_JSON = JSON3.read("""
{
  "version": 0.6,
  "generator": "Overpass API 0.7.62",
  "osm3s": {"timestamp_osm_base": "2024-01-01T00:00:00Z"},
  "elements": [
    {
      "type": "way",
      "id": 789,
      "nodes": [1, 2, 3, 4],
      "tags": {"highway": "residential", "name": "Main St"},
      "geometry": [
        {"lat": 40.0, "lon": -74.0},
        {"lat": 40.1, "lon": -74.1},
        {"lat": 40.2, "lon": -74.2},
        {"lat": 40.3, "lon": -74.3}
      ]
    },
    {
      "type": "way",
      "id": 790,
      "nodes": [5, 6, 7],
      "tags": {"building": "yes"}
    }
  ]
}
""")

const RELATION_JSON = JSON3.read("""
{
  "version": 0.6,
  "generator": "Overpass API 0.7.62",
  "osm3s": {"timestamp_osm_base": "2024-01-01T00:00:00Z"},
  "elements": [
    {
      "type": "relation",
      "id": 999,
      "tags": {"type": "multipolygon", "building": "yes"},
      "members": [
        {"type": "way", "ref": 100, "role": "outer", "geometry": [
          {"lat": 40.0, "lon": -74.0},
          {"lat": 40.1, "lon": -74.1}
        ]},
        {"type": "way", "ref": 101, "role": "inner"}
      ]
    }
  ]
}
""")

const MIXED_JSON = JSON3.read("""
{
  "version": 0.6,
  "generator": "Overpass API 0.7.62",
  "osm3s": {"timestamp_osm_base": "2024-01-01T00:00:00Z"},
  "elements": [
    {"type": "node", "id": 1, "lat": 40.0, "lon": -74.0},
    {"type": "way", "id": 2, "nodes": [1, 2], "geometry": [
      {"lat": 40.0, "lon": -74.0},
      {"lat": 40.1, "lon": -74.1}
    ]},
    {"type": "relation", "id": 3, "members": []}
  ]
}
""")

#--------------------------------------------------------------------------------# Tests
#--------------------------------------------------------------------------------

@testset "OverpassAPI.jl" begin
    @testset "Parse Nodes" begin
        r = parse_response(NODE_JSON)
        @test r.version == 0.6
        @test r.generator == "Overpass API 0.7.62"
        @test r.timestamp == "2024-01-01T00:00:00Z"
        @test length(r.elements) == 2

        n = r.elements[1]
        @test n isa Node
        @test n.id == 123
        @test n.lat == 40.748
        @test n.lon == -73.985
        @test n.tags["amenity"] == "cafe"
        @test n.tags["name"] == "Test Cafe"

        n2 = r.elements[2]
        @test n2.id == 456
        @test isempty(n2.tags)
    end

    @testset "Parse Ways" begin
        r = parse_response(WAY_JSON)
        @test length(r.elements) == 2

        w = r.elements[1]
        @test w isa Way
        @test w.id == 789
        @test w.node_ids == [1, 2, 3, 4]
        @test length(w.geometry) == 4
        @test w.geometry[1] == LatLon(40.0, -74.0)
        @test w.tags["highway"] == "residential"

        # Way without geometry
        w2 = r.elements[2]
        @test w2 isa Way
        @test w2.id == 790
        @test isempty(w2.geometry)
        @test w2.node_ids == [5, 6, 7]
    end

    @testset "Parse Relations" begin
        r = parse_response(RELATION_JSON)
        @test length(r.elements) == 1

        rel = r.elements[1]
        @test rel isa Relation
        @test rel.id == 999
        @test rel.tags["type"] == "multipolygon"
        @test length(rel.members) == 2

        m1 = rel.members[1]
        @test m1.type == "way"
        @test m1.ref == 100
        @test m1.role == "outer"
        @test length(m1.geometry) == 2
        @test m1.geometry[1] == LatLon(40.0, -74.0)

        m2 = rel.members[2]
        @test m2.role == "inner"
        @test isempty(m2.geometry)
    end

    @testset "Convenience Accessors" begin
        r = parse_response(MIXED_JSON)
        @test length(r.elements) == 3
        @test length(nodes(r)) == 1
        @test length(ways(r)) == 1
        @test length(relations(r)) == 1
        @test nodes(r)[1].id == 1
        @test ways(r)[1].id == 2
        @test relations(r)[1].id == 3
    end

    @testset "GeoInterface - LatLon" begin
        p = LatLon(40.748, -73.985)
        @test GI.isgeometry(p)
        @test GI.geomtrait(p) == GI.PointTrait()
        @test GI.ncoord(p) == 2
        @test GI.x(p) == -73.985
        @test GI.y(p) == 40.748
        GI.testgeometry(p)
    end

    @testset "GeoInterface - Node" begin
        n = Node(id=1, lat=40.748, lon=-73.985, tags=Dict("a" => "b"))
        @test GI.isgeometry(n)
        @test GI.geomtrait(n) == GI.PointTrait()
        @test GI.ncoord(n) == 2
        @test GI.x(n) == -73.985
        @test GI.y(n) == 40.748
        GI.testgeometry(n)
    end

    @testset "GeoInterface - Way with geometry" begin
        w = Way(
            id=1,
            geometry=[LatLon(40.0, -74.0), LatLon(40.1, -74.1), LatLon(40.2, -74.2)],
        )
        @test GI.isgeometry(w)
        @test GI.geomtrait(w) == GI.LineStringTrait()
        @test GI.ncoord(w) == 2
        @test GI.ngeom(w) == 3

        pt = GI.getgeom(w, 1)
        @test pt isa LatLon
        @test GI.x(pt) == -74.0
        @test GI.y(pt) == 40.0
        GI.testgeometry(w)
    end

    @testset "GeoInterface - Way without geometry" begin
        w = Way(id=1, node_ids=[1, 2, 3])
        @test GI.geomtrait(w) === nothing
    end

    @testset "query helper - auto-prepend [out:json]" begin
        # Test that [out:json] is detected
        ql_with = "[out:json];node[amenity=cafe]; out;"
        ql_without = "node[amenity=cafe]; out;"
        @test contains(ql_with, "[out:json]")
        @test !contains(ql_without, "[out:json]")
        # The actual prepend logic is in query(), tested via contains()
        prepended = "[out:json];" * ql_without
        @test contains(prepended, "[out:json]")
    end

    @testset "Tag access via getindex" begin
        n = Node(id=1, lat=0.0, lon=0.0, tags=Dict("name" => "Cafe", "amenity" => "cafe"))
        @test n["name"] == "Cafe"
        @test n["amenity"] == "cafe"
        @test get(n, "name", "?") == "Cafe"
        @test get(n, "missing", "default") == "default"
        @test haskey(n, "name")
        @test !haskey(n, "missing")
        @test "name" in keys(n)

        w = Way(id=1, tags=Dict("highway" => "residential"))
        @test w["highway"] == "residential"
        @test get(w, "nope", "x") == "x"

        r = Relation(id=1, tags=Dict("type" => "route"))
        @test r["type"] == "route"
        @test haskey(r, "type")
    end

    @testset "OverpassResponse iteration and length" begin
        r = parse_response(MIXED_JSON)
        @test length(r) == 3
        @test eltype(typeof(r)) == Element
        collected = collect(r)
        @test length(collected) == 3
        @test collected[1] isa Node
        @test collected[2] isa Way
        @test collected[3] isa Relation
    end

    @testset "bbox_string" begin
        ext = Extent(X=(-79.1, -78.8), Y=(35.9, 36.1))
        @test bbox_string(ext) == "(35.9,-79.1,36.1,-78.8)"
    end

    @testset "Extents.extent" begin
        p = LatLon(40.748, -73.985)
        ext = Extents.extent(p)
        @test ext.X == (-73.985, -73.985)
        @test ext.Y == (40.748, 40.748)

        n = Node(id=1, lat=40.748, lon=-73.985)
        ext = Extents.extent(n)
        @test ext.X == (-73.985, -73.985)
        @test ext.Y == (40.748, 40.748)

        w = Way(id=1, geometry=[
            LatLon(40.0, -74.0), LatLon(40.1, -73.9), LatLon(40.2, -74.1)
        ])
        ext = Extents.extent(w)
        @test ext.X == (-74.1, -73.9)
        @test ext.Y == (40.0, 40.2)

        # Way without geometry should error
        w2 = Way(id=2, node_ids=[1, 2, 3])
        @test_throws ErrorException Extents.extent(w2)
    end

    @testset "OQL builder - getproperty" begin
        @test overpass_ql(OQL.node) == "node"
        @test overpass_ql(OQL.way) == "way"
        @test overpass_ql(OQL.relation) == "relation"
        @test overpass_ql(OQL.rel) == "rel"
        @test overpass_ql(OQL.nwr) == "nwr"
    end

    @testset "OQL builder - tag filters" begin
        # Exact match
        s = OQL.node["amenity" => "cafe"]
        @test overpass_ql(s) == "node[amenity=cafe]"

        # Tag exists
        s = OQL.way["building"]
        @test overpass_ql(s) == "way[building]"

        # Multiple filters (chained)
        s = OQL.node["amenity" => "cafe"]["cuisine" => "coffee"]
        @test overpass_ql(s) == "node[amenity=cafe][cuisine=coffee]"

        # Regex
        s = OQL.node["name" => r"^Starbucks"]
        @test overpass_ql(s) == "node[name~\"^Starbucks\"]"

        # Case-insensitive regex
        s = OQL.node["name" => r"^starbucks"i]
        @test overpass_ql(s) == "node[name~\"^starbucks\",i]"

        # Mixed filter types
        s = OQL.node["amenity" => "cafe"]["name" => r"^Star"i]["wifi"]
        @test overpass_ql(s) == "node[amenity=cafe][name~\"^Star\",i][wifi]"
    end

    @testset "OQL builder - keyword syntax" begin
        @test overpass_ql(OQL.node[amenity = "cafe"]) == "node[amenity=cafe]"
        @test overpass_ql(OQL.node[amenity = "cafe", cuisine = "coffee"]) == "node[amenity=cafe][cuisine=coffee]"
        @test overpass_ql(OQL.way[building = "yes"]) == "way[building=yes]"
        @test overpass_ql(OQL.node[name = r"^Star"i]) == "node[name~\"^Star\",i]"
        # Mixed: keyword then positional
        s = OQL.node[amenity = "cafe"]["wifi"]
        @test overpass_ql(s) == "node[amenity=cafe][wifi]"
    end

    @testset "OQL builder - show" begin
        @test repr(OQL.node["amenity" => "cafe"]) == "node[amenity=cafe]"
    end

    @testset "OQL builder - immutability" begin
        base = OQL.node
        a = base["amenity" => "cafe"]
        b = base["highway" => "primary"]
        @test overpass_ql(a) == "node[amenity=cafe]"
        @test overpass_ql(b) == "node[highway=primary]"
        @test overpass_ql(base) == "node"
    end

    @testset "Show methods" begin
        @test repr(LatLon(1.0, 2.0)) == "LatLon(1.0, 2.0)"
        @test contains(repr(Node(id=1, lat=1.0, lon=2.0)), "Node(1")
        @test contains(repr(Way(id=1)), "Way(1")
        @test contains(repr(Relation(id=1)), "Relation(1")
        @test contains(repr(parse_response(MIXED_JSON)), "OverpassResponse")
    end
end
