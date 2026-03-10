# ── Kinetic models for supercritical fluid extraction ────────────────────────
#
# Each model implements:
#   param_spec(model)                               → Vector{ParamSpec}
#   simulate(model, curve, params::Vector{Float64}) → Vector{Float64}  (kg, same length as curve.t)
#
# All empirical models share the same ExtractionCurve operating conditions.
# The total extractable mass is  m_total = curve.x0 * curve.solid_mass  (kg).

abstract type ExtractionModel end

struct Sovova            <: ExtractionModel end  # existing PDE model (handled separately)
struct Reverchon         <: ExtractionModel end  # [1993] single exponential
struct Esquivel          <: ExtractionModel end  # [1999] single exponential
struct Zekovic           <: ExtractionModel end  # [2003] two-parameter
struct Nguyen            <: ExtractionModel end  # [1991] solid-resistance
struct VeljkovicMilenovic <: ExtractionModel end # [2002] two-phase leakage+diffusion
struct PKM               <: ExtractionModel end  # [2012] parallel-reaction kinetics
struct SplineModel       <: ExtractionModel end  # [2003] piecewise-linear CER/FER/DC

struct ParamSpec
    name    ::String   # "k1", "k2", …
    label   ::String   # human-readable description shown in the GUI
    lb      ::Float64  # suggested lower bound
    ub      ::Float64  # suggested upper bound
end

# ── Parameter specifications ──────────────────────────────────────────────────

param_spec(::Sovova) = [
    ParamSpec("kya", "kya — fluid-phase mass transfer coeff. (1/s)", 0.0, 0.05),
    ParamSpec("kxa", "kxa — solid-phase mass transfer coeff. (1/s)", 0.0, 0.005),
    ParamSpec("xk_ratio", "xk/x₀ — accessible solute ratio (—)", 0.0, 1.0),
]

param_spec(::Reverchon) = [
    ParamSpec("k1", "k₁ — rate constant (1/s)", 0.0, 1e-2),
]

param_spec(::Esquivel) = [
    ParamSpec("k1", "k₁ — rate constant (1/s)", 0.0, 1e-2),
]

param_spec(::Zekovic) = [
    ParamSpec("k1", "k₁ — accessible yield fraction (—)", 0.01, 1.0),
    ParamSpec("k2", "k₂ — rate constant (1/s)",           0.0,  1e-2),
]

param_spec(::Nguyen) = [
    ParamSpec("k1", "k₁ — solid-phase transfer coefficient (1/s)", 0.0, 1e-2),
]

param_spec(::VeljkovicMilenovic) = [
    ParamSpec("k1", "k₁ — leakage rate constant (1/s)",   0.0, 5e-2),
    ParamSpec("k2", "k₂ — diffusion rate constant (1/s)", 0.0, 5e-3),
    ParamSpec("k3", "k₃ — easily accessible fraction (—)", 0.0, 1.0),
]

param_spec(::PKM) = [
    ParamSpec("k1", "k₁ — easily accessible fraction (—)",          0.0, 1.0),
    ParamSpec("k2", "k₂ — fluid-phase rate constant (1/s)",         0.0, 5e-2),
    ParamSpec("k3", "k₃ — solid-phase rate constant (1/s)",         0.0, 5e-3),
]

param_spec(::SplineModel) = [
    ParamSpec("k1", "k₁ — CER rate (1/s)",             0.0, 5e-2),
    ParamSpec("k2", "k₂ — CER end time (s)",            0.0, 3600.0),
    ParamSpec("k3", "k₃ — FER rate (1/s)",             0.0, 1e-2),
    ParamSpec("k4", "k₄ — FER end time (s)",            0.0, 7200.0),
]

# ── Simulate functions ────────────────────────────────────────────────────────

