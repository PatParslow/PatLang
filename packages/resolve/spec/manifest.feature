Feature: resolve package: reading manifests
  A manifest (packages/README.md) reads into its fields, or fails with the
  number of the line at fault and what is wrong with it. Line 0 means the
  manifest as a whole, for a line it lacks.

  Scenario: A fixture manifest reads into its fields
    Given the manifest "packages/resolve/spec/fixtures/basic/zip-0.1.0.pkg"
    When it is read
    Then it reads as package "zip" version "0.1.0"
    And its entry is "zip.patlang"
    And it has 1 include and 1 file
    And its dependencies are "deflate >= 0.1.0, < 0.2.0"

  Scenario: Comments, blank lines, a summary and two dependencies
    Given the manifest "packages/resolve/spec/fixtures/malformed/good.pkg"
    When it is read
    Then it reads as package "good_1" version "10.20.30"
    And its summary is "spaces   inside a summary are kept"
    And it has 2 includes and 2 files
    And its dependencies are "deflate >= 0.1.0, < 0.2.0; zip = 0.1.0"
    And the hash of its file "good.patlang" is in lower case

  Scenario: The real deflate manifest reads
    Given the manifest "packages/deflate/manifest.pkg"
    When it is read
    Then it reads as package "deflate" version "0.1.0"
    And its entry is "deflate.patlang"
    And it has 5 includes and 5 files
    And its dependencies are ""

  Scenario: The real zip manifest reads
    Given the manifest "packages/zip/manifest.pkg"
    When it is read
    Then it reads as package "zip" version "0.1.0"
    And it has 1 include and 1 file
    And its dependencies are "deflate >= 0.1.0, < 0.2.0"

  Scenario: The real sha256 manifest reads
    Given the manifest "packages/sha256/manifest.pkg"
    When it is read
    Then it reads as package "sha256" version "0.1.0"
    And its entry is "sha256.patlang"
    And it has 4 includes and 4 files
    And its dependencies are ""

  Scenario: This package's own manifest reads
    Given the manifest "packages/resolve/manifest.pkg"
    When it is read
    Then it reads as package "resolve" version "0.1.0"
    And its entry is "resolve.patlang"
    And its dependencies are ""

  Scenario: Malformed manifests fail at the line at fault
    Then the manifest "malformed/no_version.pkg" fails at line 0 with "no 'version' line"
    And the manifest "malformed/short_version.pkg" fails at line 2 with "version '1.2' is not MAJOR.MINOR.PATCH"
    And the manifest "malformed/leading_zero.pkg" fails at line 2 with "version '01.2.3' is not MAJOR.MINOR.PATCH"
    And the manifest "malformed/prerelease.pkg" fails at line 2 with "version '1.0.0-beta' is not MAJOR.MINOR.PATCH"
    And the manifest "malformed/bad_op.pkg" fails at line 5 with "constraint '~> 0.1.0' has no operator =, >=, >, <= or <"
    And the manifest "malformed/double_eq.pkg" fails at line 5 with "constraint '== 0.1.0' has no operator =, >=, >, <= or <"
    And the manifest "malformed/no_constraint.pkg" fails at line 5 with "depends 'deflate' gives no constraint"
    And the manifest "malformed/trailing_comma.pkg" fails at line 5 with "depends 'deflate' has an empty constraint"
    And the manifest "malformed/bad_bound.pkg" fails at line 5 with "constraint '>= 0.1' bound '0.1' is not MAJOR.MINOR.PATCH"
    And the manifest "malformed/bad_dep_name.pkg" fails at line 5 with "'De-flate' is not a package name"
    And the manifest "malformed/twice_depends.pkg" fails at line 6 with "second depends line for 'deflate' (first at line 5)"
    And the manifest "malformed/twice_constraint.pkg" fails at line 5 with "depends 'deflate' gives '>= 0.1.0' twice"
    And the manifest "malformed/self_dep.pkg" fails at line 5 with "package 'x' depends on itself"
    And the manifest "malformed/unknown_key.pkg" fails at line 3 with "unknown key 'licence'"
    And the manifest "malformed/upper_name.pkg" fails at line 1 with "'Zip' is not a package name"
    And the manifest "malformed/two_versions.pkg" fails at line 4 with "second version line (first at line 2)"
    And the manifest "malformed/no_value.pkg" fails at line 3 with "key 'entry' has no value"
    And the manifest "malformed/bad_hash.pkg" fails at line 5 with "file line is not '<path> sha256 <64 hex digits>'"
    And the manifest "malformed/no_file.pkg" fails at line 0 with "no 'file' line"
    And the manifest "malformed/include_without_file.pkg" fails at line 5 with "include 'y.patlang' has no file line"
    And the manifest "malformed/file_not_included.pkg" fails at line 6 with "file 'y.patlang' is not an include"
    And the manifest "malformed/entry_not_included.pkg" fails at line 3 with "entry 'main.patlang' is not an include"

  Scenario: A universe giving one package version twice is refused
    Then reading the universe "duplicate" fails with "a 1.0.0 is given twice"
