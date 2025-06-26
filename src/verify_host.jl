export verify_host

"""
    verify_host(url::AbstractString, [transport::AbstractString]) :: Bool

The `verify_host` function tells the caller whether the identity of a host
should be verified when communicating over secure transports like TLS or SSH.
The `url` argument may be:

1. a proper URL staring with `proto://`
2. an `ssh`-style bare host name or host name prefixed with `user@`
3. an `scp`-style host as above, followed by `:` and a path location

In each case the host name part is parsed out and the decision about whether to
verify or not is made based solely on the host name, not anything else about the
input URL. In particular, the protocol of the URL does not matter (more below).

The `transport` argument indicates the kind of transport that the query is
about. The currently known values are `SSL`/`ssl` (alias `TLS`/`tls`) and `SSH`/`ssh`.
If the transport is omitted, the query will return `true` only if the host name should
not be verified regardless of transport.

The host name is matched against the host patterns in the relevant environment
variables depending on whether `transport` is supplied and what its value is:

- `JULIA_NO_VERIFY_HOSTS` — hosts that should not be verified for any transport
- `JULIA_SSL_NO_VERIFY_HOSTS` — hosts that should not be verified for SSL/TLS
- `JULIA_SSH_NO_VERIFY_HOSTS` — hosts that should not be verified for SSH
- `JULIA_ALWAYS_VERIFY_HOSTS` — hosts that should always be verified

The values of each of these variables is a comma-separated list of host name
patterns with the following syntax — each pattern is split on `.` into parts and
each part must one of:

1. A literal domain name component consisting of one or more ASCII letter,
   digit, hyphen or underscore (technically not part of a legal host name, but
   sometimes used). A literal domain name component matches only itself.
2. A `**`, which matches zero or more domain name components.
3. A `*`, which match any one domain name component.

When matching a host name against a pattern list in one of these variables, the
host name is split on `.` into components and that sequence of words is matched
against the pattern: a literal pattern matches exactly one host name component
with that value; a `*` pattern matches exactly one host name component with any
value; a `**` pattern matches any number of host name components. For example:

- `**` matches any host name
- `**.org` matches any host name in the `.org` top-level domain
- `example.com` matches only the exact host name `example.com`
- `*.example.com` matches `api.example.com` but not `example.com` or
  `v1.api.example.com`
- `**.example.com` matches any domain under `example.com`, including
  `example.com` itself, `api.example.com` and `v1.api.example.com`
"""
function verify_host(
    url :: AbstractString,
    tr :: Union{AbstractString, Nothing} = nothing,
)
    host = url_host(url)
    env_host_pattern_match("JULIA_ALWAYS_VERIFY_HOSTS", host) && return true
    env_host_pattern_match("JULIA_NO_VERIFY_HOSTS", host) && return false
    tr === nothing && return true
    return if tr == "SSL" || tr == "ssl" || tr == "TLS" || tr == "tls"
        !env_host_pattern_match("JULIA_SSL_NO_VERIFY_HOSTS", host)
    elseif tr == "SSH" || tr == "ssh"
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

# TODO: What to do when `env_host_pattern_regex` returns `nothing`?
env_host_pattern_match(var::AbstractString, host::AbstractString) =
    occursin(env_host_pattern_regex(var)::Regex, host)
env_host_pattern_match(var::AbstractString, host::Nothing) =
    env_host_pattern_regex(var) === MATCH_ANY_RE


function env_host_pattern_regex(var::AbstractString)
    value = get(ENV, var, nothing)
    if value === nothing
        return MATCH_NONE_RE
    end
    regex = host_pattern_regex(value, var)
    return regex
end

if !@isdefined(contains)
    contains(needle) = haystack -> occursin(needle, haystack)
end

function host_pattern_regex(value::AbstractString, var::AbstractString="")
    match_any = false
    patterns = Vector{String}[]
    for pattern in split(value, r"\s*,\s*", keepempty=false)
        match_any |= pattern == "**"
        parts = split(pattern, '.')
        # emit warning but ignore any pattern we don't recognize;
        # this allows adding syntax without breaking old versions
        if !all(contains(r"^([-\w]+|\*\*?)$"a), parts)
            in = isempty(var) ? "" : " in ENV[$(repr(var))]"
            @warn("bad host pattern$in: $(repr(pattern))")
            continue
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
