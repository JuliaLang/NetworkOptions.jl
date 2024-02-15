module NetworkOptions

include("ca_roots.jl")
include("ssh_options.jl")
include("verify_host.jl")

function __init__()
    SYSTEM_CA_ROOTS[] = nothing
    BUNDLED_KNOWN_HOSTS_FILE[] = nothing
    empty!(ENV_HOST_PATTERN_CACHE)
end

end # module
