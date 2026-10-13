class CloudflareCli < Formula
  desc "Command-line interface for the Cloudflare API and Workers"
  homepage "https://developers.cloudflare.com/cf/"
  url "https://registry.npmjs.org/cf/-/cf-1.0.0-beta.14.tgz"
  sha256 "0a5f30127f9651f0b841c7b7edb71c3a250a5f8520ac12473d2062e5b56cc0f3"
  license any_of: ["Apache-2.0", "MIT"]

  depends_on "node"
  depends_on "workerd"

  conflicts_with "cf", because: "both install `cf` binaries"
  conflicts_with "cloudfoundry-cli", because: "both install `cf` binaries"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec.glob("bin/*")

    libexec.glob("lib/node_modules/cf/node_modules/@cloudflare/workerd-*/bin/workerd").each do |workerd|
      rm workerd
      workerd.make_symlink formula_opt_bin("workerd")/"workerd"
    end

    ENV["CF_SEND_TELEMETRY"] = "false"
    generate_completions_from_executable(bin/"cf", "complete", shells: [:bash, :zsh, :fish, :pwsh])
  end

  test do
    ENV["CF_SEND_TELEMETRY"] = "false"
    # Use polling because the macOS test sandbox denies FSEvents access.
    ENV["CHOKIDAR_USEPOLLING"] = "1" if OS.mac?

    assert_match version.to_s, shell_output("#{bin}/cloudflare --version")
    results = JSON.parse(shell_output("#{bin}/cf cli search 'list zones'"))
    assert_includes results.map { |result| result["command"] }, "cf zones list"

    system bin/"cf", "init", "hello-world", "--no-install"
    assert_match 'name: "hello-world"', (testpath/"hello-world/cloudflare.config.ts").read
    assert_match "Hello", (testpath/"hello-world/src/index.ts").read

    system bin/"cf", "kv", "keys", "put", "greeting", "--namespace-id", "brew-test",
                     "--body", "Hello from Homebrew!", "--local", "--persist-to", testpath/"state"
    assert_equal "Hello from Homebrew!",
                 shell_output("#{bin}/cf kv keys get greeting --namespace-id brew-test " \
                              "--local --persist-to #{testpath}/state")
  end
end
