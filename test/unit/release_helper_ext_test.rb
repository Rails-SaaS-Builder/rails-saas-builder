# frozen_string_literal: true

require 'test_helper'
require 'rake'

# Load release.rake to get ReleaseHelper
load File.expand_path('../../lib/tasks/release.rake', __dir__)

class ReleaseHelperExtTest < ActiveSupport::TestCase
  test 'resolve_extension returns metadata for known gem' do
    result = ReleaseHelper.resolve_extension('rsb-entitlements-stripe')

    assert_equal File.join(ReleaseHelper.root, 'rsb-entitlements-stripe'), result[:dir]
    assert_equal 'rsb-entitlements-stripe.gemspec', result[:gemspec]
    assert result[:version_file].end_with?('version.rb')
    assert File.exist?(result[:version_file])
  end

  test 'resolve_extension aborts for unknown gem' do
    assert_raises(SystemExit) do
      ReleaseHelper.resolve_extension('rsb-nonexistent-gem')
    end
  end

  test 'read_version extracts version from file' do
    ext = ReleaseHelper.resolve_extension('rsb-entitlements-stripe')
    version = ReleaseHelper.read_version(ext[:version_file])

    # Current version is '1.0.0-alpha' (or whatever it currently is)
    assert_match(/\A\d+\.\d+\.\d+/, version)
  end

  test 'read_version aborts for file without VERSION constant' do
    # Create a temp file without VERSION
    require 'tempfile'
    tmpfile = Tempfile.new(['no_version', '.rb'])
    tmpfile.write('module Foo; end')
    tmpfile.rewind

    assert_raises(SystemExit) do
      ReleaseHelper.read_version(tmpfile.path)
    end
  ensure
    tmpfile&.close
    tmpfile&.unlink
  end

  test 'next_version computes patch bump' do
    assert_equal '1.0.1', ReleaseHelper.next_version('1.0.0', 'patch')
  end

  test 'next_version computes minor bump' do
    assert_equal '1.1.0', ReleaseHelper.next_version('1.0.0', 'minor')
  end

  test 'next_version computes major bump' do
    assert_equal '2.0.0', ReleaseHelper.next_version('1.0.0', 'major')
  end
end
