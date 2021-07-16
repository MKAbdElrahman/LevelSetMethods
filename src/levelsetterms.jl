"""
    abstract type LevelSetTerm

A typical term in a level-set evolution equation.
"""
abstract type LevelSetTerm end

function compute_cfl(terms,ϕ)
    minimum(terms) do term
        _compute_cfl(term,ϕ)
    end
end

# generic method, loops over dimensions
function _compute_cfl(term::LevelSetTerm,ϕ,I)
    N = ambient_dimension(ϕ)
    minimum(1:N) do dim
        _compute_cfl(term,ϕ,I,dim)
    end
end

# generic method, loops over indices
function _compute_cfl(term::LevelSetTerm,ϕ)
    dt = Inf
    for I in interior_indices(ϕ)
        cfl = _compute_cfl(term,ϕ,I)
        dt = min(dt,cfl)
    end
    return dt
end

"""
    struct AdvectionTerm{V,M} <: LevelSetTerm

Level-set advection term representing  `𝐯 ⋅ ∇ϕ`.
"""
Base.@kwdef struct AdvectionTerm{V,M,S<:SpatialScheme} <: LevelSetTerm
    velocity::NodeField{V,M}
    scheme::S = Upwind()
end
velocity(adv::AdvectionTerm) = adv.velocity
scheme(adv::AdvectionTerm) = adv.scheme

Base.show(io::IO, t::AdvectionTerm) = print(io, "𝐮 ⋅ ∇ ϕ")

@inline function _compute_term(term::AdvectionTerm,ϕ,I,dim)
    sch = scheme(term)
    𝐮 = velocity(term)
    N = ambient_dimension(ϕ)
    # for dimension dim, compute the upwind derivative and multiply by the
    # velocity
    v = 𝐮[I][dim]
    if v > 0
        if sch === Upwind()
            return v*D⁻(ϕ,I,dim)
        elseif sch === WENO5()
            return v*weno5⁻(ϕ,I,dim)
        else
            error("scheme $sch not implemented")
        end
    else
        if sch === Upwind()
            return v*D⁺(ϕ,I,dim)
        elseif sch === WENO5()
            return v*weno5⁺(ϕ,I,dim)
        else
            error("scheme $sch not implemented")
        end
    end
end

function _compute_term(term::AdvectionTerm,ϕ,I)
    N = ambient_dimension(ϕ)
    sum(1:N) do dim
        _compute_term(term,ϕ,I,dim)
    end
end

function _compute_cfl(term::AdvectionTerm,ϕ,I,dim)
    𝐮 = velocity(term)[I]
    N = ambient_dimension(ϕ)
    # for each dimension, compute the upwind derivative and multiply by the
    # velocity and add to buffer
    Δx = step(ϕ)[dim]
    return Δx/abs(𝐮[dim])
end

"""
    struct CurvatureTerm{V,M} <: LevelSetTerm

Level-set curvature term representing `bκ|∇ϕ|`, where `κ = ∇ ⋅ (∇ϕ/|∇ϕ|) ` is
the curvature.
"""
struct CurvatureTerm{V,M} <: LevelSetTerm
    b::NodeField{V,M}
end
coefficient(cterm::CurvatureTerm) = cterm.b

Base.show(io::IO, t::CurvatureTerm) = print(io, "b κ|∇ϕ|")

function _compute_term(term::CurvatureTerm,ϕ,I)
    N = ambient_dimension(ϕ)
    b = coefficient(term)
    κ = curvature(ϕ,I)
    # compute |∇ϕ|
    ϕ2 = sum(1:N) do dim
        D⁰(ϕ,I,dim)^2
    end
    # update
    return b[I]*κ*sqrt(ϕ2)
end

function _compute_cfl(term::CurvatureTerm,ϕ,I,dim)
    b = coefficient(term)[I]
    Δx = step(ϕ)[dim]
    return (Δx)^2/(2*abs(b))
end

