# NoVerifyHosts

[![Build Status](https://travis-ci.org/JuliaLang/NoVerifyHosts.jl.svg?branch=master)](https://travis-ci.org/JuliaLang/NoVerifyHosts.jl)
[![Codecov](https://codecov.io/gh/JuliaLang/NoVerifyHosts.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaLang/NoVerifyHosts.jl)

The `NoVerifyHosts` package provides a since utility function `verify_hosts`
which allows the caller to inderectly make host verification decisions based on
the values of three environment variables:

- `JULIA_NO_VERIFY_HOSTS` — hosts that should not be verified for any transport
- `JULIA_SSL_NO_VERIFY_HOSTS` — hosts that should not be verified for SSL/TLS
- `JULIA_SSH_NO_VERIFY_HOSTS` — hosts that should not be verified for SSH

Each of these variables can be set to a comma-separated list of host patterns
which determines a set of host names that should not be verified for various
secure transport mechanisms. The `JULIA_NO_VERIFY_HOSTS` describes a set of host
names whose identities should not be verified for any transport mechanism, while
the `JULIA_SSL_NO_VERIFY_HOSTS` and `JULIA_SSH_NO_VERIFY_HOSTS` variables
describe sets of host names whose identities should not be verified for the
SSL/TLS and SSH transport mechanisms, respectively.

The values of each of these variables is a comma-separated list of host name
patterns with the following syntax: each pattern is split on `.` into parts and
each part must one of:

1. A literal domain name component consisting of one or more ASCII letter,
   digit,  hyphen or underscore (technically not part of a legal host name, but
   sometimes used). A literal domain name component matches only itself.
2. A `**`, which matches zero or more domain name components.
3. A `*`, which match any one domain name component.

To match a pattern list, an entire host name must match one of the patterns.
For example:

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

## API

```jl
verify_host(url::AbstractString, transport::AbstractString) -> Bool
verify_host(url::AbstractString) -> Bool
```
This is a utility function that can be used to check if the identity of a host
should be verified when communicating over secure transports like HTTPS or SSH.
The `url` argument may be a bare host name, a host name prefixed with `user@` in
the style of SSH, or a URL, in which case the host name is parsed out of the
`url`. The `transport` argument indicates the kind of transport. The currently
known values are `SSL` (alias `TLS`) and `SSH`. If the transport is ommitted,
the query will only return `true` for URLs for which the host should not be
verified regardless of transport. The value of `transport` is case insensitive,
so `ssh` and `SSH` both indicate a query for the SSH transport protocol.

Note that the protocol of `url` need not match the transport mechanism being
queried: the protocol of the URL is entirely discarded. The reason for this is
that the typical usage of this utility function is to configure a library to
enable or disable specific features like TLS host verification based on a URL.
If the URL does not actually use the TLS transport mechanism, then it doesn't
matter if verification for that transport is enabled or not. Moreover, different
protocols can use the same transport: for example, `https` and `ftps` protocols
both use TLS and `ssh`, `scp` and `sftp` protocols all use SSH.
