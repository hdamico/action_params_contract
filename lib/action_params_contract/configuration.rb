# frozen_string_literal: true

module ActionParamsContract
  class Configuration
    DEFAULT_WHITELISTED_PARAMS = %i[format controller action locale].freeze

    attr_accessor :whitelisted_params

    def initialize
      @whitelisted_params = DEFAULT_WHITELISTED_PARAMS.dup
    end
  end
end
