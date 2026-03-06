# Installation

## Installing Julia

### Windows

#### Option 1

Install Julia directly from the Windows Store. Double click on the Julia icon to open the Julia REPL.

#### Option 2

1. Download the Julia installer from [https://julialang.org/downloads/](https://julialang.org/downloads/).
   Choose the **Windows** 64-bit installer (`.exe`).

2. Run the installer. **Important**: check the box **"Add Julia to PATH"** so that you can
   run `julia` from any terminal.

3. After installation, open **PowerShell** or **Command Prompt** and type:

   ```
   julia --version
   ```

   You should see something like `julia version 1.10.x` or later.

!!! tip "Windows tips"
    - If you use **VS Code**, install the
      [Julia extension](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia)
      for syntax highlighting, inline evaluation, and an integrated REPL.

### macOS

Install Julia via [juliaup](https://github.com/JuliaLang/juliaup):

```bash
curl -fsSL https://install.julialang.org | sh
```

Or download the `.dmg` installer from [https://julialang.org/downloads/](https://julialang.org/downloads/).

### Linux

Install Julia via [juliaup](https://github.com/JuliaLang/juliaup):

```bash
curl -fsSL https://install.julialang.org | sh
```

Or download the tarball from [https://julialang.org/downloads/](https://julialang.org/downloads/)
and extract it to a directory of your choice, adding the `bin/` subdirectory to your `PATH`.

## Installing SovovaMulti.jl

Once Julia is installed, start a Julia session and run:

```julia
julia> import Pkg

julia> Pkg.add("SovovaMulti")
```

Or, equivalently, press `]` in the Julia REPL to enter the package manager mode and type:

```
pkg> add SovovaMulti
```

### Verifying the installation

```julia
julia> using SovovaMulti

julia> curve = ExtractionCurve(
           t = [10.0, 30.0, 60.0],
           m_ext = [0.1, 0.5, 1.0],
           temperature = 313.15,
           porosity = 0.4,
           x0 = 0.05,
           solid_density = 1.1,
           solvent_density = 0.8,
           flow_rate = 5.0,
           bed_height = 20.0,
           bed_diameter = 2.0,
           particle_diameter = 0.05,
           solid_mass = 50.0,
           solubility = 0.005,
           viscosity = 0.06,
       )
```

If no error is raised, the package is correctly installed.
