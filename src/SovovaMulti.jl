module SovovaMulti

using BlackBoxOptim

export ExtractionCurve, SovovaResult, sovova_multi

const kB = 1.3806503e-23  # Boltzmann constant (J/K)
const r_solute = 1.0e-9   # solute molecule radius (m)

"""
    ExtractionCurve(; kwargs...)

Experimental extraction curve data and operating conditions for one experiment.

# Required keyword arguments
- `t::Vector{Float64}`: extraction times (min)
- `m_ext::Vector{Float64}`: cumulative extracted mass at each time (g)
- `temperature::Float64`: temperature (K)
- `porosity::Float64`: bed porosity (dimensionless)
- `x0::Float64`: total extractable yield (mass fraction, kg/kg)
- `solid_density::Float64`: solid density (g/cm³)
- `solvent_density::Float64`: solvent density (g/cm³)
- `flow_rate::Float64`: solvent flow rate (cm³/min)
- `bed_height::Float64`: bed height (cm)
- `bed_diameter::Float64`: bed diameter (cm)
- `particle_diameter::Float64`: particle diameter (cm)
- `solid_mass::Float64`: mass of solid (g)
- `solubility::Float64`: solubility (kg/kg)
- `viscosity::Float64`: solvent dynamic viscosity (mPa·s = cP)

# Optional keyword arguments  
- `diffusivity::Float64`: solute diffusivity in solvent (m²/s).
  If not provided, estimated from Stokes-Einstein equation.
- `nh::Int`: spatial discretization steps (default: 5)
- `nt::Int`: temporal discretization steps (default: 2500)
"""
struct ExtractionCurve
    # Experimental data (SI units internally)
    t::Vector{Float64}         # times (s)
    m_ext::Vector{Float64}     # cumulative extracted mass (kg)
    # Operating conditions (SI)
    temperature::Float64       # K
    porosity::Float64          # dimensionless  
    x0::Float64                # total extractable (kg/kg)
    solid_density::Float64     # kg/m³
    solvent_density::Float64   # kg/m³
    flow_rate::Float64         # m³/s
    bed_height::Float64        # m
    bed_diameter::Float64      # m
    particle_diameter::Float64 # m
    solid_mass::Float64        # kg
    solubility::Float64        # kg/kg
    viscosity::Float64         # Pa·s
    diffusivity::Float64       # m²/s
    # Discretization
    nh::Int
    nt::Int
end

function ExtractionCurve(;
    t::Vector{Float64},
    m_ext::Vector{Float64},
    temperature::Float64,
    porosity::Float64,
    x0::Float64,
    solid_density::Float64,
    solvent_density::Float64,
    flow_rate::Float64,
    bed_height::Float64,
    bed_diameter::Float64,
    particle_diameter::Float64,
    solid_mass::Float64,
    solubility::Float64,
    viscosity::Float64,
    diffusivity::Union{Float64,Nothing} = nothing,
    nh::Int = 5,
    nt::Int = 2500,
)
    # Convert from user-friendly units (g, cm, min) to SI (kg, m, s)
    t_si = t .* 60.0
    m_ext_si = m_ext ./ 1000.0
    solid_density_si = solid_density * 1000.0
    solvent_density_si = solvent_density * 1000.0
    flow_rate_si = flow_rate / (60.0 * 1000.0)
    bed_height_si = bed_height / 100.0
    bed_diameter_si = bed_diameter / 100.0
    particle_diameter_si = particle_diameter / 100.0
    solid_mass_si = solid_mass / 1000.0
    viscosity_si = viscosity / 1000.0  # mPa·s -> Pa·s

    # Compute diffusivity from Stokes-Einstein if not provided
    dab = if diffusivity === nothing
        kB * temperature / (6π * r_solute * viscosity_si)
    else
        diffusivity
    end

    ExtractionCurve(
        t_si, m_ext_si,
        temperature, porosity, x0,
        solid_density_si, solvent_density_si, flow_rate_si,
        bed_height_si, bed_diameter_si, particle_diameter_si,
        solid_mass_si, solubility, viscosity_si, dab,
        nh, nt,
    )
end

