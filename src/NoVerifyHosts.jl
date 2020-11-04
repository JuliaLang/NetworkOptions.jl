module NoVerifyHosts

export verify_host

"""
    verify_host(url::AbstractString, transport::AbstractString) -> Bool
    verify_host(url::AbstractString) -> Bool

This is a utility function that can be used to check if the identity of a host
should be verified when communicating over secure transports like HTTPS or SSH.
The `url` argument may be a bare host name, a host name prefixed with `user@` in
the style of SSH, or a URL, in which case the host name is parsed out of the
`url`. The `transport` argument indicates the kind of transport. The currently
known values are `SSL` (alias `TLS`) and `SSH`. If the transport is ommitted,
the query will only return `true` for URLs for which the host should not be
verified regardless of transport. The host name is matched against the host
pattern in the relavent environment variables:

- `JULIA_NO_VERIFY_HOSTS` — hosts that should not be verified for any transport
- `JULIA_SSL_NO_VERIFY_HOSTS` — hosts that should not be verified for SSL/TLS
- `JULIA_SSH_NO_VERIFY_HOSTS` — hosts that should not be verified for SSH

The value of these variables is a comma-separated list of host patterns. Each
host pattern consists of one or more parts, each of which may be a literal
domain name part (letters, numbers and dashes), `*` or `**`. A literal domain
name part matches only itself; a `*` part is a wildcard matching exactly one
host name part; a `**` part is a wildcard matching zero or more host name parts.
To match a pattern list, an entire host name must match one of the patterns.
Some examples:

- `**` matches any host name
- `**.org` matches any host name in the `.org` top-level domain
- `example.com` matches only the exact host name `example.com`
- `*.example.com` matches `api.example.com` but not `example.com` or
  `v1.api.example.com`
- `**.example.com` matches any domain under `example.com`, including
  `example.com` itself, `api.example.com` and `v1.api.example.com`

If you want to skip host verification all domains under `safe.example.com` for
all protocols, skip SSL host verification for `ssl.example.com`, and skip SSH
host verification for `ssh.example.com` and its immediate first level
subdomains, you could set the following environment variable values:
```sh
export JULIA_NO_VERIFY_HOSTS="**.safe.example.com"
export JULIA_SSL_NO_VERIFY_HOSTS="ssl.example.com"
export JULIA_SSH_NO_VERIFY_HOSTS="ssh.example.com,*.ssh.example.com"
```
"""
function verify_host(
    url :: AbstractString,
    transport :: Union{AbstractString, Nothing} = nothing,
)
    host = url_host(url)
    if env_host_pattern_match("JULIA_NO_VERIFY_HOSTS", host)
        return false # don't verify
    end
    transport = transport === nothing ? nothing : uppercase(transport)
    return if transport in ("SSL", "TLS")
        !env_host_pattern_match("JULIA_SSL_NO_VERIFY_HOSTS", host)
    elseif transport == "SSH"
        !env_host_pattern_match("JULIA_SSH_NO_VERIFY_HOSTS", host)
    else
        true # do verify
    end
end

function url_host(url::AbstractString)
    m = match(r"^(?:[a-z]+)://(?:[^@/]+@)?([-\w\.]+)"ai, url)
    m !== nothing && return m.captures[1]
    m = match(r"^(?:[-\w\.]+@)?([-\w\.]+)(?:$|:)"a, url)
    m !== nothing && return m.captures[1]
    return nothing # couldn't parse
end

const MATCH_ANY_RE = r""
const MATCH_NONE_RE = r"$.^"

env_host_pattern_match(var::AbstractString, host::AbstractString) =
    occursin(env_host_pattern_regex(var), host)
env_host_pattern_match(var::AbstractString, host::Nothing) =
    env_host_pattern_regex(var) === MATCH_ANY_RE

const HOST_PATTERN_LOCK = ReentrantLock()
const HOST_PATTERN_CACHE = Dict{String,Tuple{String,Regex}}()

function env_host_pattern_regex(var::AbstractString)
    lock(HOST_PATTERN_LOCK) do
        value = get(ENV, var, nothing)
        if value === nothing
            delete!(HOST_PATTERN_CACHE, var)
            return MATCH_NONE_RE
        end
        old_value, regex = get(HOST_PATTERN_CACHE, var, (nothing, nothing))
        old_value == value && return regex
        regex = host_pattern_regex(value, var)
        HOST_PATTERN_CACHE[var] = (value, regex)
        return regex
    end
end

function host_pattern_regex(value::AbstractString, var::AbstractString="")
    match_any = false
    patterns = Vector{String}[]
    for pattern in split(value, r"\s*,\s*", keepempty=false)
        match_any |= pattern == "**"
        parts = split(pattern, '.')
        if !all(occursin(r"^([-\w]+|\*\*?)$"a, p) for p in parts)
            mid = isempty(var) ? "" : "ENV[$(repr(var))] = "
            @warn("invalid host pattern: $mid$(repr(value))")
            return MATCH_NONE_RE
        end
        push!(patterns, parts)
    end
    match_any && return MATCH_ANY_RE
    isempty(patterns) && return MATCH_NONE_RE
    regex = ""
    for parts in patterns
        re = ""
        for (i, part) in enumerate(parts)
            re *= if i < length(parts)
                part == "*"  ? "[-\\w]+\\." :
                part == "**" ? "(?:[-\\w]+\\.)*" : "$part\\."
            else
                part == "*"  ? "[-\\w]+" :
                part == "**" ? "(?:[-\\w]+\\.)*[-\\w]+" : part
            end
        end
        regex = isempty(regex) ? re : "$regex|$re"
    end
    return Regex("^(?:$regex)\$", "ai")
end

end # module