function curvature(ϕ::LevelSet,I)
    N = ambient_dimension(ϕ)
    if N == 2
        ϕx  = D⁰(ϕ,I,1)
        ϕy  = D⁰(ϕ,I,2)
        ϕxx = D2⁰(ϕ,I,1)
        ϕyy = D2⁰(ϕ,I,2)
        ϕxy = D2(ϕ,I,(2,1))
        κ   = (ϕxx*(ϕy)^2 - 2*ϕy*ϕx*ϕxy + ϕyy*ϕx^2) / (ϕx^2 + ϕy^2)^(3/2)
        return κ
    elseif N == 3
        ϕx  = D⁰(ϕ,I,1)
        ϕy  = D⁰(ϕ,I,2)
        ϕz  = D⁰(ϕ,I,3)
        ϕxx = D2⁰(ϕ,I,1)
        ϕyy = D2⁰(ϕ,I,2)
        ϕzz = D2⁰(ϕ,I,3)
        ϕxy = D2(ϕ,I,(2,1))
        ϕxz = D2(ϕ,I,(3,1))
        # TODO: test + simplify this
        κ   = (ϕxx*(ϕy)^2 - 2*ϕy*ϕx*ϕxy + ϕyy*ϕx^2 + ϕx^2*ϕzz - 2*ϕx*ϕz*ϕxz + ϕz^2*ϕxx + ϕy^2*ϕzz - 2*ϕy*ϕz*ϕyz + ϕz^2*ϕyy) / (ϕx^2 + ϕy^2)^3/2
        return κ
    else
        notimplemented()
    end
end

"""
    struct NormalMotionTerm{V,M} <: LevelSetTerm

Level-set advection term representing  `v |∇ϕ|`. This `LevelSetTerm` should be
used for internally generated velocity fields; for externally generated
velocities you may use `AdvectionTerm` instead.
"""
@Base.kwdef struct NormalMotionTerm{V,M} <: LevelSetTerm
    speed::NodeField{V,M}
end
speed(adv::NormalMotionTerm) = adv.speed

Base.show(io::IO, t::NormalMotionTerm) = print(io, "v|∇ϕ|")

function _compute_term(term::NormalMotionTerm,ϕ,I)
    u = speed(term)
    v = u[I]
    ∇ = _compute_∇_normal_motion(v,ϕ,I)
    return ∇ * v
end

function _compute_∇_normal_motion(v,ϕ,I)
    N = ambient_dimension(ϕ)
    mA0²,mB0² = sum(1:N) do dim
        h = step(ϕ,dim)
        A = D⁻(ϕ,I,dim) + 0.5 * h * limiter(D2⁻⁻(ϕ,I,dim), D2⁰(ϕ,I,dim))
        B = D⁺(ϕ,I,dim) - 0.5 * h * limiter(D2⁺⁺(ϕ,I,dim), D2⁰(ϕ,I,dim))
        if v > 0.0
            SVector(positive(A)^2,negative(B)^2)
        else
            SVector(negative(A)^2,positive(B)^2)
        end
    end
    return sqrt(mA0² + mB0²)
end

function _compute_cfl(term::NormalMotionTerm,ϕ,I,dim)
    u = speed(term)[I]
    Δx = step(ϕ)[dim]
    return Δx/abs(u)
end

@inline positive(x) = x > zero(x) ? x : zero(x)
@inline negative(x) = x < zero(x) ? x : zero(x)

# eq. (6.28)
function limiter(x, y)
    x*y < zero(x) || return zero(x)
    return abs(x) <= abs(y) ? x : y
end

"""
    struct ReinitializationTerm <: LevelSetTerm

Level-set term representing  `sign(ϕ) (|∇ϕ| - 1)`. This `LevelSetTerm` should be
used for reinitializing the level set into a signed distance function: for a
sufficiently large number of time steps this term allows one to solve the
Eikonal equation |∇ϕ| = 1.
"""
@Base.kwdef struct ReinitializationTerm <: LevelSetTerm
end

Base.show(io::IO, t::ReinitializationTerm) = print(io, "sign(ϕ) (|∇ϕ| - 1)")

function _compute_term(term::ReinitializationTerm,ϕ,I)
    v = sign(ϕ[I])
    ∇ = _compute_∇_normal_motion(v,ϕ,I)
    return (∇ - 1.0) * v
end

_compute_cfl(term::ReinitializationTerm,ϕ,I,dim) = step(ϕ)[dim]