"""
    SovovaResult

Result of multi-curve Sovová model fitting.

# Fields
- `kya::Vector{Float64}`: fluid-phase mass transfer coefficients (1/s), one per curve  
- `kxa::Vector{Float64}`: solid-phase mass transfer coefficients (1/s), one per curve
- `xk_ratio::Float64`: ratio xk/x0 (shared across all curves)
- `xk::Vector{Float64}`: xk = xk_ratio * x0 for each curve (kg/kg)
- `tcer::Vector{Float64}`: CER period duration for each curve (s)
- `ycal::Vector{Vector{Float64}}`: calculated extraction curves (kg)
- `objective::Float64`: sum of squared residuals at optimum
"""
struct SovovaResult
    kya::Vector{Float64}
    kxa::Vector{Float64}
    xk_ratio::Float64
    xk::Vector{Float64}
    tcer::Vector{Float64}
    ycal::Vector{Vector{Float64}}
    objective::Float64
end

function Base.show(io::IO, r::SovovaResult)
    nexp = length(r.kya)
    println(io, "SovovaResult ($(nexp) curve$(nexp > 1 ? "s" : "")):")
    println(io, "  xk/x0 = ", r.xk_ratio)
    println(io, "  objective (SSR) = ", r.objective)
    for i in 1:nexp
        println(io, "  Curve $i: kya = $(r.kya[i]), kxa = $(r.kxa[i]), xk = $(r.xk[i]), tcer = $(r.tcer[i]) s")
    end
end

"""
    SimWorkspace

Pre-allocated workspace for the Sovová simulation, avoiding repeated allocations
in the optimization loop.
"""
struct SimWorkspace
    xs::Vector{Float64}
    y::Vector{Float64}
    ycal::Vector{Float64}
end

SimWorkspace(nh::Int, ndata::Int) = SimWorkspace(Vector{Float64}(undef, nh), zeros(nh + 1), zeros(ndata))

"""
    simulate(curve::ExtractionCurve, kya, kxa, xk)
    simulate!(workspace::SimWorkspace, curve::ExtractionCurve, kya, kxa, xk)

Simulate the Sovová extraction model for one curve.
Returns a vector of calculated cumulative extracted masses at the experimental times.
The in-place variant `simulate!` reuses pre-allocated workspace arrays.
"""
function simulate(curve::ExtractionCurve, kya, kxa, xk)
    ws = SimWorkspace(curve.nh, length(curve.t))
    simulate!(ws, curve, kya, kxa, xk)
end

function simulate!(ws::SimWorkspace, curve::ExtractionCurve, kya, kxa, xk)
    (; t, m_ext, porosity, x0, solid_density, solvent_density,
       flow_rate, bed_height, bed_diameter, particle_diameter,
       solid_mass, solubility, viscosity, diffusivity, nh, nt) = curve

    ndata = length(t)
    xs = ws.xs
    y = ws.y
    ycal = ws.ycal

    # Initialize workspace arrays
    fill!(xs, x0)
    fill!(y, 0.0)
    fill!(ycal, 0.0)

    # Recompute porosity from bed geometry (as in Fortran code)
    eps = 1.0 - 4.0 * solid_mass / (π * bed_diameter^2 * bed_height * solid_density)
    # Interstitial velocity
    v = 4.0 * flow_rate / (solvent_density * π * bed_diameter^2 * eps)

    tempo = t[end]
    dt = tempo / nt
    dh = bed_height / nh

    yant_outlet = 0.0
    ynum_prev = 0.0
    ynum_curr = 0.0

    current_t = 0.0
    for _ in 1:nt
        current_t += dt

        # Inlet boundary condition
        y[1] = 0.0

        # Spatial loop
        for k in 1:nh
            if xs[k] > xk
                # CER period: J = kya * (Y* - Y)
                jxy = kya * (solubility - y[k])
            else
                # FER period: J = kxa * x * (1 - Y/Y*)
                jxy = kxa * xs[k] * (1.0 - y[k] / solubility)
            end

            # Update solid concentration
            xs[k] -= dt * jxy * solvent_density / (solid_density * (1.0 - eps))

            # Store previous outlet for trapezoidal rule
            if k == nh
                yant_outlet = y[nh + 1]
            end

            # Update fluid concentration (spatial march)
            y[k + 1] = y[k] + dh * jxy / (eps * v)
        end

        # Trapezoidal integration of outlet mass flow
        ynum_curr = ynum_prev + dt * (y[nh + 1] + yant_outlet) * flow_rate / 2.0

        # Interpolation: assign to experimental points in [current_t - dt, current_t]
        for i in 1:ndata
            if t[i] >= current_t - dt && t[i] <= current_t
                ycal[i] = ynum_prev + (ynum_curr - ynum_prev) * (t[i] - current_t + dt) / dt
            end
        end

        ynum_prev = ynum_curr
    end

    return ycal
