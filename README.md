# NetworkOptions

[![Build Status](https://travis-ci.org/JuliaLang/NetworkOptions.jl.svg?branch=master)](https://travis-ci.org/JuliaLang/NetworkOptions.jl)
[![Codecov](https://codecov.io/gh/JuliaLang/NetworkOptions.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaLang/NetworkOptions.jl)

The `NetworkOptions` package acts as a mediator between ways of configuring
network transport mechanisms (SSL/TLS, SSH, proxies, etc.) and Julia packages
that provide access to transport mechanisms. This allows the a common interface
to configuring things like TLS and SSH host verification and proxies via
environment variables (currently) and other configuration mechanisms (in the
future), while packages that need to configure these mechanisms can simply
ask `NetworkOptions` what to do in specific situations without worrying about
how that configuration is expressed.

## API

### ca_roots

```jl
ca_roots() :: Union{Nothing, String}
```
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
of these variables that is set (whether the path exists or not).

### ca_roots_path

```jl
ca_roots_path() :: String
```
The `ca_roots_path()` function is similar to the `ca_roots()` function except
that it always returns a path to a file or directory of PEM-encoded certificate
authority roots. When called on a system like Windows or macOS, where system
root certificates are not stored in the file system, it will currently return
the path to the set of root certificates that are bundled with Julia. (In the
future, this function may instead extract the root certificates from the system
and save them to a file whose path would be returned.)

If it is possible to configure a library that uses TLS to use the system
certificates that is generally preferrable: i.e. it is better to use
`ca_roots()` which returns `nothing` to indicate that the system certs should be
used. The `ca_roots_path()` function should only be used when configuring
libraries which _require_ a path to a file or directory for root certificates.

The default value returned by `ca_roots_path()` may be overridden by setting the
`JULIA_SSL_CA_ROOTS_PATH`, `SSL_CERT_DIR`, or `SSL_CERT_FILE` environment
variables, in which case this function will always return the value of the first
of these variables that is set (whether the path exists or not).

### verify_host

```jl
verify_host(url::AbstractString, transport::AbstractString) -> Bool
verify_host(url::AbstractString) -> Bool
```
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
about. The currently known values are `SSL` (alias `TLS`) and `SSH`. If the
transport is ommitted, the query will return `true` only if the host name should
not be verified regardless of transport.

The host name is matched against the host patterns in the relavent environment
variables depending on whether `transport` is supplied and what its value is:

- `JULIA_NO_VERIFY_HOSTS` — hosts that should not be verified for any transport
- `JULIA_SSL_NO_VERIFY_HOSTS` — hosts that should not be verified for SSL/TLS
- `JULIA_SSH_NO_VERIFY_HOSTS` — hosts that should not be verified for SSH

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

#### Example scenario

Suppose you want to not verify any hosts under `safe.example.com` for all
protocols, skip SSL host verification for just `ssl.example.com`, and skip SSH
host verification for `ssh.example.com` and its immediate first level
subdomains. Then you could set the following environment variable values:
```sh
export JULIA_NO_VERIFY_HOSTS="**.safe.example.com"
export JULIA_SSL_NO_VERIFY_HOSTS="ssl.example.com"
export JULIA_SSH_NO_VERIFY_HOSTS="ssh.example.com,*.ssh.example.com"
```
With this configuration:

- `example.com` would be verified for all protocols
- `safe.example.com`, `api.safe.example.com`, `v1.api.safe.example.com` and so
  on would be unverified for all transports
- `ssl.example.com` would be unverified for SSL/TLS transport
- `sub.ssl.example.com` would be verified for all transports, including SSL/TLS
- `ssh.example.com` and `sub.ssh.example.com` would be unverified for SSH only
- `sub.sub.ssh.example.com` would be verified for all transports

Note that the protocol of `url` need not match the transport mechanism being
queried: the protocol of the URL is entirely discarded. The reason for this is
that the typical usage of this utility function is to configure a library to
enable or disable specific features like TLS host verification based on a URL.
If the URL does not actually use the TLS transport mechanism, then it doesn't
matter if verification for that transport is enabled or not. Moreover, different
protocols can use the same transport: for example, `https` and `ftps` protocols
both use TLS and `ssh`, `scp` and `sftp` protocols all use SSH.
