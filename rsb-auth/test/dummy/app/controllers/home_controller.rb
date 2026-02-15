# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    render plain: 'OK'
  end
end
