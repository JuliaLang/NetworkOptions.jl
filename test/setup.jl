using Test
using Logging
using NetworkOptions
using NetworkOptions: CA_ROOTS_VARS, bundled_ca_roots, bundled_known_hosts

const pkg_dir = dirname(@__DIR__)

const TEST_URLS = [
    "" # not a valid host name
    "com"
    ".com" # not a valid host name
    "example.com"
    "user@example.com"
    "https://example.com"
    "xyz://example.com" # protocol doesn't matter
    "\x02H2ݼtOٲ\0RƆW9\e]B>#ǲR" # not a valid host name
]

const TRANSPORTS = [nothing, "ssl", "tls", "ssh", "xyz"]

host_variants(host::AbstractString) = Dict(
    "$host"              => true,
    ".$host"             => false,
    "$host."             => false,
    "/$host"             => false,
    "$host/"             => false,
    "user@$host"         => true,
    "user@$host:path"    => true,
    "user@$host:/path"   => true,
    "user@$host/"        => false,
    "user@$host/:"       => false,
    "user@$host/path"    => false,
    "user@$host/:path"   => false,
    "user@$host."        => false,
    "user@.$host"        => false,
    "@$host"             => false,
    "$host@"             => false,
    "://$host"           => false,
    "https://$host"      => true,
    "https://$host/"     => true,
    "https://$host/path" => true,
    "https://$host."     => false,
    "https://.$host"     => false,
    "https:/$host"       => false,
    "https:///$host"     => false,
    "xyz://$host"        => true,
    "xyz://$host."       => false,
    "xyz://.$host"       => false,
)

const VARIABLES = [
    "JULIA_SSL_CA_ROOTS_PATH"
    "SSL_CERT_DIR"
    "SSL_CERT_FILE"
    "JULIA_NO_VERIFY_HOSTS"
    "JULIA_SSH_NO_VERIFY_HOSTS"
    "JULIA_SSL_NO_VERIFY_HOSTS"
    "JULIA_ALWAYS_VERIFY_HOSTS"
    "SSH_DIR"
    "SSH_KEY_NAME"
    "SSH_KEY_PASS"
    "SSH_KEY_PATH"
    "SSH_PUB_KEY_PATH"
    "SSH_KNOWN_HOSTS_FILES"
]

const SAVED_VARS = Dict{String,Union{String,Nothing}}(
    var => nothing for var in VARIABLES
)

function save_env()
    for var in VARIABLES
        SAVED_VARS[var] = get(ENV, var, nothing)
    end
end

function reset_env()
    for var in VARIABLES
        val = get(SAVED_VARS, var, nothing)
        if val !== nothing
            ENV[var] = val
        else
            delete!(ENV, var)
        end
    end
end

function clear_env()
    for var in VARIABLES
        delete!(ENV, var)
    end
end

save_env()
clear_env()
