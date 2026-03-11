```@meta
CollapsedDocStrings = true
```

# API Reference

## Input

```@docs
ExtractionCurve
```

## Data readers

```@docs
TextTable
ExcelTable
```

## Simulation

```@docs
SovovaMulti.simulate
```

## Fitting

```@docs
fit_model
param_spec
```

Available model types (pass an instance as the first argument to `fit_model`; omit for the default Sovová PDE model):

```@docs
Sovova
Reverchon
Esquivel
Nguyen
Zekovic
VeljkovicMilenovic
PKM
SplineModel
```

## Output

```@docs
ModelFitResult
```

## Graphical Interface

See the [GUI](@ref "Graphical User Interface") page.
