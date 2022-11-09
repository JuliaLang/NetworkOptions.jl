export ca_roots, ca_roots_path

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
ca_roots()::Union{Nothing,String} = _ca_roots(true)

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
ca_roots_path()::String = _ca_roots(false)

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

const SYSTEM_CA_ROOTS_LOCK = ReentrantLock()
const SYSTEM_CA_ROOTS = Ref{String}()

const BEGIN_CERT_REGULAR = "-----BEGIN CERTIFICATE-----"
const BEGIN_CERT_OPENSSL = "-----BEGIN TRUSTED CERTIFICATE-----"
const OPENSSL_WARNING = """
NetworkOptions could only find OpenSSL-specific TLS certificates which cannot be used by MbedTLS. Please open an issue at https://github.com/JuliaLang/NetworkOptions.jl/issues with details about your system, especially where generic non-OpenSSL certificates can be found. See https://stackoverflow.com/questions/55447752/what-does-begin-trusted-certificate-in-a-certificate-mean for more details.
""" |> split |> text -> join(text, " ")

function system_ca_roots()
    lock(SYSTEM_CA_ROOTS_LOCK) do
        isassigned(SYSTEM_CA_ROOTS) && return # from lock()
        search_path = Sys.islinux() ? LINUX_CA_ROOTS :
            Sys.isbsd() && !Sys.isapple() ? BSD_CA_ROOTS : String[]
        openssl_only = false
        for path in search_path
            ispath(path) || continue
            for line in eachline(path)
                if line == BEGIN_CERT_REGULAR
                    SYSTEM_CA_ROOTS[] = path
                    return # from lock()
                elseif line == BEGIN_CERT_OPENSSL
                    openssl_only = true
                end
            end
        end
        # warn if we:
        #  1. did not find any regular certs
        #  2. did find OpenSSL-only certs
        openssl_only && @warn OPENSSL_WARNING
        # TODO: extract system certs on Windows & macOS
        SYSTEM_CA_ROOTS[] = bundled_ca_roots()
    end
    return SYSTEM_CA_ROOTS[]
end

const CA_ROOTS_VARS = [
    "JULIA_SSL_CA_ROOTS_PATH"
    "SSL_CERT_DIR"
    "SSL_CERT_FILE"
]

function _ca_roots(allow_nothing::Bool)
    for var in CA_ROOTS_VARS
        path = get(ENV, var, nothing)
        if path == "" && startswith(var, "JULIA_")
            break # ignore other vars
        end
        if !isempty(something(path, ""))
            return path
        end
    end
    if Sys.iswindows() || Sys.isapple()
        allow_nothing && return # use system certs
    end
    return system_ca_roots()
end
