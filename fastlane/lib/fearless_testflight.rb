# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "tempfile"
require "time"

module FearlessTestFlight
  APP_ID = "1537251089"
  BUNDLE_IDENTIFIER = "jp.co.soramitsu.fearlesswallet"
  PLATFORM = "IOS"
  SESSION_ONLY_PASSWORD = "FASTLANE_SESSION_ONLY_DO_NOT_USE"
  UPLOAD_AUDITS = ["fearless-testflight-upload", "fearless-fastlane-testflight-upload"].freeze
  TERMINAL_FAILURE_STATES = %w[FAILED INVALID].freeze
  MARKETING_VERSION_PATTERN = /\A[0-9]+(?:\.[0-9]+){1,3}\z/
  BUILD_NUMBER_PATTERN = /\A[0-9]+(?:\.[0-9]+){0,2}\z/
  TRUSTED_MACOS_ROOT_SYMLINKS = %w[/etc /tmp /var].freeze

  class ContractError < StandardError; end

  module_function

  def value(env, key)
    candidate = env[key]
    candidate = candidate.strip if candidate.respond_to?(:strip)
    candidate.nil? || candidate.empty? ? nil : candidate
  end

  def validate_release_identity!(version:, build_number:)
    unless version.is_a?(String) && version.match?(MARKETING_VERSION_PATTERN)
      raise ContractError, "marketing version must contain only two to four numeric components"
    end
    unless build_number.is_a?(String) && build_number.match?(BUILD_NUMBER_PATTERN)
      raise ContractError, "build number must contain only one to three numeric components"
    end

    true
  end

  def require_no_symlink_ancestors!(path, label)
    expanded = File.expand_path(path)
    Pathname.new(expanded).ascend do |candidate|
      next if TRUSTED_MACOS_ROOT_SYMLINKS.include?(candidate.to_s)
      raise ContractError, "#{label} traverses a symlink: #{candidate}" if File.symlink?(candidate.to_s)
    end
    true
  end

  def resolve_auth(env)
    key_id = value(env, "APP_STORE_CONNECT_API_KEY_KEY_ID")
    issuer_id = value(env, "APP_STORE_CONNECT_API_KEY_ISSUER_ID")
    key_filepath = value(env, "APP_STORE_CONNECT_API_KEY_KEY_FILEPATH")
    any_key_field = [key_id, issuer_id, key_filepath].any?

    if any_key_field
      missing = []
      missing << "APP_STORE_CONNECT_API_KEY_KEY_ID" unless key_id
      missing << "APP_STORE_CONNECT_API_KEY_KEY_FILEPATH" unless key_filepath
      raise ContractError, "incomplete App Store Connect API key configuration: missing #{missing.join(', ')}" unless missing.empty?
      raise ContractError, "API key file must be an absolute path" unless File.absolute_path(key_filepath) == key_filepath
      raise ContractError, "API key file is missing, unreadable, or a symlink: #{key_filepath}" unless File.file?(key_filepath) && File.readable?(key_filepath) && !File.symlink?(key_filepath)

      return {
        mode: "app-store-connect-api-key",
        key_id: key_id,
        issuer_id: issuer_id,
        key_filepath: key_filepath
      }
    end

    user = value(env, "FASTLANE_USER")
    session = value(env, "FASTLANE_SESSION")
    if user || session
      missing = []
      missing << "FASTLANE_USER" unless user
      missing << "FASTLANE_SESSION" unless session
      raise ContractError, "incomplete Apple-ID session configuration: missing #{missing.join(', ')}" unless missing.empty?

      return {
        mode: "apple-id-session",
        user: user,
        session_password: SESSION_ONLY_PASSWORD
      }
    end

    raise ContractError,
          "App Store Connect authentication is unavailable: configure an API key, or both FASTLANE_USER and FASTLANE_SESSION"
  end

  def read_json(path, label: "JSON receipt")
    raise ContractError, "#{label} path must be absolute: #{path}" unless Pathname.new(path).absolute?
    require_no_symlink_ancestors!(path, label)
    raise ContractError, "#{label} is missing, unreadable, or a symlink: #{path}" unless File.file?(path) && File.readable?(path) && !File.symlink?(path)

    JSON.parse(File.binread(path))
  rescue JSON::ParserError => e
    raise ContractError, "#{label} is invalid JSON: #{e.message}"
  end

  def sha256_file(path)
    raise ContractError, "required file is missing, unreadable, or a symlink: #{path}" unless File.file?(path) && File.readable?(path) && !File.symlink?(path)

    Digest::SHA256.file(path).hexdigest
  end

  def require_equal!(actual, expected, label)
    raise ContractError, "#{label} mismatch: expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
  end

  def require_sha256!(value, label)
    raise ContractError, "#{label} is not a lowercase SHA-256 digest" unless value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
  end

  def require_commit!(value, label)
    raise ContractError, "#{label} is not a full Git commit" unless value.is_a?(String) && value.match?(/\A[0-9a-f]{40}\z/)
  end

  def validate_evidence(signed_audit_path:, upload_receipt_path:, version:, build_number:, bundle_identifier: BUNDLE_IDENTIFIER)
    signed = read_json(signed_audit_path, label: "signed archive audit")
    upload = read_json(upload_receipt_path, label: "TestFlight upload receipt")

    require_equal!(signed["audit"], "fearless-ios-signed-production-archive", "signed archive audit type")
    require_equal!(signed["bundleIdentifier"], bundle_identifier, "signed archive bundle identifier")
    require_equal!(signed["marketingVersion"], version, "signed archive marketing version")
    require_equal!(signed["buildNumber"], build_number, "signed archive build number")
    require_commit!(signed["gitCommit"], "signed archive source commit")
    require_sha256!(signed["archiveTreeSHA256"], "signed archive tree digest")
    require_sha256!(signed["executableSHA256"], "signed archive executable digest")

    raise ContractError, "unsupported TestFlight upload receipt type: #{upload['audit'].inspect}" unless UPLOAD_AUDITS.include?(upload["audit"])
    require_equal!(upload["verdict"], "pass", "upload receipt verdict")
    require_equal!(upload["appleUploadAccepted"], true, "Apple upload acceptance")
    require_equal!(upload["bundleIdentifier"], bundle_identifier, "upload bundle identifier")
    require_equal!(upload["marketingVersion"], version, "upload marketing version")
    require_equal!(upload["buildVersion"], build_number, "upload build number")
    require_equal!(upload["gitCommit"], signed["gitCommit"], "upload source commit")
    require_equal!(upload["archiveTreeSHA256"], signed["archiveTreeSHA256"], "upload archive tree digest")
    require_equal!(upload["executableSHA256"], signed["executableSHA256"], "upload executable digest")

    signed_receipt_hash = upload.dig("hashes", "signedArchiveAuditSHA256")
    require_equal!(signed_receipt_hash, sha256_file(signed_audit_path), "signed archive audit file digest")

    {
      signed: signed,
      upload: upload,
      git_commit: signed["gitCommit"],
      signed_audit_sha256: signed_receipt_hash,
      upload_receipt_sha256: sha256_file(upload_receipt_path)
    }
  end

  def exact_build(builds, version:, build_number:, platform: PLATFORM)
    matches = Array(builds).select do |candidate|
      candidate_version = candidate.respond_to?(:app_version) ? candidate.app_version.to_s : nil
      candidate_build = candidate.respond_to?(:version) ? candidate.version.to_s : nil
      candidate_platform = candidate.respond_to?(:platform) ? candidate.platform.to_s : platform
      candidate_version == version.to_s && candidate_build == build_number.to_s && candidate_platform == platform.to_s
    end
    raise ContractError, "App Store Connect returned multiple records for exact build #{version} (#{build_number})" if matches.length > 1

    matches.first
  end

  def wait_for_exact_build(version:, build_number:, timeout:, poll_interval:, fetch_builds:, monotonic_clock: nil, sleeper: nil)
    monotonic_clock ||= -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    sleeper ||= ->(seconds) { sleep(seconds) }
    deadline = monotonic_clock.call + Integer(timeout)

    loop do
      build = exact_build(fetch_builds.call, version: version, build_number: build_number)
      if build
        state = build.processing_state.to_s
        raise ContractError, "App Store Connect rejected build #{version} (#{build_number}) with state #{state}" if TERMINAL_FAILURE_STATES.include?(state)
        return build if state == "VALID" && build.respond_to?(:ready_for_internal_testing?) && build.ready_for_internal_testing?
      end

      raise ContractError, "timed out waiting for exact build #{version} (#{build_number}) to become valid for internal testing" if monotonic_clock.call >= deadline

      sleeper.call(Integer(poll_interval))
    end
  end

  def resolve_target_group(groups:, tester:, requested_group_id: nil)
    all_groups = Array(groups)
    internal_groups = all_groups.select { |group| group.respond_to?(:is_internal_group) && group.is_internal_group == true }
    tester_group_ids = Array(tester.respond_to?(:beta_groups) ? tester.beta_groups : nil).map { |group| group.id.to_s }

    if requested_group_id && !requested_group_id.to_s.strip.empty?
      exact = all_groups.select { |group| group.id.to_s == requested_group_id.to_s }
      raise ContractError, "requested TestFlight group ID does not exist for this app: #{requested_group_id}" if exact.empty?
      raise ContractError, "App Store Connect returned duplicate groups for ID #{requested_group_id}" if exact.length > 1
      target = exact.first
      raise ContractError, "requested TestFlight group is external; refusing to change public/external distribution" unless target.is_internal_group == true
      raise ContractError, "target tester is not a member of requested internal group #{requested_group_id}" unless tester_group_ids.include?(target.id.to_s)
      return target
    end

    candidates = internal_groups.select { |group| tester_group_ids.include?(group.id.to_s) }
    if candidates.empty?
      raise ContractError, "target tester does not belong to an internal TestFlight group; set TESTFLIGHT_INTERNAL_GROUP_ID after adding membership"
    end
    if candidates.length > 1
      ids = candidates.map { |group| group.id.to_s }.sort.join(",")
      raise ContractError, "target tester belongs to multiple internal groups (#{ids}); set TESTFLIGHT_INTERNAL_GROUP_ID"
    end

    candidates.first
  end

  def groups_containing_build(groups:, build_id:, fetch_builds:)
    Array(groups).select do |group|
      Array(fetch_builds.call(group)).any? { |build| build.id.to_s == build_id.to_s }
    end
  end

  def write_json_atomic(path, payload, overwrite: false)
    raise ContractError, "receipt path must be absolute: #{path}" unless Pathname.new(path).absolute?
    parent = File.dirname(path)
    require_no_symlink_ancestors!(parent, "receipt path")
    FileUtils.mkdir_p(parent, mode: 0o700)
    require_no_symlink_ancestors!(parent, "receipt path")
    if File.exist?(path) || File.symlink?(path)
      raise ContractError, "receipt already exists: #{path}" unless overwrite
      raise ContractError, "refusing to overwrite symlink receipt: #{path}" if File.symlink?(path)
    end

    temporary = Tempfile.new([".fearless-testflight-", ".json"], parent)
    begin
      temporary.chmod(0o600)
      temporary.write(JSON.pretty_generate(payload))
      temporary.write("\n")
      temporary.flush
      temporary.fsync
      temporary.close
      File.rename(temporary.path, path)
      File.chmod(0o600, path)
    ensure
      temporary.close! if temporary
    end

    path
  end

  def publication_receipt(evidence:, auth_mode:, app:, build:, tester_email:, target_group:, assignment_performed:, assigned_groups:)
    internal = assigned_groups.select { |group| group.is_internal_group == true }
    external = assigned_groups.reject { |group| group.is_internal_group == true }
    {
      "schemaVersion" => 1,
      "audit" => "fearless-testflight-internal-publication",
      "verdict" => "pass",
      "verifiedAtUTC" => Time.now.utc.iso8601,
      "authenticationMode" => auth_mode,
      "app" => {
        "id" => app.id.to_s,
        "bundleIdentifier" => app.bundle_id.to_s
      },
      "build" => {
        "id" => build.id.to_s,
        "marketingVersion" => build.app_version.to_s,
        "buildNumber" => build.version.to_s,
        "platform" => build.platform.to_s,
        "processingState" => build.processing_state.to_s,
        "readyForInternalTesting" => build.ready_for_internal_testing? == true
      },
      "source" => {
        "gitCommit" => evidence.fetch(:git_commit),
        "archiveTreeSHA256" => evidence.fetch(:signed).fetch("archiveTreeSHA256"),
        "executableSHA256" => evidence.fetch(:signed).fetch("executableSHA256")
      },
      "tester" => {
        "emailSHA256" => Digest::SHA256.hexdigest(tester_email.downcase),
        "targetGroupMembershipVerified" => true
      },
      "targetInternalGroup" => {
        "id" => target_group.id.to_s,
        "name" => target_group.name.to_s,
        "isInternalGroup" => target_group.is_internal_group == true
      },
      "assignment" => {
        "performed" => assignment_performed,
        "verified" => true,
        "assignedInternalGroupIds" => internal.map { |group| group.id.to_s }.sort,
        "assignedExternalGroupIds" => external.map { |group| group.id.to_s }.sort,
        "publicBetaGroupChanged" => false
      },
      "upload" => {
        "uploadId" => evidence.fetch(:upload)["appStoreConnectBuildUploadId"],
        "uploadFileId" => evidence.fetch(:upload)["appStoreConnectBuildUploadFileId"]
      },
      "hashes" => {
        "signedArchiveAuditSHA256" => evidence.fetch(:signed_audit_sha256),
        "testFlightUploadReceiptSHA256" => evidence.fetch(:upload_receipt_sha256)
      }
    }
  end
end
