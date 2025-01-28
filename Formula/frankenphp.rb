class Frankenphp < Formula
  desc "Modern PHP app server"
  homepage "https://frankenphp.dev"
  url "https://github.com/dunglas/frankenphp/archive/refs/tags/v1.4.2.tar.gz"
  sha256 "250a681d7306a5d1b69bb5ff727edf24c9276b994a8d74a1d30de812a96a53d8"
  license "MIT"
  head "https://github.com/dunglas/frankenphp.git", branch: "main"

  bottle do
    root_url "https://ghcr.io/v2/dunglas/frankenphp"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "c03baa91a6c0af248df7814c10f65175a3a7e1d3f99527946f79206fc24b8002"
  end

  depends_on "go" => :build

  depends_on "brotli"
  depends_on "shivammathur/php/php-zts"
  depends_on "watcher"

  def install
    php_config = "#{Formula["shivammathur/php/php-zts"].opt_bin}/php-config"
    lib_path = OS.mac? ? " -L#{MacOS.sdk_path_if_needed}/usr/lib" : ""

    ENV["CGO_CFLAGS"] = `#{php_config} --includes`
    ENV["CGO_LDFLAGS"] = `#{php_config} --ldflags`.strip! + " " + `#{php_config} --libs`.strip! + lib_path

    ldflags = %W[
      -s -w
      -X "github.com/caddyserver/caddy/v2.CustomVersion=FrankenPHP #{version} (Homebrew) PHP #{Formula["shivammathur/php/php-zts"].version} Caddy"
    ]

    cd "caddy/frankenphp" do
      system "go", "build", \
        *std_go_args(ldflags:, output: bin/"frankenphp"), "-tags", "nobadger,nomysql,nopgx", "main.go"
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
