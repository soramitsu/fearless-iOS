# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/fearless_testflight"

class FearlessTestFlightTest < Minitest::Test
  Group = Struct.new(:id, :name, :is_internal_group, :beta_groups)
  Tester = Struct.new(:id, :email, :beta_groups)
  App = Struct.new(:id, :bundle_id)

  class Build
    attr_reader :id, :app_version, :version, :platform, :processing_state

    def initialize(id:, app_version:, version:, platform: "IOS", processing_state: "VALID", ready: true)
      @id = id
      @app_version = app_version
      @version = version
      @platform = platform
      @processing_state = processing_state
      @ready = ready
    end

    def ready_for_internal_testing?
      @ready
    end
  end

  def api_key_env(path)
    {
      "APP_STORE_CONNECT_API_KEY_KEY_ID" => "KEY123",
      "APP_STORE_CONNECT_API_KEY_ISSUER_ID" => "",
      "APP_STORE_CONNECT_API_KEY_KEY_FILEPATH" => path
    }
  end

  def test_individual_api_key_does_not_require_issuer
    Dir.mktmpdir do |directory|
      path = File.join(directory, "AuthKey_KEY123.p8")
      File.write(path, "private")
      result = FearlessTestFlight.resolve_auth(api_key_env(path))
      assert_equal "app-store-connect-api-key", result[:mode]
      assert_nil result[:issuer_id]
    end
  end

  def test_release_identity_accepts_numeric_version_and_build
    assert FearlessTestFlight.validate_release_identity!(
      version: "4.2.0",
      build_number: "2026.8.33"
    )
  end

  def test_release_identity_rejects_path_and_glob_characters
    ["../4.2.0", "4.2.*", "4/2/0"].each do |version|
      assert_raises(FearlessTestFlight::ContractError) do
        FearlessTestFlight.validate_release_identity!(version: version, build_number: "2026.8.33")
      end
    end
    ["../33", "2026.*.33", "2026/8/33"].each do |build_number|
      assert_raises(FearlessTestFlight::ContractError) do
        FearlessTestFlight.validate_release_identity!(version: "4.2.0", build_number: build_number)
      end
    end
  end

  def test_symlinked_receipt_ancestor_is_rejected
    Dir.mktmpdir do |directory|
      real = File.join(directory, "real")
      link = File.join(directory, "link")
      Dir.mkdir(real)
      File.symlink(real, link)
      assert_raises(FearlessTestFlight::ContractError) do
        FearlessTestFlight.write_json_atomic(File.join(link, "receipt.json"), { "verdict" => "pass" })
      end
    end
  end

  def test_partial_api_key_configuration_is_rejected
    error = assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.resolve_auth("APP_STORE_CONNECT_API_KEY_KEY_ID" => "KEY123")
    end
    assert_includes error.message, "KEY_FILEPATH"
  end

  def test_session_requires_user_and_session
    assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.resolve_auth("FASTLANE_USER" => "tester@example.com")
    end
    result = FearlessTestFlight.resolve_auth(
      "FASTLANE_USER" => "tester@example.com",
      "FASTLANE_SESSION" => "opaque-cookie"
    )
    assert_equal "apple-id-session", result[:mode]
    assert_equal FearlessTestFlight::SESSION_ONLY_PASSWORD, result[:session_password]
    refute_empty result[:session_password]
  end

  def test_unique_internal_group_containing_tester_is_selected
    internal = Group.new("internal-1", "Internal", true)
    external = Group.new("external-1", "Public", false)
    tester = Tester.new("tester", "tester@example.com", [internal, external])
    assert_same internal, FearlessTestFlight.resolve_target_group(groups: [internal, external], tester: tester)
  end

  def test_exact_requested_internal_group_is_selected
    first = Group.new("internal-1", "One", true)
    second = Group.new("internal-2", "Two", true)
    tester = Tester.new("tester", "tester@example.com", [first, second])
    result = FearlessTestFlight.resolve_target_group(
      groups: [first, second], tester: tester, requested_group_id: "internal-2"
    )
    assert_same second, result
  end

  def test_external_requested_group_is_rejected
    external = Group.new("external-1", "Public", false)
    tester = Tester.new("tester", "tester@example.com", [external])
    assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.resolve_target_group(
        groups: [external], tester: tester, requested_group_id: external.id
      )
    end
  end

  def test_requested_group_requires_tester_membership
    internal = Group.new("internal-1", "Internal", true)
    tester = Tester.new("tester", "tester@example.com", [])
    assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.resolve_target_group(
        groups: [internal], tester: tester, requested_group_id: internal.id
      )
    end
  end

  def test_ambiguous_internal_groups_are_rejected
    first = Group.new("internal-1", "One", true)
    second = Group.new("internal-2", "Two", true)
    tester = Tester.new("tester", "tester@example.com", [first, second])
    assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.resolve_target_group(groups: [first, second], tester: tester)
    end
  end

  def test_exact_build_rejects_duplicate_records
    builds = 2.times.map do |index|
      Build.new(id: index.to_s, app_version: "4.2.0", version: "2026.8.33")
    end
    assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.exact_build(builds, version: "4.2.0", build_number: "2026.8.33")
    end
  end

  def test_wait_for_exact_build_rejects_invalid_processing_state
    invalid = Build.new(
      id: "build-1", app_version: "4.2.0", version: "2026.8.33", processing_state: "INVALID"
    )
    assert_raises(FearlessTestFlight::ContractError) do
      FearlessTestFlight.wait_for_exact_build(
        version: "4.2.0",
        build_number: "2026.8.33",
        timeout: 10,
        poll_interval: 1,
        fetch_builds: -> { [invalid] },
        monotonic_clock: -> { 0 },
        sleeper: ->(_seconds) {}
      )
    end
  end

  def test_groups_containing_build_uses_exact_build_id
    first = Group.new("one", "One", true)
    second = Group.new("two", "Two", true)
    builds = {
      "one" => [Build.new(id: "target", app_version: "4.2.0", version: "2026.8.33")],
      "two" => [Build.new(id: "other", app_version: "4.2.0", version: "2026.8.33")]
    }
    result = FearlessTestFlight.groups_containing_build(
      groups: [first, second],
      build_id: "target",
      fetch_builds: ->(group) { builds.fetch(group.id) }
    )
    assert_equal [first], result
  end

  def test_evidence_validation_binds_receipts_to_exact_artifact
    Dir.mktmpdir do |directory|
      signed_path, upload_path = write_evidence(directory)
      result = FearlessTestFlight.validate_evidence(
        signed_audit_path: signed_path,
        upload_receipt_path: upload_path,
        version: "4.2.0",
        build_number: "2026.8.33"
      )
      assert_equal "a" * 40, result[:git_commit]
      assert_equal Digest::SHA256.file(upload_path).hexdigest, result[:upload_receipt_sha256]
    end
  end

  def test_evidence_validation_rejects_source_mismatch
    Dir.mktmpdir do |directory|
      signed_path, upload_path = write_evidence(directory, upload_commit: "b" * 40)
      assert_raises(FearlessTestFlight::ContractError) do
        FearlessTestFlight.validate_evidence(
          signed_audit_path: signed_path,
          upload_receipt_path: upload_path,
          version: "4.2.0",
          build_number: "2026.8.33"
        )
      end
    end
  end

  def test_atomic_receipt_is_private_and_refuses_overwrite
    Dir.mktmpdir do |directory|
      path = File.join(directory, "receipt.json")
      FearlessTestFlight.write_json_atomic(path, { "verdict" => "pass" })
      assert_equal 0o600, File.stat(path).mode & 0o777
      assert_equal({ "verdict" => "pass" }, JSON.parse(File.read(path)))
      assert_raises(FearlessTestFlight::ContractError) do
        FearlessTestFlight.write_json_atomic(path, { "verdict" => "changed" })
      end
    end
  end

  def test_publication_receipt_hashes_tester_email
    internal = Group.new("internal-1", "Internal", true)
    evidence = {
      git_commit: "a" * 40,
      signed: { "archiveTreeSHA256" => "b" * 64, "executableSHA256" => "c" * 64 },
      upload: {},
      signed_audit_sha256: "d" * 64,
      upload_receipt_sha256: "e" * 64
    }
    receipt = FearlessTestFlight.publication_receipt(
      evidence: evidence,
      auth_mode: "app-store-connect-api-key",
      app: App.new("1537251089", FearlessTestFlight::BUNDLE_IDENTIFIER),
      build: Build.new(id: "build-1", app_version: "4.2.0", version: "2026.8.33"),
      tester_email: "Tester@Example.com",
      target_group: internal,
      assignment_performed: true,
      assigned_groups: [internal]
    )
    refute_includes JSON.generate(receipt), "Tester@Example.com"
    assert_equal Digest::SHA256.hexdigest("tester@example.com"), receipt.dig("tester", "emailSHA256")
    assert_equal [], receipt.dig("assignment", "assignedExternalGroupIds")
  end

  private

  def write_evidence(directory, upload_commit: "a" * 40)
    signed_path = File.join(directory, "signed.json")
    upload_path = File.join(directory, "upload.json")
    signed = {
      "audit" => "fearless-ios-signed-production-archive",
      "bundleIdentifier" => FearlessTestFlight::BUNDLE_IDENTIFIER,
      "marketingVersion" => "4.2.0",
      "buildNumber" => "2026.8.33",
      "gitCommit" => "a" * 40,
      "archiveTreeSHA256" => "b" * 64,
      "executableSHA256" => "c" * 64
    }
    File.write(signed_path, JSON.generate(signed))
    upload = {
      "audit" => "fearless-testflight-upload",
      "verdict" => "pass",
      "appleUploadAccepted" => true,
      "bundleIdentifier" => FearlessTestFlight::BUNDLE_IDENTIFIER,
      "marketingVersion" => "4.2.0",
      "buildVersion" => "2026.8.33",
      "gitCommit" => upload_commit,
      "archiveTreeSHA256" => "b" * 64,
      "executableSHA256" => "c" * 64,
      "hashes" => {
        "signedArchiveAuditSHA256" => Digest::SHA256.file(signed_path).hexdigest
      }
    }
    File.write(upload_path, JSON.generate(upload))
    [signed_path, upload_path]
  end
end
