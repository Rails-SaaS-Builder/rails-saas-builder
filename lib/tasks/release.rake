PUBLISH_ORDER = [
  { name: "rsb-settings",        dir: "rsb-settings",        gemspec: "rsb-settings.gemspec",        version_file: "rsb-settings/lib/rsb/settings/version.rb" },
  { name: "rsb-auth",            dir: "rsb-auth",            gemspec: "rsb-auth.gemspec",            version_file: "rsb-auth/lib/rsb/auth/version.rb" },
  { name: "rsb-entitlements",    dir: "rsb-entitlements",    gemspec: "rsb-entitlements.gemspec",    version_file: "rsb-entitlements/lib/rsb/entitlements/version.rb" },
  { name: "rsb-admin",           dir: "rsb-admin",           gemspec: "rsb-admin.gemspec",           version_file: "rsb-admin/lib/rsb/admin/version.rb" },
  { name: "rails-saas-builder",  dir: ".",                   gemspec: "rails-saas-builder.gemspec",  version_file: "lib/rsb/version.rb" }
].freeze

VERSION_FILES = PUBLISH_ORDER.map { |g| g[:version_file] }.freeze

PKG_DIR = File.expand_path("pkg", __dir__.then { File.expand_path("../..", _1) })

module ReleaseHelper
  module_function

  def root
    File.expand_path("../..", __dir__)
  end

  def current_version
    content = File.read(File.join(root, "lib/rsb/version.rb"))
    content.match(/VERSION\s*=\s*"([^"]+)"/)[1]
  end

  def next_version(current, bump)
    major, minor, patch = current.split(".").map(&:to_i)
    case bump.to_s
    when "major" then "#{major + 1}.0.0"
    when "minor" then "#{major}.#{minor + 1}.0"
    when "patch" then "#{major}.#{minor}.#{patch + 1}"
    else abort "Unknown bump type: #{bump}. Use patch, minor, or major."
    end
  end

  def update_version_file(path, new_version)
    full_path = File.join(root, path)
    content = File.read(full_path)
    updated = content.gsub(/VERSION\s*=\s*"[^"]+"/, "VERSION = \"#{new_version}\"")
    File.write(full_path, updated)
    puts "  Updated #{path} → #{new_version}"
  end

  def ensure_clean_git!
    status = `git -C #{root} status --porcelain`.strip
    abort "Aborting: working tree is dirty. Commit or stash changes first." unless status.empty?
  end

  def ensure_on_master!
    branch = `git -C #{root} branch --show-current`.strip
    abort "Aborting: not on master branch (currently on '#{branch}')." unless branch == "master"
  end

  def ensure_tests_pass!
    puts "Running full test suite..."
    unless system("bundle exec rake test", chdir: root)
      abort "Aborting: tests failed."
    end
  end

  def build_gem(gem_info)
    FileUtils.mkdir_p(PKG_DIR)

    gem_dir = File.join(root, gem_info[:dir])
    gemspec = gem_info[:gemspec]

    puts "  Building #{gem_info[:name]}..."
    output = `cd #{gem_dir} && gem build #{gemspec} 2>&1`
    unless $?.success?
      abort "Failed to build #{gem_info[:name]}:\n#{output}"
    end

    gem_file = output.match(/File:\s*(.+\.gem)/)[1].strip
    source = File.join(gem_dir, gem_file)
    dest = File.join(PKG_DIR, gem_file)
    FileUtils.mv(source, dest)
    puts "  Built #{dest}"
    dest
  end

  def push_gem(gem_path)
    name = File.basename(gem_path)
    puts "  Pushing #{name}..."
    unless system("gem push #{gem_path}")
      abort "Failed to push #{name}."
    end
    puts "  Pushed #{name}"
  end

  def build_all
    puts "\nBuilding gems..."
    PUBLISH_ORDER.map { |gem_info| build_gem(gem_info) }
  end

  def push_all(gem_paths)
    puts "\nPushing gems to RubyGems.org..."
    gem_paths.each { |path| push_gem(path) }
  end
end

desc "Build and push all gems to RubyGems.org (no version bump)"
task :publish do
  version = ReleaseHelper.current_version
  puts "Publishing v#{version}..."

  gem_paths = ReleaseHelper.build_all
  ReleaseHelper.push_all(gem_paths)

  puts "\nPublished v#{version} successfully!"
end

desc "Bump version, build, push gems, tag and push git (default: patch)"
task :release, [:bump] do |_t, args|
  bump = args[:bump] || "patch"
  current = ReleaseHelper.current_version
  new_version = ReleaseHelper.next_version(current, bump)

  puts "Release: #{current} → #{new_version} (#{bump} bump)\n\n"

  # Safety checks
  ReleaseHelper.ensure_clean_git!
  ReleaseHelper.ensure_on_master!
  ReleaseHelper.ensure_tests_pass!

  # Bump all version files
  puts "\nBumping version files..."
  VERSION_FILES.each { |path| ReleaseHelper.update_version_file(path, new_version) }

  # Git commit and tag
  root = ReleaseHelper.root
  puts "\nCommitting version bump..."
  system("git -C #{root} add #{VERSION_FILES.join(' ')}")
  system("git -C #{root} commit -m 'Release v#{new_version}'")
  system("git -C #{root} tag -a v#{new_version} -m 'Release v#{new_version}'")

  # Build and push gems
  gem_paths = ReleaseHelper.build_all
  ReleaseHelper.push_all(gem_paths)

  # Push git
  puts "\nPushing to origin..."
  system("git -C #{root} push origin master")
  system("git -C #{root} push origin v#{new_version}")

  puts "\n#{'=' * 60}"
  puts "Released v#{new_version} successfully!"
  puts "  - #{PUBLISH_ORDER.size} gems pushed to RubyGems.org"
  puts "  - Tagged v#{new_version} and pushed to origin"
  puts '=' * 60
end
