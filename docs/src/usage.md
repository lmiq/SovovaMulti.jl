# Usage

## Defining an extraction curve

Create an [`ExtractionCurve`](@ref) with your experimental data and operating conditions.
All inputs use **laboratory units** (g, cm, min, mPa·s) — the package converts to SI internally.

```julia
using SovovaMulti

curve = ExtractionCurve(
    t         = [5.0, 10.0, 15.0, 20.0, 30.0, 45.0, 60.0, 90.0, 120.0],  # min
    m_ext     = [0.1, 0.25, 0.42, 0.58, 0.85, 1.10, 1.28, 1.45, 1.52],    # g
    temperature    = 313.15,   # K
    porosity       = 0.4,      # dimensionless
    x0             = 0.05,     # kg/kg (total extractable yield)
    solid_density  = 1.1,      # g/cm³
    solvent_density = 0.8,     # g/cm³
    flow_rate      = 5.0,      # cm³/min
    bed_height     = 20.0,     # cm
    bed_diameter   = 2.0,      # cm
    particle_diameter = 0.05,  # cm
    solid_mass     = 50.0,     # g
    solubility     = 0.005,    # kg/kg
    viscosity      = 0.06,     # mPa·s (= cP)
)
```

### Diffusivity

By default, the solute diffusivity in the solvent is estimated from the **Stokes-Einstein
equation**:

```math
D_{AB} = \frac{k_B T}{6\pi r_{\text{solute}} \mu}
```

where ``r_{\text{solute}} = 10^{-9}`` m. You can override this by passing the `diffusivity`
keyword (in m²/s):

```julia
curve = ExtractionCurve(
    # ... other arguments ...
    diffusivity = 3.3e-9,  # m²/s
)
```

### Discretization

The numerical solution uses finite differences with `nh` spatial steps and `nt` temporal
steps (defaults: `nh=5`, `nt=2500`). Increase `nt` for better accuracy at the cost of
computation time:

```julia
curve = ExtractionCurve(
    # ... other arguments ...
    nh = 10,
    nt = 5000,
)
```

## Fitting a single curve

```julia
result = sovova_multi(curve)
```

The returned [`SovovaResult`](@ref) contains the fitted parameters:

```julia
println(result.kya)       # fluid-phase mass transfer coefficients
println(result.kxa)       # solid-phase mass transfer coefficients
println(result.xk_ratio)  # xk/x0 ratio (shared)
println(result.xk)        # xk = xk_ratio * x0 for each curve
println(result.tcer)      # CER period duration (s)
println(result.objective) # sum of squared residuals
```

The calculated extraction curves (in kg) are available as:

```julia
result.ycal[1]  # calculated values for the first (and only) curve
```

## Fitting multiple curves simultaneously

Pass a vector of [`ExtractionCurve`](@ref)s to fit all curves at once. Each curve gets its
own `kya` and `kxa`, but the ratio `xk/x0` is **shared** across all curves:

```julia
curve1 = ExtractionCurve(; t=t1, m_ext=m1, temperature=313.15, ...)
curve2 = ExtractionCurve(; t=t2, m_ext=m2, temperature=323.15, ...)
curve3 = ExtractionCurve(; t=t3, m_ext=m3, temperature=333.15, ...)

result = sovova_multi([curve1, curve2, curve3])
```

Access per-curve results by index:

```julia
result.kya[2]   # kya for curve 2
result.kxa[2]   # kxa for curve 2
result.xk[2]    # xk for curve 2
result.tcer[2]  # tCER for curve 2
result.ycal[2]  # calculated curve 2
```

## Optimizer options

The fitting uses the BOBYQA algorithm from [PRIMA.jl](https://github.com/libprima/PRIMA.jl)
with multi-start optimization. Control the optimization via keyword arguments:

```julia
result = sovova_multi(curves;
    kya_bounds      = (0.0, 0.05),   # bounds for kya (1/s)
    kxa_bounds      = (0.0, 0.005),  # bounds for kxa (1/s)
    xk_ratio_bounds = (0.0, 1.0),    # bounds for xk/x0
    maxfun          = 5000,          # max evaluations per restart
    rhoend          = 1e-6,          # final trust region radius
    nrestarts       = 1000,          # number of random restarts
)
```

If the default bounds do not cover your expected parameter range, adjust them accordingly.
The initial trust region radius (`rhobeg`) is set automatically from the bounds but can be
overridden:

```julia
result = sovova_multi(curve; rhobeg=0.001)
```
