# SovovaMulti

[![Build Status](https://github.com/lmiq/SovovaMulti.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/lmiq/SovovaMulti.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://lmiq.github.io/SovovaMulti.jl/stable/)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://lmiq.github.io/SovovaMulti.jl/dev/)

**SovovaMulti** fits the [Sovová (1994)](https://doi.org/10.1016/0009-2509(94)85024-5) supercritical fluid extraction model to experimental extraction curves. It supports simultaneous fitting of multiple curves sharing a common `xk/x0` parameter, using global optimization.

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
import Pkg
Pkg.Apps.add("SovovaMulti")
```

This will create a desktop shortcut for the app. Advanced command-line (Julia REPL) use is possible.

Supported platforms: **Linux**, **macOS**, **Windows**.

## References

Sovová, H. (1994). Rate of the vegetable oil extraction with supercritical CO₂ — I. Modelling of extraction curves. *Chemical Engineering Science*, 49(3), 409–414. https://doi.org/10.1016/0009-2509(94)85024-5

Martínez, J.; Martínez, J.M. (2008). Fitting the Sovová's supercritical fluid extraction model by means of a global optimization tool. *Computers & Chemical Engineering*, 32(8), 1735–1745. https://doi.org/10.1016/j.compchemeng.2007.08.009

Martínez, J.; Monteiro, A.R.; Rosa, P.T.V.; Marques, M.O.M.; Meireles, M.A.A. (2003). Multicomponent model to describe extraction of ginger oleoresin with supercritical carbon dioxide. *Industrial & Engineering Chemistry Research*, 42(5), 1057–1063. https://doi.org/10.1021/ie020694f
