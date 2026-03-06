# SovovaMulti.jl

*Multi-curve fitting of the Sovová supercritical fluid extraction model.*

[![Build Status](https://github.com/lmiq/SovovaMulti.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lmiq/SovovaMulti.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://lmiq.github.io/SovovaMulti.jl/stable/)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://lmiq.github.io/SovovaMulti.jl/dev/)

## Overview

SovovaMulti.jl fits the Sovová (1994) model of supercritical fluid extraction (SFE) to one
or more experimental extraction curves simultaneously. The package:

- Accepts experimental data and operating conditions in **laboratory units** (g, cm, min).
- Solves the Sovová partial-differential-equation model numerically (finite differences).
- Fits per-curve mass transfer coefficients (`kya`, `kxa`) and a shared easily-accessible
  solute ratio (`xk/x0`) using global optimization from
  [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl).
- No need for manual multi-start — the optimizer handles global search automatically.

## Quick start

```julia
using SovovaMulti

curve = ExtractionCurve(
    t         = [5.0, 10.0, 20.0, 30.0, 60.0, 90.0, 120.0],  # min
    m_ext     = [0.1, 0.3, 0.6, 0.9, 1.2, 1.4, 1.5],          # g
    temperature    = 313.15,   # K
    porosity       = 0.4,
    x0             = 0.05,     # kg/kg
    solid_density  = 1.1,      # g/cm³
    solvent_density = 0.8,     # g/cm³
    flow_rate      = 5.0,      # cm³/min
    bed_height     = 20.0,     # cm
    bed_diameter   = 2.0,      # cm
    particle_diameter = 0.05,  # cm
    solid_mass     = 50.0,     # g
    solubility     = 0.005,    # kg/kg
    viscosity      = 0.06,     # mPa·s
)

result = sovova_multi(curve)
```

See the [Usage](@ref) page for details and multi-curve examples.
