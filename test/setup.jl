using Test
using Logging
using NetworkOptions
using NetworkOptions: bundled_ca_roots

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

function clear_vars!(ENV)
    delete!(ENV, "JULIA_NO_VERIFY_HOSTS")
    delete!(ENV, "JULIA_SSL_NO_VERIFY_HOSTS")
    delete!(ENV, "JULIA_SSH_NO_VERIFY_HOSTS")
end

