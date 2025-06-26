export ca_roots, ca_roots_path, ca_root_locations

"""
    ca_roots() :: Union{Nothing, String}

The `ca_roots()` function tells the caller where, if anywhere, to find a file or
directory of PEM-encoded certificate authority roots. By default, on systems
like Windows and macOS where the built-in TLS engines know how to verify hosts
using the system's built-in certificate verification mechanism, this function
will return `nothing`. On classic UNIX systems (excluding macOS), root
certificates are typically stored in a file in `/etc`: the common places for the
current UNIX system will be searched and if one of these paths exists, it will
be returned; if none of these typical root certificate paths exist, then the
path to the set of root certificates that are bundled with Julia is returned.

The default value returned by `ca_roots()` may be overridden by setting the
`JULIA_SSL_CA_ROOTS_PATH`, `SSL_CERT_DIR`, or `SSL_CERT_FILE` environment
variables, in which case this function will always return the value of the first
of these variables that is set (whether the path exists or not). If
`JULIA_SSL_CA_ROOTS_PATH` is set to the empty string, then the other variables
are ignored (as if unset); if the other variables are set to the empty string,
they behave is if they are not set.
"""
function ca_roots()::Union{Nothing,String}
    Base.depwarn("`ca_roots()` is deprecated. Use `ca_root_locations()` instead.", :ca_roots)
    return _ca_roots(true)
end

"""
    ca_roots_path() :: String

The `ca_roots_path()` function is similar to the `ca_roots()` function except
that it always returns a path to a file or directory of PEM-encoded certificate
authority roots. When called on a system like Windows or macOS, where system
root certificates are not stored in the file system, it will currently return
the path to the set of root certificates that are bundled with Julia. (In the
future, this function may instead extract the root certificates from the system
and save them to a file whose path would be returned.)

If it is possible to configure a library that uses TLS to use the system
certificates that is generally preferable: i.e. it is better to use
`ca_roots()` which returns `nothing` to indicate that the system certs should be
used. The `ca_roots_path()` function should only be used when configuring
libraries which _require_ a path to a file or directory for root certificates.

The default value returned by `ca_roots_path()` may be overridden by setting the
`JULIA_SSL_CA_ROOTS_PATH`, `SSL_CERT_DIR`, or `SSL_CERT_FILE` environment
variables, in which case this function will always return the value of the first
of these variables that is set (whether the path exists or not). If
`JULIA_SSL_CA_ROOTS_PATH` is set to the empty string, then the other variables
are ignored (as if unset); if the other variables are set to the empty string,
they behave is if they are not set.
"""
function ca_roots_path()::String
    Base.depwarn("`ca_roots_path()` is deprecated. Use `ca_root_locations(allow_nothing=false)` instead.", :ca_roots_path)
    return _ca_roots(false)
end

"""
    ca_root_locations(; allow_nothing::Bool=true) :: Union{Nothing, Tuple{Vector{String}, Vector{String}}}

The `ca_root_locations()` function returns certificate locations for the current system.

If `allow_nothing` is `true` (default), returns `nothing` on systems like Windows and macOS
where the built-in TLS engines know how to verify hosts using the system's built-in
certificate verification mechanism.

Otherwise, returns a tuple of two vectors: (files, directories). The first vector contains
paths to certificate files, and the second vector contains paths to certificate directories.
SSL_CERT_FILE specifies a single certificate file, while SSL_CERT_DIR can contain a
delimiter-separated list of directories.

The paths are determined by checking the following environment variables in order:
1. `JULIA_SSL_CA_ROOTS_PATH` - If set, other variables are ignored
2. `SSL_CERT_FILE` - Path to a single certificate file
3. `SSL_CERT_DIR` - Delimiter-separated list of certificate directories

If no environment variables are set, system default locations are returned.
"""
function ca_root_locations(; allow_nothing::Bool=true)::Union{Nothing, Tuple{Vector{String}, Vector{String}}}
    files = String[]
    dirs = String[]

    # Check for JULIA_SSL_CA_ROOTS_PATH first
    julia_path = get(ENV, "JULIA_SSL_CA_ROOTS_PATH", nothing)
    if julia_path == ""
        # Empty string means ignore other variables
        return _system_ca_root_locations()
    elseif julia_path !== nothing
        # JULIA_SSL_CA_ROOTS_PATH is set, determine if it's a file or directory
        if isdir(julia_path)
            push!(dirs, julia_path)
        else
            push!(files, julia_path)
        end
        return (files, dirs)
    end

    # Parse SSL_CERT_FILE (single file path)
    cert_file = get(ENV, "SSL_CERT_FILE", "")
    if !isempty(cert_file)
        push!(files, cert_file)
    end

    # Parse SSL_CERT_DIR
    cert_dir = get(ENV, "SSL_CERT_DIR", "")
    if !isempty(cert_dir)
        delimiter = Sys.iswindows() ? ';' : ':'
        append!(dirs, split(cert_dir, delimiter; keepempty=false))
    end

    # If no environment variables were set, check system defaults
    if isempty(files) && isempty(dirs)
        # If on Windows/macOS and allow_nothing is true, return nothing
        if allow_nothing && (Sys.iswindows() || Sys.isapple())
            return nothing
        end
        return _system_ca_root_locations()
    end

    return (files, dirs)
