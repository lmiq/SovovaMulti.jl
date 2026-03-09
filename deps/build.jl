# deps/build.jl — executed automatically by Pkg.build() / Pkg.Apps.add()
#
# Creates a desktop shortcut for the SovovaMulti GUI.
# If shortcut creation fails for any reason (headless server, missing desktop, etc.)
# the build succeeds anyway — the shortcut can always be created manually with:
#
#   using SovovaMulti; create_shortcut()

try
    using SovovaMulti
    create_shortcut()
catch e
    @warn "SovovaMulti: could not create desktop shortcut (run `create_shortcut()` manually)" exception=e
end
