#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$(pwd)}"
TARGET_REGEX="${COVERAGE_TARGET_REGEX:-^fearless\\.app$}"
MIN_PERCENT="${COVERAGE_MIN_LINE_PERCENT:-}"
COVERAGE_IGNORE_CONFIG="${COVERAGE_IGNORE_CONFIG-$ROOT/codecov.yml}"
export COVERAGE_TARGET_REGEX="$TARGET_REGEX"
export COVERAGE_MIN_LINE_PERCENT="$MIN_PERCENT"
export COVERAGE_IGNORE_CONFIG
export ROOT

if [[ "$#" -gt 0 ]]; then
  bundles=("$@")
else
  bundles=()
  while IFS= read -r bundle; do
    bundles+=("$bundle")
  done < <(/usr/bin/find "$ROOT/build/test-results" -maxdepth 1 -type d -name "*.xcresult" -print 2>/dev/null | /usr/bin/sort)
fi

if [[ "${#bundles[@]}" -eq 0 ]]; then
  echo "[coverage-summary] No xcresult bundles found" >&2
  exit 1
fi

for bundle in "${bundles[@]}"; do
  if [[ ! -d "$bundle" ]]; then
    echo "[coverage-summary] Missing xcresult bundle: $bundle" >&2
    exit 1
  fi

  xcrun xccov view --report --json "$bundle" | ruby -rjson -ryaml -e '
    bundle = ARGV.fetch(0)
    root = File.expand_path(ENV.fetch("ROOT"))
    target_regex = Regexp.new(ENV.fetch("COVERAGE_TARGET_REGEX"))
    min_percent = ENV["COVERAGE_MIN_LINE_PERCENT"]
    ignore_config = ENV["COVERAGE_IGNORE_CONFIG"]
    ignore_patterns = if ignore_config && !ignore_config.empty? && File.file?(ignore_config)
      config = YAML.load_file(ignore_config)
      config.is_a?(Hash) ? config.fetch("ignore", []) : []
    else
      []
    end
    fnmatch_flags = File::FNM_PATHNAME | File::FNM_EXTGLOB

    relative_path = lambda do |path|
      expanded = File.expand_path(path)
      root_prefix = root.end_with?("/") ? root : "#{root}/"
      expanded.start_with?(root_prefix) ? expanded.delete_prefix(root_prefix) : path
    end

    ignored = lambda do |path|
      relative = relative_path.call(path).sub(%r{\A\./}, "")

      ignore_patterns.any? do |raw_pattern|
        pattern = raw_pattern.to_s.sub(%r{\A\./}, "")
        File.fnmatch?(pattern, relative, fnmatch_flags) ||
          (!pattern.include?("*") && (relative == pattern || relative.start_with?("#{pattern}/")))
      end
    end

    data = JSON.parse(STDIN.read)
    targets = data.fetch("targets", []).select do |target|
      target.fetch("name", "").match?(target_regex) &&
        target.fetch("executableLines", 0).to_i.positive?
    end

    if targets.empty?
      warn "[coverage-summary] No covered targets in #{bundle} matching #{target_regex.inspect}"
      exit 1
    end

    ignored_files = 0
    covered = targets.sum do |target|
      files = target.fetch("files", [])
      next target.fetch("coveredLines", 0).to_i if files.empty?

      files.reject { |file| ignored.call(file.fetch("path", file.fetch("name", ""))) }
        .sum { |file| file.fetch("coveredLines", 0).to_i }
    end
    executable = targets.sum do |target|
      files = target.fetch("files", [])
      next target.fetch("executableLines", 0).to_i if files.empty?

      considered_files = files.reject { |file| ignored.call(file.fetch("path", file.fetch("name", ""))) }
      ignored_files += files.count - considered_files.count
      considered_files.sum { |file| file.fetch("executableLines", 0).to_i }
    end
    percent = executable.zero? ? 0.0 : (covered.to_f / executable * 100.0)
    names = targets.map { |target| target.fetch("name", "<unknown>") }.join(", ")
    ignored_suffix = ignored_files.positive? ? " (#{ignored_files} file(s) ignored by coverage config)" : ""

    puts format(
      "[coverage-summary] %s: %.2f%% line coverage (%d/%d) for %s%s",
      bundle,
      percent,
      covered,
      executable,
      names,
      ignored_suffix
    )

    if min_percent && !min_percent.empty? && percent < min_percent.to_f
      warn format(
        "[coverage-summary] Coverage %.2f%% is below required %.2f%% for %s",
        percent,
        min_percent.to_f,
        bundle
      )
      exit 1
    end
  ' "$bundle"
done
