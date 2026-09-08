# Live queries against the public Overpass API.  Opt in with OVERPASS_LIVE_TESTS=true.
# OVERPASS_ENDPOINT selects a mirror, e.g. https://overpass.kumi.systems/api/interpreter.
using OverpassAPI
using Extents: Extents, Extent
using GeoInterface
using Test

const LIVE_ENDPOINT = get(ENV, "OVERPASS_ENDPOINT", DEFAULT_ENDPOINT)

# Downtown Durham, NC.  Small enough that every query below returns in a few seconds.
const LIVE_EXT = Extent(X=(-78.905, -78.895), Y=(35.993, 36.001))

# The public endpoint rate-limits (HTTP 429) and sheds load (HTTP 504).  Its usage policy asks
# for a 30 s pause before retrying; any other error propagates unchanged.
function live_query(args...; kw...)
    for delay in (30, 60)
        try
            return query(args...; kw..., endpoint=LIVE_ENDPOINT)
        catch e
            e isa ErrorException && occursin(r"HTTP (429|504)", e.msg) || rethrow()
            @warn "Overpass API busy, retrying in $(delay)s"
            sleep(delay)
        end
    end
    query(args...; kw..., endpoint=LIVE_ENDPOINT)
end

@testset "Live Overpass service" begin
    cafes = live_query("node[amenity=cafe]$(bbox_string(LIVE_EXT)); out;")
    cafe_ids = Set(n.id for n in nodes(cafes))

    @testset "raw QL with inline bbox" begin
        @test cafes.version == 0.6
        @test startswith(cafes.generator, "Overpass API")
        @test !isempty(cafes.timestamp)
        @test !isempty(cafe_ids)
        @test all(n -> n["amenity"] == "cafe", nodes(cafes))
        @test all(n -> Extents.coveredby(Extents.extent(n), LIVE_EXT), nodes(cafes))
    end

    @testset "bbox keyword prepends [out:json][bbox:...]" begin
        r = live_query("node[amenity=cafe]; out;", bbox=LIVE_EXT)
        @test Set(n.id for n in nodes(r)) == cafe_ids
    end

    @testset "bbox keyword merges into an existing settings statement" begin
        r = live_query("[timeout:25]; node[amenity=cafe]; out;", bbox=LIVE_EXT)
        @test Set(n.id for n in nodes(r)) == cafe_ids
    end

    @testset "QLStatement query" begin
        r = live_query(OQL.node[amenity="cafe"], bbox=LIVE_EXT)
        @test Set(n.id for n in nodes(r)) == cafe_ids
    end

    @testset "ways with out geom" begin
        r = live_query(OQL.way["building"], bbox=LIVE_EXT)
        ws = ways(r)
        @test !isempty(ws)
        @test all(w -> haskey(w, "building"), ws)
        @test all(w -> length(w.geometry) == length(w.node_ids), ws)
        @test all(w -> GeoInterface.geomtrait(w) == GeoInterface.LineStringTrait(), ws)
        @test all(w -> Extents.intersects(Extents.extent(w), LIVE_EXT), ws)
    end

    @testset "relations with out geom" begin
        r = live_query(OQL.rel[type="multipolygon"], bbox=LIVE_EXT)
        rs = relations(r)
        @test !isempty(rs)
        @test all(rel -> rel["type"] == "multipolygon", rs)
        @test all(rel -> !isempty(rel.members), rs)
        @test all(rel -> all(m -> m.type in ("node", "way", "relation"), rel.members), rs)
        @test any(rel -> any(m -> !isempty(m.geometry), rel.members), rs)
    end

    @testset "invalid query raises HTTP 400" begin
        err = try
            live_query("this is not valid;")
        catch e
            e
        end
        @test err isa ErrorException
        @test occursin("HTTP 400", sprint(showerror, err))
    end
end
