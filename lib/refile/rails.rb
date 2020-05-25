require "refile"
require "refile/rails/attachment_helper"

module Refile
  # @api private
  class Engine < Rails::Engine
    initializer "refile.setup", before: :load_environment_config do
      if RUBY_PLATFORM == "java"
        # Work around a bug in JRuby, see: https://github.com/jruby/jruby/issues/2779
        Encoding.default_internal = nil
      end

      Refile.store ||= Refile::Backend::FileSystem.new(Rails.root.join("tmp/uploads/store").to_s)
      Refile.cache ||= Refile::Backend::FileSystem.new(Rails.root.join("tmp/uploads/cache").to_s)

      ActiveSupport.on_load :active_record do
        require "refile/attachment/active_record"
      end

      ActionView::Base.send(:include, Refile::AttachmentHelper)
      ActionView::Helpers::FormBuilder.send(:include, AttachmentHelper::FormBuilder)
    end

    initializer "refile.app" do
      Refile.logger = Rails.logger
      Refile.app = Refile::App.new
    end

    initializer "refile.secret_key" do |app|
      Refile.secret_key ||= if app.respond_to?(:credentials) && key_exists?(app.credentials)
        app.credentials.secret_key_base
      elsif app.respond_to?(:secrets) && key_exists?(app.secrets)
        app.secrets.secret_key_base
      elsif app.config.respond_to?(:secret_key_base) && key_exists?(app.config)
        app.config.secret_key_base
      elsif app.config.respond_to?(:secret_token)
        app.config.secret_token
      end
    end

  private

    def key_exists?(object)
      object.secret_key_base.present?
    end
  end
end

# Add in missing methods for file uploads in Rails < 4
ActionDispatch::Http::UploadedFile.class_eval do
  unless instance_methods.include?(:eof?)
    def eof?
      @tempfile.eof?
    end
  end

  unless instance_methods.include?(:close)
    def close
      @tempfile.close
    end
  end
end
