# NetworkOptions

[![Build Status](https://github.com/JuliaLang/NetworkOptions.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/JuliaLang/NetworkOptions.jl/actions/workflows/ci.yml)
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
of these variables that is set (whether the path exists or not). If
`JULIA_SSL_CA_ROOTS_PATH` is set to the empty string, then the other variables
are ignored (as if unset); if the other variables are set to the empty string,
they behave is if they are not set.

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

### ssh_dir

```jl
ssh_dir() :: String
```
The `ssh_dir()` function returns the location of the directory where the `ssh`
program keeps/looks for configuration files. By default this is `~/.ssh` but
this can be overridden by setting the environment variable `SSH_DIR`.

### ssh_key_name

```jl
ssh_key_name() :: String
```
The `ssh_key_name()` function returns the base name of key files that SSH should
use for when establishing a connection. There is usually no reason that this
function should be called directly and libraries should generally use the
`ssh_key_path` and `ssh_pub_key_path` functions to get full paths. If the
environment variable `SSH_KEY_NAME` is set then this function returns that;
otherwise it returns `id_rsa` by default.

### ssh_key_path

```jl
ssh_key_path() :: String
```
The `ssh_key_path()` function returns the path of the SSH private key file that
should be used for SSH connections. If the `SSH_KEY_PATH` environment variable
is set then it will return that value. Otherwise it defaults to returning
```jl
joinpath(ssh_dir(), ssh_key_name())
```
This default value in turn depends on the `SSH_DIR` and `SSH_KEY_NAME`
environment variables.

### ssh_pub_key_path

```jl
ssh_pub_key_path() :: String
```
The `ssh_pub_key_path()` function returns the path of the SSH public key file
that should be used for SSH connections. If the `SSH_PUB_KEY_PATH` environment
variable is set then it will return that value. If that isn't set but
`SSH_KEY_PATH` is set, it will return that path with the `.pub` suffix appended.
If neither is set, it defaults to returning
```jl
joinpath(ssh_dir(), ssh_key_name() * ".pub")
```
This default value in turn depends on the `SSH_DIR` and `SSH_KEY_NAME`
environment variables.

### ssh_key_pass

```jl
ssh_key_pass() :: String
```
The `ssh_key_pass()` function returns the value of the environment variable
`SSH_KEY_PASS` if it is set or `nothing` if it is not set. In the future, this
may be able to find a password by other means, such as secure system storage, so
packages that need a password to decrypt an SSH private key should use this API
instead of directly checking the environment variable so that they gain such
capabilities automatically when they are added.

### ssh_known_hosts_files

```jl
ssh_known_hosts_files() :: Vector{String}
```
The `ssh_known_hosts_files()` function returns a vector of paths of SSH known
hosts files that should be used when establishing the identities of remote
servers for SSH connections. By default this function returns
```jl
[joinpath(ssh_dir(), "known_hosts"), bundled_known_hosts]
```
where `bundled_known_hosts` is the path of a copy of a known hosts file that is
bundled with this package (containing known hosts keys for `github.com` and
`gitlab.com`). If the environment variable `SSH_KNOWN_HOSTS_FILES` is set,
however, then its value is split into paths on the `:` character (or on `;` on
Windows) and this vector of paths is returned instead. If any component of this
vector is empty, it is expanded to the default known hosts paths.

Packages that use `ssh_known_hosts_files()` should ideally look for matching
entries by comparing the host name and key types, considering the first entry in
any of the files which matches to be the definitive identity of the host. If the
caller cannot compare the key type (e.g. because it has been hashes) then it
must approximate the above algorithm by looking for all matching entries for a
host in each file: if a file has any entries for a host then one of them must
match; the caller should only continue to search further known hosts files if
there are no entries for the host in question in an earlier file.

### ssh_known_hosts_file

```jl
ssh_known_hosts_file() :: String
```
The `ssh_known_hosts_file()` function returns a single path of an SSH known
hosts file that should be used when establishing the identities of remote
servers for SSH connections. It returns the first path returned by
`ssh_known_hosts_files` that actually exists. Callers who can look in more than
one known hosts file should use `ssh_known_hosts_files` instead and look for
host matches in all the files returned as described in that function's docs.

### verify_host

```jl
verify_host(url::AbstractString, [transport::AbstractString]) :: Bool
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
transport is omitted, the query will return `true` only if the host name should
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

#### Example scenarios

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

A common scenario that occur behind firewalls is for all connections to external
systems to go through a transparent man-in-the-middle proxy: any SSL/TLS
connection to a host under `example.com` would be internal and should have a
valid certificate but any connection outside of `example.com` would go through
the proxy, which uses a self-signed certificate. For such a scenario the best
solution would be to deploy a CA root certificate to all clients, but if that's
not possible, then configuring clients to verify hosts under `example.com` but
not verify other SSL/TLS connections would be a viable solution. In fact, as
long as the man-in-the-middle proxy verifies all upstream TLS connections, this
is still secure (although not private from the proxy, of course). Such a
configuration can be accomplished with the following exports:
```sh
export JULIA_ALWAYS_VERIFY_HOSTS="**.example.com"
export JULIA_SSL_NO_VERIFY_HOSTS="**"
```
This configuration causes all domains under `example.com` to always be verified
for all protocols, including SSL/TLS, while skipping host verification for SSL/TLS
connections to all other hosts.
