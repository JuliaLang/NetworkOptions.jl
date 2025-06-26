include("setup.jl")

@testset "ca_roots" begin
    @testset "system certs" begin
        @test isfile(bundled_ca_roots())
        @test_deprecated ca_roots_path() isa String
        @test_deprecated ispath(ca_roots_path())
        if Sys.iswindows() || Sys.isapple()
            @test_deprecated ca_roots_path() == bundled_ca_roots()
            @test_deprecated ca_roots() === nothing
        else
            @test_deprecated ca_roots_path() != bundled_ca_roots()
            @test_deprecated ca_roots() == ca_roots_path()
        end
    end

    @testset "env vars" begin
        unset = @test_deprecated((ca_roots(), ca_roots_path()))
        value = "Why hello!"
        # set only one CA_ROOT_VAR
        for var in CA_ROOTS_VARS
            ENV[var] = value
            @test_deprecated ca_roots() == value
            @test_deprecated ca_roots_path() == value
            ENV[var] = ""
            @test_deprecated ca_roots() == unset[1]
            @test_deprecated ca_roots_path() == unset[2]
            clear_env()
        end
        # set multiple CA_ROOT_VARS with increasing precedence
        ENV["SSL_CERT_DIR"] = "3"
        @test_deprecated ca_roots() == ca_roots_path() == "3"
        ENV["SSL_CERT_FILE"] = "2"
        @test_deprecated ca_roots() == ca_roots_path() == "2"
        ENV["JULIA_SSL_CA_ROOTS_PATH"] = "1"
        @test_deprecated ca_roots() == ca_roots_path() == "1"
        ENV["JULIA_SSL_CA_ROOTS_PATH"] = ""
        @test_deprecated ca_roots() == unset[1]
        @test_deprecated ca_roots_path() == unset[2]
        clear_env()
    end

    @testset "ca_root_locations" begin
        path_sep = Sys.iswindows() ? ';' : ':'

        # Test with no environment variables set
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => nothing,
                "SSL_CERT_DIR" => nothing) do
            # Test with allow_nothing=true (default)
            result = ca_root_locations()
            if Sys.iswindows() || Sys.isapple()
                @test result === nothing
            else
                # On Unix systems, check system locations
                @test result !== nothing
                files, dirs = result
                root = system_ca_roots()
                if root !== nothing
                    @test files == [root]
                    @test isempty(dirs)
                end
            end

            # Test with allow_nothing=false
            result = ca_root_locations(; allow_nothing=false)
            @test result !== nothing
            files, dirs = result
            if Sys.iswindows() || Sys.isapple()
                @test files == [bundled_ca_roots()]
                @test isempty(dirs)
            else
                root = system_ca_roots()
                if root !== nothing
                    @test files == [root]
                    @test isempty(dirs)
                end
            end
        end

        # Test with JULIA_SSL_CA_ROOTS_PATH set to a file
        withenv("JULIA_SSL_CA_ROOTS_PATH" => "/path/to/cert.pem",
                "SSL_CERT_FILE" => nothing,
                "SSL_CERT_DIR" => nothing) do
            result = ca_root_locations()
            @test result !== nothing
            files, dirs = result
            @test files == ["/path/to/cert.pem"]
            @test isempty(dirs)
        end

        # Test with JULIA_SSL_CA_ROOTS_PATH set to a directory
        mktempdir() do tempdir
            withenv("JULIA_SSL_CA_ROOTS_PATH" => tempdir,
                    "SSL_CERT_FILE" => nothing,
                    "SSL_CERT_DIR" => nothing) do
                result = ca_root_locations()
                @test result !== nothing
                files, dirs = result
                @test isempty(files)
                @test dirs == [tempdir]
            end
        end

        # Test with JULIA_SSL_CA_ROOTS_PATH set to empty string
        withenv("JULIA_SSL_CA_ROOTS_PATH" => "",
                "SSL_CERT_FILE" => "/ignored/cert.pem",
                "SSL_CERT_DIR" => nothing) do
            result = ca_root_locations()
            # Should ignore other variables and return system defaults
            if Sys.iswindows() || Sys.isapple()
                @test result === nothing
            else
                @test result !== nothing
                files, dirs = result
                root = system_ca_roots()
                if root !== nothing
                    @test files == [root]
                    @test isempty(dirs)
                end
            end
        end

        # Test with SSL_CERT_FILE (single path)
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => "/path1/cert.pem",
                "SSL_CERT_DIR" => nothing) do
            result = ca_root_locations()
            @test result !== nothing
            files, dirs = result
            @test files == ["/path1/cert.pem"]
            @test isempty(dirs)
        end

        # Test that SSL_CERT_FILE with delimiter is treated as single path
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => "/path1/cert.pem$(path_sep)/path2/cert.pem",
                "SSL_CERT_DIR" => nothing) do
            result = ca_root_locations()
            @test result !== nothing
            files, dirs = result
            @test files == ["/path1/cert.pem$(path_sep)/path2/cert.pem"]
            @test isempty(dirs)
        end

        # Test with SSL_CERT_DIR containing multiple paths
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => nothing,
                "SSL_CERT_DIR" => "/certs1$(path_sep)/certs2") do
            result = ca_root_locations()
            @test result !== nothing
            files, dirs = result
            @test isempty(files)
            @test dirs == ["/certs1", "/certs2"]
        end

        # Test with both SSL_CERT_FILE and SSL_CERT_DIR
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => "/cert1.pem",
                "SSL_CERT_DIR" => "/certs1$(path_sep)/certs2") do
            result = ca_root_locations()
            @test result !== nothing
            files, dirs = result
            @test files == ["/cert1.pem"]
            @test dirs == ["/certs1", "/certs2"]
        end

        # Test that ca_roots() uses ca_root_locations() correctly
        # Priority should be files over directories
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => "/cert.pem",
                "SSL_CERT_DIR" => "/certs") do
            @test_deprecated ca_roots() == "/cert.pem"
        end

        # Test with only SSL_CERT_DIR
        withenv("JULIA_SSL_CA_ROOTS_PATH" => nothing,
                "SSL_CERT_FILE" => nothing,
                "SSL_CERT_DIR" => "/certs") do
            @test_deprecated ca_roots() == "/certs"
        end
    end
