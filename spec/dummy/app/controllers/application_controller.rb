# frozen_string_literal: true

class ApplicationController < ActionController::Base
  skip_forgery_protection

  rescue_from ActionParamsContract::InvalidParamsError, with: :render_bad_request

  private

  def render_bad_request(exception)
    render json: { error: "Bad Request", details: exception.errors }, status: :bad_request
  end
end
