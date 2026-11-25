Feature: tls package: the TLS 1.3 client against OpenSSL's server
  openssl s_server -tls1_3, on this machine's loopback with the test PKI
  (spec/make_certs.py), and the client as a Linux build beside it
  (spec/live_client.patlang), run under WSL on Windows. Each case asks for
  "/" and reads the server's status page. The scenarios fail, naming what is
  missing, when wsl or openssl is not there.

  Scenario: handshakes the client completes
    Then the client reads "HTTP/1.0 200 ok" from each server, trusting the test root:
      """
      leaf_ec | localhost
      leaf_rsa | localhost
      leaf_ec | a.test.example
      leaf_ec | localhost | -ciphersuites | TLS_AES_128_GCM_SHA256
      leaf_ec | localhost | -groups | P-256
      """

  Scenario: http_request takes https:// URLs over the client
    Then http_request of https://localhost on the server with leaf_ec, trusting the test root, gives status 200

  Scenario: tls_https_get fetches a file's bytes
    Then tls_https_get of a certificate file served by s_server -WWW gives status 200 and the file's bytes

  Scenario: handshakes the client refuses, saying why
    Then the client refuses each server, its reason starting as given:
      """
      leaf_ec | localhost | system | the server's certificate: untrusted
      leaf_ec | other.example | test | the server's certificate: name
      expired | localhost | test | the server's certificate: expired
      """
