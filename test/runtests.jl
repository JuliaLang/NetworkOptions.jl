include("setup.jl")

save_env()
clear_env()

@testset "ca_roots" begin
    @testset "system certs" begin
        @test isfile(bundled_ca_roots())
        @test ca_roots_path() isa String
        @test ispath(ca_roots_path())
        if Sys.iswindows() || Sys.isapple()
            @test ca_roots_path() == bundled_ca_roots()
            @test ca_roots() === nothing
        else
            @test ca_roots_path() != bundled_ca_roots()
            @test ca_roots() == ca_roots_path()
        end
    end
    @testset "env vars" begin
        unset = ca_roots(), ca_roots_path()
        value = "Why hello!"
        for var in CA_ROOTS_VARS
            ENV[var] = value
            @test ca_roots() == value
            @test ca_roots_path() == value
            ENV[var] = ""
            @test ca_roots() == unset[1]
            @test ca_roots_path() == unset[2]
            clear_env()
        end
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
        clear_env()
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
