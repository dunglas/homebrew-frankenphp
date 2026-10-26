class Frankenphp < Formula
  desc "Modern PHP app server"
  homepage "https://frankenphp.dev"
  url "https://github.com/php/frankenphp/archive/refs/tags/v1.13.4.tar.gz"
  sha256 "855d2e725cf4882e489cabf89f1827ff7e7991de348ed6d2e702056016751462"
  license "MIT"
  head "https://github.com/dunglas/frankenphp.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/dunglas/frankenphp"
    sha256 cellar: :any, arm64_sequoia: "9b3af83d94b314bf6755d01ad500fd5b221ea31881e77d200a1b5c434242f2ae"
    sha256 cellar: :any, x86_64_linux:  "9299b5cf2f34c1c708c67457ec004b5994002257b0041de544f5778e9ff6cb7c"
  end

  depends_on "go" => :build
  depends_on "pkgconf" => :build

  depends_on "argon2"
  depends_on "brotli"
  depends_on "freetds"
  depends_on "gd"
  depends_on "gettext"
  depends_on "gmp"
  depends_on "icu4c@78"
  depends_on "libpq"
  depends_on "libsodium"
  depends_on "libzip"
  depends_on "oniguruma"
  depends_on "openssl@4"
  depends_on "pcre2"
  depends_on "shivammathur/php/php-zts"
  depends_on "sqlite"
  depends_on "unixodbc"
  depends_on "watcher"

  def install
    php_config = "#{formula_opt_bin("shivammathur/php/php-zts")}/php-config"
    php_config_libs = Utils.safe_popen_read(php_config, "--libs").strip

    lib_path = OS.mac? ? " -L#{MacOS.sdk_path}/usr/lib" : ""
    ENV["CGO_CFLAGS"] = Utils.safe_popen_read(php_config, "--includes") + " -DFRANKENPHP_VERSION=#{version}"
    ENV["CGO_LDFLAGS"] = Utils.safe_popen_read(php_config, "--ldflags").strip + php_config_libs + lib_path

    tags = %w[nobadger nomysql nopgx]
    ldflags = %W[
      -s -w
      -X "github.com/caddyserver/caddy/v2.CustomVersion=FrankenPHP v#{version} (Homebrew) PHP #{Formula["shivammathur/php/php-zts"].version} Caddy"
      -X github.com/caddyserver/caddy/v2.CustomBinaryName=frankenphp
      -X "github.com/caddyserver/caddy/v2/modules/caddyhttp.ServerHeader=FrankenPHP Caddy"
    ]

    cd "caddy/frankenphp" do
      system "go", "build", *std_go_args(ldflags:, tags:), "main.go"
    end
  end

  def caveats
    <<~EOS
      When running the provided service, frankenphp's data dir will be set as
        `#{HOMEBREW_PREFIX}/var/lib`
        instead of the default location found at https://caddyserver.com/docs/conventions#data-directory
    EOS
  end

  service do
    run [opt_bin/"frankenphp", "run", "--config", etc/"Caddyfile"]
    keep_alive true
    environment_variables XDG_DATA_HOME: "#{HOMEBREW_PREFIX}/var/lib"
  end

  test do
    port1 = free_port
    port2 = free_port

    (testpath/"Caddyfile").write <<~EOS
      {
        admin 127.0.0.1:#{port1}
      }

      http://127.0.0.1:#{port2} {
        respond "Hello, FrankenPHP!"
      }
    EOS

    fork do
      exec bin/"frankenphp", "run", "--config", testpath/"Caddyfile"
    end
    sleep 2

    assert_match "\":#{port2}\"",
                 shell_output("curl -s http://127.0.0.1:#{port1}/config/apps/http/servers/srv0/listen/0")
    assert_match "Hello, FrankenPHP!", shell_output("curl -s http://127.0.0.1:#{port2}")

    assert_match version.to_s, shell_output("#{bin}/frankenphp version")
  end
end
