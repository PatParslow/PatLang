Feature: installing packages from local sources: pkg install
  An install reads package directories from local sources, keeps as
  candidates only the versions that verify against the trust store's pins
  (or a pin taken on first use, when asked), resolves the request among
  them, and plans the work as GOAP actions: each package is staged, verified
  again where it is staged, and installed only after the packages it depends
  on. Nothing in the project's packages/ changes until every package of the
  plan has verified; the commit is written down first, so a crash part way is
  finished by the next run, and a crash before it leaves packages/ as it was.
  The store's epochs and the project's trust.lock change with the commit.

  Background:
    Given sources holding deflate 0.2.0, and zip 0.2.0 depending on deflate, each released by a group of its own
    And a consumer's trust store pinning both genesis hashes, and an empty project

  Scenario: installing zip installs deflate first, then zip
    When zip is installed from the sources
    Then the report lists deflate 0.2.0 and then zip 0.2.0, each pinned given, at epoch 0
    And the project holds deflate and zip, each verifying where it is installed
    And the project's trust.lock names deflate 0.2.0 and zip 0.2.0 with their pins and manifests
    And no staging directory is left

  Scenario: a tampered copy is refused, and packages/ is untouched
    When deflate's file in the sources is changed after its release
    Then installing zip is refused, naming deflate and its file check
    And the project's packages/ holds nothing

  Scenario: a withdrawn version is refused
    When deflate 0.2.0 is withdrawn in the sources, for the reason "a bad build"
    Then installing zip is refused, naming deflate and its withdrawal
    And the project's packages/ holds nothing

  Scenario: an unpinned package is refused, unless a pin is taken on first use
    When zip is unpinned in the store
    Then installing zip is refused, saying zip is not pinned
    And the project's packages/ holds nothing
    When zip is installed from the sources, pinning on first use
    Then the report lists deflate 0.2.0 pinned given and zip 0.2.0 pinned on first use
    And the store holds zip's genesis hash, its source first-use

  Scenario: a crash at any step leaves packages/ as it was, or is finished by the next run
    Then an install of zip stopped after each of its steps leaves packages/ as it was before the commit is written, and whole after the next run from then on

  Scenario: the lock file holds a project to the versions it was installed with
    When zip is installed from the sources
    And the sources gain deflate 0.2.1, released by deflate's group
    Then installing zip again is refused, saying deflate is locked at 0.2.0
    And installing zip again with updating allowed installs deflate 0.2.1, and the lock names it