end

@testset "ssh_options" begin
    path_sep = Sys.iswindows() ? ";" : ":"
    bundled = bundled_known_hosts()

    @testset "defaults" begin
        @test ssh_key_pass() === nothing
        @test ssh_dir() == joinpath(homedir(), ".ssh")
        @test ssh_key_name() == "id_rsa"
        @test ssh_key_path() == joinpath(homedir(), ".ssh", "id_rsa")
        @test ssh_pub_key_path() == joinpath(homedir(), ".ssh", "id_rsa.pub")
        default = joinpath(homedir(), ".ssh", "known_hosts")
        @test ssh_known_hosts_files() == [default, bundled]
        @test ssh_known_hosts_file() == (ispath(default) ? default : bundled)
    end

    @testset "SSH_KEY_PASS" begin
        password = "Julia is awesome!"
        ENV["SSH_KEY_PASS"] = password
        @test ssh_key_pass() === password
        clear_env()
    end

    @testset "SSH_DIR" begin
        dir = tempname()
        ENV["SSH_DIR"] = dir
        @test ssh_dir() == dir
        @test ssh_key_name() == "id_rsa"
        @test ssh_key_path() == joinpath(dir, "id_rsa")
        @test ssh_pub_key_path() == joinpath(dir, "id_rsa.pub")
        default = joinpath(dir, "known_hosts")
        @test ssh_known_hosts_files() == [default, bundled]
        @test ssh_known_hosts_file() == bundled
        clear_env()
    end

    @testset "SSH_KEY_NAME" begin
        ENV["SSH_KEY_NAME"] = "my_key"
        @test ssh_dir() == joinpath(homedir(), ".ssh")
        @test ssh_key_name() == "my_key"
        @test ssh_key_path() == joinpath(homedir(), ".ssh", "my_key")
        @test ssh_pub_key_path() == joinpath(homedir(), ".ssh", "my_key.pub")
        clear_env()
    end

    @testset "SSH_KEY_PATH" begin
        key_path = tempname()
        ENV["SSH_KEY_PATH"] = key_path
        @test ssh_dir() == joinpath(homedir(), ".ssh")
        @test ssh_key_name() == "id_rsa"
        @test ssh_key_path() == key_path
        @test ssh_pub_key_path() == "$key_path.pub"
        clear_env()
    end

    @testset "SSH_PUB_KEY_PATH" begin
        pub_key_path = tempname()
        ENV["SSH_PUB_KEY_PATH"] = pub_key_path
        @test ssh_dir() == joinpath(homedir(), ".ssh")
        @test ssh_key_name() == "id_rsa"
        @test ssh_key_path() == joinpath(homedir(), ".ssh", "id_rsa")
        @test ssh_pub_key_path() == pub_key_path
        clear_env()
    end

    @testset "SSH_KEY_PATH & SSH_PUB_KEY_PATH" begin
        key_path = tempname()
        pub_key_path = tempname()
        ENV["SSH_KEY_PATH"] = key_path
        ENV["SSH_PUB_KEY_PATH"] = pub_key_path
        @test ssh_dir() == joinpath(homedir(), ".ssh")
        @test ssh_key_name() == "id_rsa"
        @test ssh_key_path() == key_path
        @test ssh_pub_key_path() == pub_key_path
        clear_env()
    end

    @testset "SSH_KNOWN_HOSTS_FILES" begin
        # empty
        ENV["SSH_KNOWN_HOSTS_FILES"] = ""
        @test ssh_known_hosts_files() == []
        file = ssh_known_hosts_file()
        @test !isfile(file) || isempty(read(file))
        # explicit default
        ENV["SSH_KNOWN_HOSTS_FILES"] = path_sep
        default = joinpath(homedir(), ".ssh", "known_hosts")
        @test ssh_known_hosts_files() == [default, bundled]
        @test ssh_known_hosts_file() == (ispath(default) ? default : bundled)
        # single path
        path = tempname()
        ENV["SSH_KNOWN_HOSTS_FILES"] = path
        @test ssh_known_hosts_files() == [path]
        @test ssh_known_hosts_file() == path
        # multi path
        paths = [tempname() for _ = 1:3]
        ENV["SSH_KNOWN_HOSTS_FILES"] = join(paths, path_sep)
        @test ssh_known_hosts_files() == paths
        @test ssh_known_hosts_file() == paths[1]
        touch(paths[3])
        @test ssh_known_hosts_files() == paths
        @test ssh_known_hosts_file() == paths[3]
        touch(paths[2])
        @test ssh_known_hosts_files() == paths
        @test ssh_known_hosts_file() == paths[2]
        rm(paths[2])
        rm(paths[3])
        # prepend path
        path = tempname()
        ENV["SSH_KNOWN_HOSTS_FILES"] = path * path_sep
        @test ssh_known_hosts_files() == [path, default, bundled]
        @test ssh_known_hosts_file() == (ispath(default) ? default : bundled)
        touch(path)
        @test ssh_known_hosts_file() == path
        rm(path)
        # append path
        path = tempname()
        ENV["SSH_KNOWN_HOSTS_FILES"] = path_sep * path
        @test ssh_known_hosts_files() == [default, bundled, path]
        @test ssh_known_hosts_file() == (ispath(default) ? default : bundled)
        # prepend default (no effect)
        ENV["SSH_KNOWN_HOSTS_FILES"] = default * path_sep
        @test ssh_known_hosts_files() == [default, bundled]
        @test ssh_known_hosts_file() == (ispath(default) ? default : bundled)
        # prepend bundled (swap order)
        ENV["SSH_KNOWN_HOSTS_FILES"] = bundled * path_sep
        @test ssh_known_hosts_files() == [bundled, default]
        @test ssh_known_hosts_file() == bundled
    end
