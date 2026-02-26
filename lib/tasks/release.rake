# frozen_string_literal: true

require 'English'
PUBLISH_ORDER = [
  { name: 'rsb-settings',        dir: 'rsb-settings',        gemspec: 'rsb-settings.gemspec' },
  { name: 'rsb-auth',            dir: 'rsb-auth',            gemspec: 'rsb-auth.gemspec' },
  { name: 'rsb-entitlements',    dir: 'rsb-entitlements',    gemspec: 'rsb-entitlements.gemspec' },
  { name: 'rsb-admin',           dir: 'rsb-admin',           gemspec: 'rsb-admin.gemspec' },
  { name: 'rails-saas-builder',  dir: '.',                   gemspec: 'rails-saas-builder.gemspec' }
].freeze

VERSION_FILE = 'lib/rsb/version.rb'

PKG_DIR = File.expand_path('pkg', __dir__.then { File.expand_path('../..', _1) })

module ReleaseHelper
  module_function

  def root
    File.expand_path('../..', __dir__)
  end

  def current_version
    content = File.read(File.join(root, VERSION_FILE))
    content.match(/VERSION\s*=\s*['"]([^'"]+)['"]/)[1]
  end

  def next_version(current, bump)
    major, minor, patch = current.split('.').map(&:to_i)
    case bump.to_s
    when 'major' then "#{major + 1}.0.0"
    when 'minor' then "#{major}.#{minor + 1}.0"
    when 'patch' then "#{major}.#{minor}.#{patch + 1}"
    else abort "Unknown bump type: #{bump}. Use patch, minor, or major."
    end
  end

  def update_version_file(new_version)
    full_path = File.join(root, VERSION_FILE)
    content = File.read(full_path)
    updated = content.gsub(/VERSION\s*=\s*['"][^'"]+['"]/, "VERSION = '#{new_version}'")
    File.write(full_path, updated)
    puts "  Updated #{VERSION_FILE} → #{new_version}"
  end

  def ensure_clean_git!
    status = `git -C #{root} status --porcelain`.strip
    abort 'Aborting: working tree is dirty. Commit or stash changes first.' unless status.empty?
  end

  def ensure_on_master!
    branch = `git -C #{root} branch --show-current`.strip
    abort "Aborting: not on master branch (currently on '#{branch}')." unless branch == 'master'
  end

  def ensure_tests_pass!
    puts 'Running full test suite...'
    return if system('bundle exec rake test', chdir: root)

    abort 'Aborting: tests failed.'
  end

  def build_gem(gem_info)
    FileUtils.mkdir_p(PKG_DIR)

    gem_dir = File.join(root, gem_info[:dir])
    gemspec = gem_info[:gemspec]

    puts "  Building #{gem_info[:name]}..."
    output = `cd #{gem_dir} && gem build #{gemspec} 2>&1`
    abort "Failed to build #{gem_info[:name]}:\n#{output}" unless $CHILD_STATUS.success?

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
    abort "Failed to push #{name}." unless system("gem push #{gem_path}")
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

  # --- Extension gem helpers ---

  def resolve_extension(gem_name)
    gem_dir = File.join(root, gem_name)
    unless File.directory?(gem_dir)
      abort "Unknown extension gem: #{gem_name}. Directory '#{gem_dir}' not found."
    end

    gemspec = "#{gem_name}.gemspec"
    unless File.exist?(File.join(gem_dir, gemspec))
      abort "Cannot find gemspec: #{File.join(gem_dir, gemspec)}"
    end

    version_files = Dir.glob(File.join(gem_dir, 'lib', '**', 'version.rb'))
    if version_files.empty?
      abort "Cannot find version.rb for #{gem_name} in #{gem_dir}/lib/"
    end

    { dir: gem_dir, gemspec: gemspec, version_file: version_files.first }
  end

  def read_version(version_file)
    content = File.read(version_file)
    match = content.match(/VERSION\s*=\s*['"]([^'"]+)['"]/)
    abort "Cannot extract VERSION from #{version_file}" unless match
    match[1]
  end

  def update_version(version_file, new_version)
    content = File.read(version_file)
    updated = content.gsub(/VERSION\s*=\s*['"][^'"]+['"]/, "VERSION = '#{new_version}'")
    File.write(version_file, updated)
    puts "  Updated #{version_file} → #{new_version}"
  end

  def ensure_gem_tests_pass!(gem_dir)
    puts "Running tests for #{File.basename(gem_dir)}..."
    return if system('bundle exec rake test', chdir: gem_dir)

    abort 'Aborting: tests failed.'
  end
