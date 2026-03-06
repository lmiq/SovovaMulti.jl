# Graphical User Interface

SovovaMulti includes a **built-in web GUI** — no extra packages or configuration required.
Launch it directly from the Julia REPL:

```julia
using SovovaMulti
sovovagui()
```

This starts a local HTTP server and opens your default browser at `http://127.0.0.1:9876`.

## Features

In the browser interface you can:

- **Upload** a data file (`.txt`, `.csv`, `.dat`, or `.xlsx`) with time and replicate columns
- **Fill in** all operating conditions through form fields (temperature, porosity, densities, etc.)
- **Configure** optimizer bounds and maximum evaluations
- **Run** the fitting and see results directly in the browser

No Julia code required — everything is done through the graphical form.

## Options

```julia
sovovagui(port=8080, launch=false)
```

| Keyword | Default | Description |
|---------|---------|-------------|
| `port`  | `9876`  | Local port for the HTTP server |
| `launch`| `true`  | Automatically open the browser |

## Stopping the server

Press **Ctrl-C** in the REPL, or call `close(server)` on the returned server object:

```julia
server = sovovagui()
# ... use the GUI ...
close(server)
```

## API

```@docs
sovovagui
```
