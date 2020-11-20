function evolve!(ϕⁿ⁺¹,ϕⁿ,𝐮,grid,Δt)
    ∇ϕⁿ  = upwind(ϕⁿ,𝐮,grid)    
    map!(ϕⁿ⁺¹,𝐮,∇ϕⁿ) do u,∇ϕ
        -Δt * (u ⋅ ∇ϕ)
    end    
    @. ϕⁿ⁺¹ = ϕⁿ⁺¹ + ϕⁿ
    return ϕⁿ⁺¹
end

