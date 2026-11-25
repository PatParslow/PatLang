Feature: installer: zip archives and https URLs as sources (docs/plans/package-trust.md, S6)
  A source is a directory of packages, a zip archive of one, or an https URL
  of such an archive. An archive is read with the zip package and its entries
  written under packages/.sources/ in the project, each name first checked to
  stay there; an https URL is fetched with the tls package's TLS 1.3 client,
  its certificates checked, then read as an archive. From there an install is
  the same as one from a directory: every package verifies against its pin.
  The packages are this repository's zip and deflate, with their trust
  records, verified against packages/trust.pins.

  Scenario: a zip archive of packages installs as their directory does
    Given a zip archive holding the repository's zip and deflate packages
    When zip is installed from the archive, with the repository's shipped pins
    Then deflate then zip are installed, each with its pin shipped, trust.lock names both, and nothing is left under packages/.sources

  Scenario: an archive whose entry would leave its directory is refused, and nothing is written
    Given a zip archive holding the repository's zip and deflate packages and an entry named "../escaped.txt"
    When zip is installed from the archive, with the repository's shipped pins
    Then the install is refused, naming the entry, no escaped.txt is written beside packages/, and nothing is installed

  Scenario: an https URL of the archive installs as the archive does
    Then installing zip from https://localhost of the archive, served by openssl s_server and trusting the test root, installs deflate then zip
