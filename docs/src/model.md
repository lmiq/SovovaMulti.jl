# Model Description

## The Sovová (1994) model

SovovaMulti.jl implements the mathematical model of supercritical fluid extraction (SFE) from
a packed bed, as described by Sovová (1994). The model distinguishes two extraction periods
based on the solid-phase solute concentration relative to a threshold ``x_k``:

### Mass balance equations

The model solves coupled mass balances for the **fluid phase** (concentration ``Y``) and the
**solid phase** (concentration ``X``) along the bed height ``h``:

**Fluid phase** (spatial march, neglecting accumulation):

```math
\varepsilon \, v \, \frac{\partial Y}{\partial h} = J(X, Y)
```

**Solid phase** (temporal evolution):

```math
(1 - \varepsilon) \, \rho_s \, \frac{\partial X}{\partial t} = -\rho_f \, J(X, Y)
```

where:
- ``\varepsilon`` is the bed porosity
- ``v`` is the interstitial solvent velocity (m/s)
- ``\rho_s`` is the solid density (kg/m³)
- ``\rho_f`` is the solvent density (kg/m³)

### Mass transfer rate

The volumetric mass transfer rate ``J`` depends on the extraction period:

**CER period** (constant extraction rate, ``X > x_k``):

```math
J = k_Y a \, (Y^* - Y)
```

**FER period** (falling extraction rate, ``X \le x_k``):

```math
J = k_X a \, X \left(1 - \frac{Y}{Y^*}\right)
```

where:
- ``k_Y a`` (`kya`) is the fluid-phase volumetric mass transfer coefficient (1/s)
- ``k_X a`` (`kxa`) is the solid-phase volumetric mass transfer coefficient (1/s)
- ``Y^*`` is the solubility (kg solute / kg solvent)
- ``x_k`` is the concentration threshold separating CER from FER

### Boundary and initial conditions

- **Inlet**: ``Y(h=0, t) = 0`` (pure solvent enters the bed)
- **Initial solid concentration**: ``X(h, t=0) = x_0`` (uniformly loaded)

### CER period duration

The duration of the CER period for each curve is computed as:

```math
t_{\text{CER}} = \frac{(x_0 - x_k)(1 - \varepsilon)\rho_s}{Y^* \, k_Y a \, \rho_f}
```

## Numerical method

The PDE system is solved by the **method of lines** with:

- **Spatial discretization**: first-order upwind finite differences along the bed height
  (default: 5 nodes).
- **Temporal integration**: explicit Euler stepping (default: 2500 steps).
- **Cumulative mass**: the outlet concentration is integrated in time using the trapezoidal
  rule to obtain the cumulative extracted mass.

The calculated extraction curve is interpolated at the experimental time points for comparison
with measured data.

## Parameter estimation

The model parameters are estimated by minimizing the sum of squared residuals (SSR):

```math
\text{SSR} = \sum_{i=1}^{N_{\text{exp}}} \sum_{j=1}^{m_i}
\left( y_{\text{cal},j}^{(i)} - y_{\text{exp},j}^{(i)} \right)^2
```

When fitting multiple curves simultaneously:
- Each curve has its own ``k_Y a`` and ``k_X a``
- The ratio ``x_k / x_0`` is **shared** across all curves

The optimization uses a global, derivative-free optimizer from
[BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl).
This avoids the need for manual multi-start strategies and handles the
non-convex, bound-constrained search space robustly.

## References

- Sovová, H. (1994). Rate of the vegetable oil extraction with supercritical CO₂ — I. 
  Modelling of extraction curves. *Chemical Engineering Science*, 49(3), 409–414.
