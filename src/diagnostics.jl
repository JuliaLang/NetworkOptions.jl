# NetworkOptions.__diagnostics__()
function __diagnostics__(io::IO)
    indent = "  "
    name_list = [
        "JULIA_ALWAYS_VERIFY_HOSTS",
        "JULIA_NO_VERIFY_HOSTS",
        "JULIA_SSH_NO_VERIFY_HOSTS",
        "JULIA_SSL_CA_ROOTS_PATH",
        "JULIA_SSL_NO_VERIFY_HOSTS",
        "SSH_DIR",
        "SSH_KEY_NAME",
        "SSH_KEY_PASS",
        "SSH_KEY_PATH",
        "SSH_KNOWN_HOSTS_FILES",
        "SSH_PUB_KEY_PATH",
        "SSL_CERT_DIR",
        "SSL_CERT_FILE",
    ]
    lines_to_print = Tuple{String, String}[]
    environment = ENV
    for name in name_list
        if haskey(environment, name)
            value = environment[name]
            if isempty(value)
                description = "[empty]"
            else
                if isempty(strip(value))
                    description = "[whitespace]"
                else
                    description = "***"
                end
            end
            line = (name, description)
            push!(lines_to_print, line)
        end
    end
    if isempty(lines_to_print)
        println(io, "Relevant environment variables: [none]")
    else
        println(io, "Relevant environment variables:")
        all_names = getindex.(lines_to_print, Ref(1))
        max_name_length = maximum(length.(all_names))
        name_pad_length = length(indent) + max_name_length + 1
        for (name, description) in lines_to_print
            name_padded = rpad("$(indent)$(name):", name_pad_length)
            println(io, "$(name_padded) $(description)")
        end
    end
    return nothing
end
