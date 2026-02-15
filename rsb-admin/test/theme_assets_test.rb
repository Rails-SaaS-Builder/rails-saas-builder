# frozen_string_literal: true

require 'test_helper'

class ThemeAssetsTest < ActiveSupport::TestCase
  test 'default theme CSS file exists' do
    path = RSB::Admin::Engine.root.join('app', 'assets', 'stylesheets', 'rsb', 'admin', 'themes', 'default.css')
    assert File.exist?(path), "Default theme CSS not found at #{path}"
  end

  test 'modern theme CSS file exists' do
    path = RSB::Admin::Engine.root.join('app', 'assets', 'stylesheets', 'rsb', 'admin', 'themes', 'modern.css')
    assert File.exist?(path), "Modern theme CSS not found at #{path}"
  end

  test 'modern theme JS file exists' do
    path = RSB::Admin::Engine.root.join('app', 'assets', 'javascripts', 'rsb', 'admin', 'themes', 'modern.js')
    assert File.exist?(path), "Modern theme JS not found at #{path}"
  end

  test 'default theme CSS contains CSS variables' do
    path = RSB::Admin::Engine.root.join('app', 'assets', 'stylesheets', 'rsb', 'admin', 'themes', 'default.css')
    css = File.read(path)
    assert_includes css, '--rsb-admin-primary'
  end

  test 'modern theme CSS contains dark mode variables' do
    path = RSB::Admin::Engine.root.join('app', 'assets', 'stylesheets', 'rsb', 'admin', 'themes', 'modern.css')
    css = File.read(path)
    assert_includes css, 'data-rsb-mode'
  end

  test 'modern theme JS contains toggle function' do
    path = RSB::Admin::Engine.root.join('app', 'assets', 'javascripts', 'rsb', 'admin', 'themes', 'modern.js')
    js = File.read(path)
    assert_includes js, 'rsbToggleMode'
    assert_includes js, 'prefers-color-scheme'
    assert_includes js, 'localStorage'
  end
end