end

"""
    sovova_multi(curves::Vector{ExtractionCurve}; kwargs...)
    sovova_multi(curve::ExtractionCurve; kwargs...)

Fit the Sovová supercritical extraction model to one or more extraction curves simultaneously.

The model fits per-curve parameters `kya` (fluid-phase mass transfer coefficient) and
`kxa` (solid-phase mass transfer coefficient), plus a shared parameter `xk/x0` 
(ratio of easily accessible solute to total extractable).

# Keyword arguments
- `kya_bounds::Tuple{Float64,Float64}`: bounds for kya (default: `(0.0, 0.05)`)
- `kxa_bounds::Tuple{Float64,Float64}`: bounds for kxa (default: `(0.0, 0.005)`)
- `xk_ratio_bounds::Tuple{Float64,Float64}`: bounds for xk/x0 (default: `(0.0, 1.0)`)
- `maxevals::Int`: maximum number of function evaluations (default: `50000`)
- `tracemode::Symbol`: verbosity of optimizer output (default: `:silent`). Use `:compact` or `:verbose` for progress.

# Returns
- `SovovaResult`: fitted model parameters and calculated curves.
"""
function sovova_multi(curve::ExtractionCurve; kwargs...)
    sovova_multi([curve]; kwargs...)
end

function sovova_multi(
    curves::Vector{ExtractionCurve};
    kya_bounds::Tuple{Float64,Float64} = (0.0, 0.05),
    kxa_bounds::Tuple{Float64,Float64} = (0.0, 0.005),
    xk_ratio_bounds::Tuple{Float64,Float64} = (0.0, 1.0),
    maxevals::Int = 50_000,
    tracemode::Symbol = :silent,
)
    nexp = length(curves)
    n = 2 * nexp + 1  # number of parameters

    # Build bounds: [kya_1, kxa_1, kya_2, kxa_2, ..., xk_ratio]
    search_range = Tuple{Float64,Float64}[]
    for iexp in 1:nexp
        push!(search_range, kya_bounds)
        push!(search_range, kxa_bounds)
    end
    push!(search_range, xk_ratio_bounds)

    # Pre-allocate simulation workspaces (one per curve)
    workspaces = [SimWorkspace(curves[i].nh, length(curves[i].t)) for i in 1:nexp]

    # Objective function: sum of squared residuals
    function objective(a)
        xk_ratio = a[n]
        f = 0.0
        for iexp in 1:nexp
            kya_i = a[2*iexp-1]
            kxa_i = a[2*iexp]
            xk_i = curves[iexp].x0 * xk_ratio
            ycal = simulate!(workspaces[iexp], curves[iexp], kya_i, kxa_i, xk_i)
            for i in eachindex(ycal)
                f += (ycal[i] - curves[iexp].m_ext[i])^2
            end
        end
        return f
    end

    # Global optimization with BlackBoxOptim
    res = bboptimize(objective;
        SearchRange = search_range,
        NumDimensions = n,
        MaxFuncEvals = maxevals,
        TraceMode = tracemode,
    )

    best_a = best_candidate(res)
    best_f = best_fitness(res)

    # Extract results
    xk_ratio = best_a[n]
    kya_vec = [best_a[2*i-1] for i in 1:nexp]
    kxa_vec = [best_a[2*i]   for i in 1:nexp]
    xk_vec  = [curves[i].x0 * xk_ratio for i in 1:nexp]

    # Compute tcer and final calculated curves
    tcer_vec = zeros(nexp)
    ycal_all = Vector{Vector{Float64}}(undef, nexp)
    for iexp in 1:nexp
        c = curves[iexp]
        eps = 1.0 - 4.0 * c.solid_mass / (π * c.bed_diameter^2 * c.bed_height * c.solid_density)
        tcer_vec[iexp] = (c.x0 - xk_vec[iexp]) * (1.0 - eps) * c.solid_density /
                         (c.solubility * kya_vec[iexp] * c.solvent_density)
        ycal_all[iexp] = simulate(c, kya_vec[iexp], kxa_vec[iexp], xk_vec[iexp])
    end

    return SovovaResult(
        kya_vec, kxa_vec, xk_ratio, xk_vec, tcer_vec,
        ycal_all, best_f,
    )
end

end
