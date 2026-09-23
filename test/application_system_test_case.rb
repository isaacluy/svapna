require "test_helper"
require "socket"

# Chromium runs in the `selenium` compose service (bin/d sys), so nothing is
# installed on the host and nothing extra goes into the app image.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["SELENIUM_REMOTE_URL"].present?
    # The browser is in another container, so Capybara must bind to this
    # container's interface and advertise an address the browser can reach.
    # Not the service name: `docker compose run` containers get a generated
    # name that `selenium` cannot resolve, so the address is this container's
    # own private IP.
    # Serial, deliberately. The browser reaches the app over a fixed port, and
    # parallel workers would fight over it -- the browser then talks to another
    # worker's app and database, which fails in ways that look like the feature
    # is broken rather than the harness.
    parallelize(workers: 1)

    Capybara.server_host = "0.0.0.0"
    Capybara.server_port = 3001
    Capybara.app_host = "http://#{Socket.ip_address_list.detect(&:ipv4_private?)&.ip_address}:3001"

    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ], options: {
      browser: :remote,
      url: ENV.fetch("SELENIUM_REMOTE_URL")
    }
  else
    # Without the browser container, system tests still run headless-free so
    # `bin/d t` is never blocked -- they just cannot exercise JavaScript.
    driven_by :rack_test
  end
end