end

# Helper function to get system default certificate locations
function _system_ca_root_locations()::Tuple{Vector{String}, Vector{String}}
    files = String[]
    dirs = String[]

    # System CA roots are always files, not directories
    root = system_ca_roots()
    if root !== nothing
        push!(files, root)
    end

    return (files, dirs)
end

# NOTE: this has to be a function not a constant since the
# value of Sys.BINDIR changes from build time to run time.
bundled_ca_roots() =
    normpath(Sys.BINDIR::String, "..", "share", "julia", "cert.pem")

const LINUX_CA_ROOTS = [
    "/etc/ssl/cert.pem"                                 # Alpine Linux
    "/etc/ssl/ca-bundle.pem"                            # OpenSUSE
    "/etc/ssl/ca-certificates.pem"                      # OpenSUSE
    "/etc/ssl/certs/ca-bundle.crt"                      # Debian/Ubuntu/Gentoo etc.
    "/etc/ssl/certs/ca-certificates.crt"                # Debian/Ubuntu/Gentoo etc.
    "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem" # CentOS/RHEL 7
    "/etc/pki/tls/certs/ca-bundle.crt"                  # Fedora/RHEL 6
    "/etc/pki/tls/certs/ca-certificates.crt"            # Fedora/RHEL 6
    "/etc/pki/tls/cacert.pem"                           # OpenELEC
]

const BSD_CA_ROOTS = [
    "/etc/ssl/cert.pem"                                 # OpenBSD
    "/usr/local/share/certs/ca-root-nss.crt"            # FreeBSD
    "/usr/local/etc/ssl/cert.pem"                       # FreeBSD
]

const BEGIN_CERT_REGULAR = "-----BEGIN CERTIFICATE-----"
const BEGIN_CERT_OPENSSL = "-----BEGIN TRUSTED CERTIFICATE-----"

const system_ca_roots = OncePerProcess{String}() do
    search_path = Sys.islinux() ? LINUX_CA_ROOTS :
        Sys.isbsd() && !Sys.isapple() ? BSD_CA_ROOTS : String[]
    for path in search_path
        ispath(path) || continue
        for line in eachline(path)
            if line in [BEGIN_CERT_REGULAR, BEGIN_CERT_OPENSSL]
                return path
            end
        end
    end
    # TODO: extract system certs on Windows & macOS
    return bundled_ca_roots()
end

const CA_ROOTS_VARS = [
    "JULIA_SSL_CA_ROOTS_PATH"
    "SSL_CERT_FILE"
    "SSL_CERT_DIR"
]

function _ca_roots(allow_nothing::Bool)
    result = ca_root_locations(; allow_nothing)
    result === nothing && return nothing

    files, dirs = result
    # Prioritize files over directories for backward compatibility
    !isempty(files) && return first(files)
    @assert !isempty(dirs) "Should always have at least the bundled CA roots"
    return first(dirs)
end
