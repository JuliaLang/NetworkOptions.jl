export
    ssh_dir,
    ssh_key_pass,
    ssh_key_name,
    ssh_key_path,
    ssh_pub_key_path,
    ssh_known_hosts_files,
    ssh_known_hosts_file

"""
    ssh_dir() :: String

The `ssh_dir()` function returns the location of the directory where the `ssh`
program keeps/looks for configuration files. By default this is `~/.ssh` but
this can be overridden by setting the envirnoment variable `SSH_DIR`.
"""
ssh_dir() = get(ENV, "SSH_DIR", joinpath(homedir(), ".ssh"))

"""
    ssh_key_pass() :: String

The `ssh_key_pass()` function returns the value of the environment variable
`SSH_KEY_PASS` if it is set or `nothing` if it is not set. In the future, this
may be able to find a password by other means, such as secure system storage, so
packages that need a pawword to decrypt an SSH private key should use this API
instead of directly checking the environment variable so that they gain such
capabilities automatically when they are added.
"""
ssh_key_pass() = get(ENV, "SSH_KEY_PASS", nothing)

"""
    ssh_key_name() :: String

The `ssh_key_name()` function returns the base name of key files that SSH should
use for when estabilishing a connection. There is usually no reason that this
function should be called directly and libraries should generally use the
`ssh_key_path` and `ssh_pub_key_path` functions to get full paths. If the
environment variable `SSH_KEY_NAME` is set then this function returns that;
otherwise it returns `id_rsa` by default.
"""
ssh_key_name() = get(ENV, "SSH_KEY_NAME", "id_rsa")

"""
    ssh_key_path() :: String

The `ssh_key_path()` function returns the path of the SSH private key file that
should be used for SSH connections. If the `SSH_KEY_PATH` environment variable
is set then it will return that value. Otherwise it defaults to returning

    joinpath(ssh_dir(), ssh_key_name())

This default value in turn depends on the `SSH_DIR` and `SSH_KEY_NAME`
environment variables.
"""
function ssh_key_path()
    key_path = get(ENV, "SSH_KEY_PATH", "")
    !isempty(key_path) && return key_path
    return joinpath(ssh_dir(), ssh_key_name())
end

"""
    ssh_pub_key_path() :: String

The `ssh_pub_key_path()` function returns the path of the SSH public key file
that should be used for SSH connections. If the `SSH_PUB_KEY_PATH` environment
variable is set then it will return that value. If that isn't set but
`SSH_KEY_PATH` is set, it will return that path with the `.pub` suffix appended.
If neither is set, it defaults to returning

    joinpath(ssh_dir(), ssh_key_name() * ".pub")

This default value in turn depends on the `SSH_DIR` and `SSH_KEY_NAME`
environment variables.
"""
function ssh_pub_key_path()
    pub_key_path = get(ENV, "SSH_PUB_KEY_PATH", "")
    !isempty(pub_key_path) && return pub_key_path
    key_path = get(ENV, "SSH_KEY_PATH", "")
    !isempty(key_path) && return "$key_path.pub"
    return joinpath(ssh_dir(), ssh_key_name() * ".pub")
end

"""
    ssh_known_hosts_files() :: Vector{String}

The `ssh_known_hosts_files()` function returns a vector of paths of SSH known
hosts files that should be used when establishing the identities of remote
servers for SSH connections. By default this function returns

    [joinpath(ssh_dir(), "known_hosts"), bundled_known_hosts]

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
"""
function ssh_known_hosts_files()
    default = joinpath(ssh_dir(), "known_hosts")
    bundled = joinpath(@__DIR__, "known_hosts")
    value = get(ENV, "SSH_KNOWN_HOSTS_FILES", nothing)
    value === nothing && return [default, bundled]
    isempty(value) && return String[]
    paths = String[]
    for path in split(value, Sys.iswindows() ? ';' : ':')
        if !isempty(path)
            path in paths || push!(paths, path)
        else
            default in paths || push!(paths, default)
            bundled in paths || push!(paths, bundled)
        end
    end
    return paths
end

"""
    ssh_known_hosts_file() :: String

The `ssh_known_hosts_file()` function returns a single path of an SSH known
hosts file that should be used when establishing the identities of remote
servers for SSH connections. It returns the first path returned by
`ssh_known_hosts_files` that actually exists. Callers who can look in more than
one known hosts file should use `ssh_known_hosts_files` instead and look for
host matches in all the files returned as described in that function's docs.
"""
function ssh_known_hosts_file()
    files = ssh_known_hosts_files()
    for file in files
        ispath(file) && return file
    end
    return files[1]
end
