# SovovaMulti

[![Build Status](https://github.com/lmiq/SovovaMulti.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lmiq/SovovaMulti.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://lmiq.github.io/SovovaMulti.jl/stable/)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://lmiq.github.io/SovovaMulti.jl/dev/)

**SovovaMulti** fits the [Sovová (1994)](https://doi.org/10.1016/0009-2509(94)85024-5) supercritical fluid extraction model to experimental extraction curves. It supports simultaneous fitting of multiple curves sharing a common `xk/x0` parameter, using global black-box optimization.

## What it does

Supercritical fluid extraction (SFE) experiments produce cumulative-mass-vs-time curves. The Sovová model describes these curves with three physical parameters per experiment:

| Parameter | Description |
|-----------|-------------|
| `kya`     | Fluid-phase mass transfer coefficient (1/s) |
| `kxa`     | Solid-phase mass transfer coefficient (1/s) |
| `xk/x0`   | Fraction of easily accessible solute (shared across curves) |

`SovovaMulti` minimizes the sum of squared residuals between the simulated and experimental extraction curves using [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl). When multiple curves are fitted together (e.g. at different flow rates or temperatures), `xk/x0` is constrained to be the same for all of them, which improves the physical consistency of the fit.

## Installation

```julia
using Pkg
Pkg.add("SovovaMulti")
```

## Usage

### Graphical interface (GUI)

The easiest way to use the package is through its browser-based GUI:

```julia
using SovovaMulti
sovovagui()
```

This opens a local web application where you can:

1. **Input tab** — upload your data file (`.txt` or `.xlsx`), enter operating conditions, and configure optimizer bounds.
2. **Output tab** — view fitted parameters, a chart of experimental vs. calculated curves, and download the results as `.txt` or `.xlsx`.

#### Desktop shortcut

To create a desktop icon that launches the GUI without opening Julia first:

```julia
using SovovaMulti
create_shortcut()                        # desktop shortcut (default port 9876)
create_shortcut(location=:applications)  # app-menu entry
create_shortcut(port=8080, name="SFE Fit")
```

Supported platforms: **Linux**, **macOS**, **Windows**.

#### Command-line launch

```bash
julia -m SovovaMulti
julia -m SovovaMulti --port 8080
julia -m SovovaMulti --no-launch   # start server without opening a browser
```

### Julia API

#### Input data format

Data files must have one time column (minutes) followed by one or more replicate columns (grams of extracted material):

```
# t (min)   rep1 (g)   rep2 (g)
0.0         0.000      0.000
5.0         0.110      0.094
10.0        0.257      0.227
```

Lines starting with `#` are ignored. Both delimited text files and Excel (`.xlsx`) files are supported.

#### Single curve

```julia
using SovovaMulti

data = TextTable("experiment.txt")   # or ExcelTable("experiment.xlsx")

curve = ExtractionCurve(
    data             = data,
    temperature      = 313.15,   # K
    porosity         = 0.40,
    x0               = 0.05,     # kg/kg — total extractable yield
    solid_density    = 1050.0,   # g/cm³
    solvent_density  = 840.0,    # g/cm³
    flow_rate        = 0.5,      # cm³/min
    bed_height       = 10.0,     # cm
    bed_diameter     = 2.0,      # cm
    particle_diameter= 0.05,     # cm
    solid_mass       = 20.0,     # g
    solubility       = 0.008,    # kg/kg
    viscosity        = 0.08,     # mPa·s
)

result = sovova_multi(curve)
println(result)

export_results("results.txt",  result, curve)
export_results("results.xlsx", result, curve)
```

#### Multiple curves

```julia
curve1 = ExtractionCurve(data=TextTable("exp1.txt"), temperature=313.15, ...)
curve2 = ExtractionCurve(data=TextTable("exp2.txt"), temperature=333.15, ...)

result = sovova_multi([curve1, curve2])
```

#### Optimizer options

```julia
result = sovova_multi(curves;
    kya_bounds      = (0.0, 0.05),
    kxa_bounds      = (0.0, 0.005),
    xk_ratio_bounds = (0.0, 1.0),
    maxevals        = 100_000,
    tracemode       = :compact,   # :silent (default), :compact, or :verbose
)
```

## Output

`sovova_multi` returns a `SovovaResult` with fields:

- `kya`, `kxa` — fitted mass-transfer coefficients (one per curve)
- `xk_ratio` — fitted `xk/x0` (shared)
- `xk` — `xk_ratio * x0` for each curve
- `tcer` — duration of the constant-extraction-rate (CER) period for each curve
- `ycal` — calculated extraction curves
- `objective` — sum of squared residuals at the optimum

## Reference

Sovová, H. (1994). Rate of the vegetable oil extraction with supercritical CO₂ — I. Modelling of extraction curves. *Chemical Engineering Science*, 49(3), 409–414. https://doi.org/10.1016/0009-2509(94)85024-5