function simulate(::Reverchon, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1 = p[1]
    return [m_total * (1.0 - exp(-k1 * t)) for t in curve.t]
end

function simulate(::Esquivel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1 = p[1]
    return [m_total * (1.0 - exp(-k1 * t)) for t in curve.t]
end

function simulate(::Zekovic, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2 = p[1], p[2]
    # m_e(t) = m_total * k1 * (1 - exp(-k2 * t))
    return [m_total * k1 * (1.0 - exp(-k2 * t)) for t in curve.t]
end

function simulate(::Nguyen, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1 = p[1]
    return [m_total * (1.0 - exp(-k1 * t)) for t in curve.t]
end

function simulate(::VeljkovicMilenovic, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3 = p[1], p[2], p[3]
    # m_e(t) = m_total * [k3*(1-exp(-k1*t)) + (1-k3)*(1-exp(-k2*t))]
    return [m_total * (k3 * (1.0 - exp(-k1 * t)) + (1.0 - k3) * (1.0 - exp(-k2 * t)))
            for t in curve.t]
end

function simulate(::PKM, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3 = p[1], p[2], p[3]
    # m_e(t) = m_total * [k1*(1-exp(-k2*t)) + (1-k1)*(1-exp(-k3*t))]
    return [m_total * (k1 * (1.0 - exp(-k2 * t)) + (1.0 - k1) * (1.0 - exp(-k3 * t)))
            for t in curve.t]
end

function simulate(::SplineModel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3, k4 = p[1], p[2], p[3], p[4]
    # Piecewise-linear: CER (slope k1) → FER (slope k3) → DC (flat)
    m_cer = m_total * k1 * k2                          # mass at end of CER
    m_fer = m_cer + m_total * k3 * max(k4 - k2, 0.0)  # mass at end of FER
    return map(curve.t) do t
        if t <= k2
            m_total * k1 * t
        elseif t <= k4
            m_cer + m_total * k3 * (t - k2)
        else
            m_fer  # DC phase: flat
        end
    end
end

# ── Generic multi-curve fitting ───────────────────────────────────────────────

"""Result of fitting an empirical model to one or more extraction curves."""
struct ModelFitResult
    model    ::ExtractionModel
    spec     ::Vector{ParamSpec}
    params   ::Vector{Float64}        # best-fit k1, k2, …
    ycal     ::Vector{Vector{Float64}} # calculated curves (kg)
    objective::Float64                # SSR at optimum
end

function Base.show(io::IO, r::ModelFitResult)
    println(io, "ModelFitResult ($(typeof(r.model)), $(length(r.ycal)) curve(s)):")
    for (s, v) in zip(r.spec, r.params)
        println(io, "  $(s.name) = $v  # $(s.label)")
    end
    println(io, "  SSR = $(r.objective)")
end

"""
    fit_model(model, curves; param_bounds, maxevals, tracemode)
    fit_model(model, curve;  ...)

Fit an empirical SFE kinetic model to one or more extraction curves.
All parameters are shared across curves.

# Arguments
- `model`: one of `Reverchon()`, `Esquivel()`, `Zekovic()`, `Nguyen()`,
           `VeljkovicMilenovic()`, `PKM()`, or `SplineModel()`
- `curves`: `Vector{ExtractionCurve}` or a single `ExtractionCurve`
- `param_bounds`: optional `Vector{Tuple{Float64,Float64}}`, one per parameter;
                  defaults to the values from `param_spec(model)`
- `maxevals`: maximum optimizer evaluations (default: `50_000`)
- `tracemode`: BlackBoxOptim trace verbosity (default: `:silent`)
"""
function fit_model(model::ExtractionModel, curve::ExtractionCurve; kwargs...)
    fit_model(model, [curve]; kwargs...)
end

function fit_model(
    model  ::ExtractionModel,
    curves ::Vector{ExtractionCurve};
    param_bounds ::Union{Nothing, Vector{Tuple{Float64,Float64}}} = nothing,
    maxevals     ::Int    = 50_000,
    tracemode    ::Symbol = :silent,
)
    spec   = param_spec(model)
    bounds = param_bounds !== nothing ? param_bounds : [(s.lb, s.ub) for s in spec]
    n      = length(bounds)

    function objective(params)
        f = 0.0
        for curve in curves
            ycal = simulate(model, curve, params)
            for i in eachindex(ycal)
                f += (ycal[i] - curve.m_ext[i])^2
            end
        end
        return f
    end

    res    = bboptimize(objective; SearchRange = bounds, NumDimensions = n,
                        MaxFuncEvals = maxevals, TraceMode = tracemode)
    best_p = best_candidate(res)
    best_f = best_fitness(res)
    ycal_all = [simulate(model, c, best_p) for c in curves]

    return ModelFitResult(model, spec, collect(best_p), ycal_all, best_f)
end

# ── Name → model instance lookup (used by the GUI) ───────────────────────────

const _MODEL_REGISTRY = Dict{String, ExtractionModel}(
    "sovova"    => Sovova(),
    "reverchon" => Reverchon(),
    "esquivel"  => Esquivel(),
    "zekovic"   => Zekovic(),
    "nguyen"    => Nguyen(),
    "veljkovic" => VeljkovicMilenovic(),
    "pkm"       => PKM(),
    "spline"    => SplineModel(),
)

model_from_name(name::String) = get(_MODEL_REGISTRY, lowercase(name), Sovova())

# ── Export support for ModelFitResult ─────────────────────────────────────────

function _fitted_params(result::ModelFitResult, ::Int)
    params = [(s.name, result.params[i], "") for (i, s) in enumerate(result.spec)]
    push!(params, ("SSR", result.objective, ""))
    return params
end

function export_results(filename::AbstractString, result::ModelFitResult, curve::ExtractionCurve)
    export_results(filename, result, [curve])
end

function export_results(filename::AbstractString, result::ModelFitResult, curves::Vector{ExtractionCurve})
    if endswith(lowercase(filename), ".xlsx")
        _export_xlsx(filename, result, curves)
    else
        _export_txt(filename, result, curves)
    end
    @info "Results written to $filename"
    return filename
end