end

@testset "verify_host" begin
    @testset "verify everything" begin
        for url in TEST_URLS
            @test verify_host(url) # cover this API once
            for transport in TRANSPORTS
                @test verify_host(url, transport)
            end
        end
    end

    @testset "bad patterns fail safely" begin
        patterns = [
            "~", "* *", "*~*", "***", "∀", "~, ***",
            ".com", "*com", ".*com", ".example.com", "*example.com",
        ]
        for url in TEST_URLS, transport in TRANSPORTS
            for pattern in patterns
                # NB: Setting ENV here in the inner loop so that we defeat
                # the ENV_HOST_PATTERN_CACHE and get a warning every time.
                ENV["JULIA_NO_VERIFY_HOSTS"] = pattern
                @test @test_logs (:warn, r"bad host pattern in ENV") match_mode=:any verify_host(url, transport)
            end
        end
        clear_env()
    end

    @testset "only ignore bad patterns in list" begin
        patterns = ["ok.com,~", "^, ok.com ,, !"]
        for url in TEST_URLS
            for pattern in patterns
                ENV["JULIA_NO_VERIFY_HOSTS"] = pattern
                @test @test_logs (:warn, r"bad host pattern in ENV") match_mode=:any verify_host(url)
            end
            @test @test_logs min_level=Logging.Error !verify_host("ok.com")
        end
        clear_env()
    end

    @testset "verify nothing" begin
        for pattern in ["**", "example.com,**", "**,, blah"]
            ENV["JULIA_NO_VERIFY_HOSTS"] = pattern
            for url in TEST_URLS, transport in TRANSPORTS
                @test !verify_host(url, transport)
            end
        end
        clear_env()
    end

    @testset "SSL no verify" begin
        for pattern in ["**", "example.com,**", "**, blah"]
            ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = pattern
            for url in TEST_URLS, transport in TRANSPORTS
                no_verify = transport in ["ssl", "tls"]
                @test verify_host(url, transport) == !no_verify
            end
        end
        clear_env()
    end

    @testset "SSH no verify" begin
        for pattern in ["**", "example.com,**", "**, blah"]
            ENV["JULIA_SSH_NO_VERIFY_HOSTS"] = pattern
            for url in TEST_URLS, transport in TRANSPORTS
                no_verify = transport == "ssh"
                @test verify_host(url, transport) == !no_verify
            end
        end
        clear_env()
    end

    @testset "complex scenario" begin
        ENV["JULIA_NO_VERIFY_HOSTS"] = "**.safe.example.com"
        ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = "ssl.example.com"
        ENV["JULIA_SSH_NO_VERIFY_HOSTS"] = "ssh.example.com,*.ssh.example.com"
        for transport in TRANSPORTS
            for url in TEST_URLS
                @test verify_host(url, transport)
            end
            hosts = [
                "safe.example.com",
                "api.SAFE.example.COM",
                "v1.API.safe.eXample.com",
            ]
            for host in hosts, (url, valid) in host_variants(host)
                @test verify_host(url, transport) == !valid
            end
            hosts = [
                "ssl.example.com",
                "SSL.example.com",
                "ssl.Example.COM",
            ]
            for host in hosts, (url, valid) in host_variants(host)
                no_verify = valid && transport in ["ssl", "tls"]
                @test verify_host(url, transport) == !no_verify
            end
            hosts = [
                "sub.ssl.example.com",
                "sub.SSL.example.com",
                "ssl..example.com",
            ]
            for host in hosts, (url, valid) in host_variants(host)
                @test verify_host(url, transport)
            end
            hosts = [
                "ssh.example.com",
                "ssh.EXAMPLE.com",
                "sub.ssh.example.com",
                "sub.ssh.example.COM",
            ]
            for host in hosts, (url, valid) in host_variants(host)
                no_verify = valid && transport == "ssh"
                @test verify_host(url, transport) == !no_verify
            end
            hosts = [
                "v1.api.ssh.example.com",
                "123.api.SSH.example.COM",
            ]
            for host in hosts, (url, valid) in host_variants(host)
                @test verify_host(url, transport)
            end
        end
        clear_env()
    end

    @testset "transparent proxy" begin
        ENV["JULIA_ALWAYS_VERIFY_HOSTS"] = "**.example.com"
        ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = "**"
        verified_hosts = [
            "example.com",
            "Example.COM",
            "sub.eXampLe.cOm",
            "123.sub.example.COM",
        ]
        unverified_hosts = [
            "com",
            "invalid",
            "github.com",
            "julialang.org",
            "pkg.julialang.org",
        ]
        all_hosts = [verified_hosts .=> true; unverified_hosts .=> false]
        for transport in TRANSPORTS, (host, tls_verified) in all_hosts
            verified = tls_verified || transport ∉ ["tls", "ssl"]
            @test verify_host(host, transport) == verified
        end
        clear_env()
    end
end

reset_env()
