# Usage

## Defining an extraction curve

Create an [`ExtractionCurve`](@ref) with your experimental data and operating conditions.
All inputs use **laboratory units** (g, cm, min, mPa·s) — the package converts to SI internally.

The experimental data is provided as a **matrix** where column 1 is the extraction time (min)
and columns 2, 3, … are cumulative extracted mass (g) for each replicate:

```julia
using SovovaMulti

# Single replicate (2 columns: time, m_ext)
data = [5.0  0.10;
        10.0 0.25;
        15.0 0.42;
        20.0 0.58;
        30.0 0.85;
        45.0 1.10;
        60.0 1.28;
        90.0 1.45;
        120.0 1.52]

curve = ExtractionCurve(
    data           = data,
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

## Reading data from files

Instead of typing the data matrix directly, you can read it from a text or Excel file.

### Text files with [`TextTable`](@ref)

A whitespace-delimited text file with an optional comment header (lines starting with `#`):

```
# t (min)   rep1 (g)   rep2 (g)
0.0         0.000      0.000
5.0         0.110      0.094
10.0        0.257      0.227
```

```julia
data = TextTable("experiment.txt")
curve = ExtractionCurve(data=data, temperature=313.15, ...)
```

### Excel files with [`ExcelTable`](@ref)

An `.xlsx` file where the first row is a header and the remaining rows contain
the data matrix (time column + replicate columns):

```julia
data = ExcelTable("experiment.xlsx")              # reads first sheet, skips header
data = ExcelTable("experiment.xlsx"; sheet=2)      # read a specific sheet
data = ExcelTable("experiment.xlsx"; header=false)  # no header row to skip
curve = ExtractionCurve(data=data, temperature=313.15, ...)
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
curve1 = ExtractionCurve(; data=data1, temperature=313.15, ...)
curve2 = ExtractionCurve(; data=data2, temperature=323.15, ...)
curve3 = ExtractionCurve(; data=data3, temperature=333.15, ...)

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

The fitting uses global optimization from
[BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl).
Control the optimization via keyword arguments:

```julia
result = sovova_multi(curves;
    kya_bounds      = (0.0, 0.05),   # bounds for kya (1/s)
    kxa_bounds      = (0.0, 0.005),  # bounds for kxa (1/s)
    xk_ratio_bounds = (0.0, 1.0),    # bounds for xk/x0
    maxevals        = 50_000,        # max function evaluations
    tracemode       = :silent,       # :silent, :compact, or :verbose
)
```

If the default bounds do not cover your expected parameter range, adjust them accordingly.
To see optimizer progress, set `tracemode = :compact`:

```julia
result = sovova_multi(curve; tracemode=:compact)
```

## Complete example with real data

The following example uses experimental data from a supercritical CO₂ extraction experiment
at 333.15 K (data from Mateus et al.), with two replicates:

```julia
using SovovaMulti

# Data matrix: column 1 = time (min), columns 2-3 = replicate m_ext (g)
data = [
    0.0   0.0000  0.0000;
    5.0   0.1097  0.0935;
   10.0   0.2571  0.2265;
   15.0   0.3894  0.3507;
   20.0   0.5228  0.4746;
   30.0   0.7872  0.7270;
   45.0   1.1633  1.0636;
   60.0   1.4848  1.3746;
   75.0   1.7484  1.6411;
   90.0   1.9751  1.8913;
  110.0   2.2485  2.1785;
  135.0   2.5630  2.5539;
  155.0   2.7584  2.7690;
  180.0   3.0323  3.0527;
  210.0   3.3022  3.3416;
  240.0   3.5332  3.5906;
  270.0   3.7349  3.8130;
  300.0   3.9260  4.0177
]

# Or read from a file:
# data = TextTable("mateus1.txt")
# data = ExcelTable("mateus1.xlsx")

curve = ExtractionCurve(
    data              = data,
    temperature       = 333.15,   # K
    porosity          = 0.7,      # bed porosity (dimensionless)
    x0                = 0.069,    # total extractable yield (kg/kg)
    solid_density     = 1.32,     # g/cm³
    solvent_density   = 0.78023,  # g/cm³
    flow_rate         = 9.9,      # cm³/min
    bed_height        = 9.2,      # cm
    bed_diameter      = 5.42,     # cm
    particle_diameter = 0.0337,   # cm
    solid_mass        = 100.01,   # g
    solubility        = 0.003166, # kg/kg
    viscosity         = 0.067739, # mPa·s
)

result = sovova_multi(curve)

# Print fitted parameters
println("kya  = ", result.kya[1], " 1/s")
println("kxa  = ", result.kxa[1], " 1/s")
println("xk   = ", result.xk[1], " kg/kg")
println("tCER = ", result.tcer[1], " s")
println("SSR  = ", result.objective)
```

## Graphical User Interface

See the [GUI](@ref "Graphical User Interface") page for the built-in web interface.