end

desc 'Build and push all gems to RubyGems.org (no version bump)'
task :publish do
  version = ReleaseHelper.current_version
  puts "Publishing v#{version}..."

  gem_paths = ReleaseHelper.build_all
  ReleaseHelper.push_all(gem_paths)

  puts "\nPublished v#{version} successfully!"
end

desc 'Bump version, build, push gems, tag and push git (default: patch)'
task :release, [:bump] do |_t, args|
  bump = args[:bump] || 'patch'
  current = ReleaseHelper.current_version
  new_version = ReleaseHelper.next_version(current, bump)

  puts "Release: #{current} → #{new_version} (#{bump} bump)\n\n"

  # Safety checks
  ReleaseHelper.ensure_clean_git!
  ReleaseHelper.ensure_on_master!
  ReleaseHelper.ensure_tests_pass!

  # Bump the single version file
  puts "\nBumping version..."
  ReleaseHelper.update_version_file(new_version)

  # Git commit and tag
  root = ReleaseHelper.root
  puts "\nCommitting version bump..."
  system("git -C #{root} add #{VERSION_FILE}")
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

desc 'Build and push an extension gem (no version bump): rake publish_ext[rsb-entitlements-stripe]'
task :publish_ext, [:gem_name] do |_t, args|
  gem_name = args[:gem_name] || abort('Usage: rake publish_ext[gem_name]')
  ext = ReleaseHelper.resolve_extension(gem_name)
  version = ReleaseHelper.read_version(ext[:version_file])

  puts "Publishing #{gem_name} v#{version}..."

  gem_info = { name: gem_name, dir: gem_name, gemspec: ext[:gemspec] }
  gem_path = ReleaseHelper.build_gem(gem_info)
  ReleaseHelper.push_gem(gem_path)

  puts "\nPublished #{gem_name} v#{version} successfully!"
end

desc 'Bump, build, push, tag extension gem: rake release_ext[rsb-entitlements-stripe,patch]'
task :release_ext, [:gem_name, :bump] do |_t, args|
  gem_name = args[:gem_name] || abort('Usage: rake release_ext[gem_name,bump]')
  bump = args[:bump] || 'patch'
  ext = ReleaseHelper.resolve_extension(gem_name)
  current = ReleaseHelper.read_version(ext[:version_file])
  new_version = ReleaseHelper.next_version(current, bump)

  puts "Release: #{gem_name} #{current} → #{new_version} (#{bump} bump)\n\n"

  # Safety checks
  ReleaseHelper.ensure_clean_git!
  ReleaseHelper.ensure_on_master!
  ReleaseHelper.ensure_gem_tests_pass!(ext[:dir])

  # Bump version
  puts "\nBumping version..."
  ReleaseHelper.update_version(ext[:version_file], new_version)

  # Git commit and tag
  root = ReleaseHelper.root
  relative_version_file = Pathname.new(ext[:version_file]).relative_path_from(Pathname.new(root)).to_s
  tag = "#{gem_name}-v#{new_version}"

  puts "\nCommitting version bump..."
  system("git -C #{root} add #{relative_version_file}")
  system("git -C #{root} commit -m 'Release #{gem_name} v#{new_version}'")
  system("git -C #{root} tag -a #{tag} -m 'Release #{gem_name} v#{new_version}'")

  # Build and push gem
  gem_info = { name: gem_name, dir: gem_name, gemspec: ext[:gemspec] }
  gem_path = ReleaseHelper.build_gem(gem_info)
  ReleaseHelper.push_gem(gem_path)

  # Push git
  puts "\nPushing to origin..."
  system("git -C #{root} push origin master")
  system("git -C #{root} push origin #{tag}")

  puts "\n#{'=' * 60}"
  puts "Released #{gem_name} v#{new_version} successfully!"
  puts "  - Gem pushed to RubyGems.org"
  puts "  - Tagged #{tag} and pushed to origin"
  puts '=' * 60
end
