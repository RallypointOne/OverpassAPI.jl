using OverpassAPI
using Test

@testset "OverpassAPI.jl" begin
    @test OverpassAPI.greet() == "Hello from OverpassAPI!"
end
