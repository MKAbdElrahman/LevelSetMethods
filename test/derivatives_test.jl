using Test
using LevelSetMethods
using LinearAlgebra

using LevelSetMethods: D⁺, D⁻, D⁰, D2⁰,D2

@testset "Uniform mesh" begin
    nx,ny = 100,50
    x     = LinRange(-2,2,nx)
    y     = LinRange(-2,2,ny)
    grid = CartesianGrid(x,y)
    h    = meshsize(grid)
    ϕ    = LevelSet(grid) do (x,y)
        1 - x^2 - y^2
    end    
    I  = CartesianIndex(9,7)
    ∇ϕ   = MeshField(grid) do (x,y)
        SVector(-2x,-2y)
    end
    # first derivative    
    for op in (D⁺,D⁻,D⁰)
        for dir in 1:2
            @test abs(∇ϕ[I][dir] - op(ϕ,I,dir)) < 5*h[dir]
        end
    end
    # second derivative, same direction
    for dir in 1:2
        @test abs( -2 - D2⁰(ϕ,I,dir)) < 5*h[dir]
        @test abs( -2 - D2(ϕ,I,(dir,dir))) < 5*h[dir]
    end
    # second derivative, different directions
    for op in (D2,)
        for dims in ((1,2),(2,1))
            @test abs(op(ϕ,I,dims)) < 5*h[dims[1]]*h[dims[2]]
        end
    end
end