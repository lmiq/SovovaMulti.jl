using Documenter
using SovovaMulti

using Documenter.Remotes: GitHub

makedocs(;
    modules=[SovovaMulti],
    sitename="SovovaMulti.jl",
    repo=GitHub("lmiq", "SovovaMulti.jl"),
    pages=[
        "Home" => "index.md",
        "Installation" => "installation.md",
        "GUI" => "gui.md",
        "Advanced usage" => "usage.md",
        "Model" => "model.md",
        "API Reference" => "api.md",
    ],
    warnonly=true,
)

deploydocs(;
    repo="github.com/lmiq/SovovaMulti.jl",
    devbranch="main",
    push_preview=true,
)
