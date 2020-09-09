module Refile
  # Rails view helpers which aid in using Refile from views.
  module AttachmentHelper
    # Form builder extension
    module FormBuilder
      # @see AttachmentHelper#attachment_field
      def attachment_field(method, options = {})
        self.multipart = true
        @template.attachment_field(@object_name, method, **objectify_options(options))
      end

      # @see AttachmentHelper#attachment_cache_field
      def attachment_cache_field(method, options = {})
        self.multipart = true
        @template.attachment_cache_field(@object_name, method, **objectify_options(options))
      end
    end

    # View helper which generates a url for an attachment. This generates a URL
    # to the {Refile::App} which is assumed to be mounted in the Rails
    # application.
    #
    # @see Refile.attachment_url
    #
    # @param [Refile::Attachment] object   Instance of a class which has an attached file
    # @param [Symbol] name                 The name of the attachment column
    # @param [String, nil] filename        The filename to be appended to the URL
    # @param [String, nil] fallback        The path to an asset to be used as a fallback
    # @param [String, nil] format          A file extension to be appended to the URL
    # @param [String, nil] host            Override the host
    # @return [String, nil]                The generated URL
    def attachment_url(record, name, *args, fallback: nil, **opts)
      file = record && record.public_send(name)
      if file
        Refile.attachment_url(record, name, *args, **opts)
      elsif fallback
        asset_url(fallback)
      end
    end

    # Generates an image tag for the given attachment, adding appropriate
    # classes and optionally falling back to the given fallback image if there
    # is no file attached.
    #
    # Returns `nil` if there is no file attached and no fallback specified.
    #
    # @param [String] fallback                   The path to an image asset to be used as a fallback
    # @param [Hash] options                      Additional options for the image tag
    # @see #attachment_url
    # @return [ActiveSupport::SafeBuffer, nil]   The generated image tag
    def attachment_image_tag(record, name, *args, fallback: nil, host: nil, prefix: nil, format: nil, **options)
      file = record && record.public_send(name)
      classes = ["attachment", (record.class.model_name.singular if record), name, *options[:class]]

      if file
        image_tag(attachment_url(record, name, *args, host: host, prefix: prefix, format: format), options.merge(class: classes))
      elsif fallback
        classes << "fallback"
        image_tag(fallback, options.merge(class: classes))
      end
    end

    # Generates a form field which can be used with records which have
    # attachments. This will generate both a file field as well as a hidden
    # field which tracks the id of the file in the cache before it is
    # permanently stored.
    #
    # @param object_name                    The name of the object to generate a field for
    # @param method                         The name of the field
    # @param [Hash] options
    # @option options [Object] object       Set by the form builder, currently required for direct/presigned uploads to work.
    # @option options [Boolean] direct      If set to true, adds the appropriate data attributes for direct uploads with refile.js.
    # @option options [Boolean] presign     If set to true, adds the appropriate data attributes for presigned uploads with refile.js.
    # @return [ActiveSupport::SafeBuffer]   The generated form field
    def attachment_field(object_name, method, object:, **options)
      options[:data] ||= {}

      definition = object.send(:"#{method}_attachment_definition")
      options[:accept] = definition.accept

      if options[:direct]
        url = Refile.attachment_upload_url(object, method, host: options[:host], prefix: options[:prefix])
        options[:data].merge!(direct: true, as: "file", url: url)
      end

      if options[:presigned] and definition.cache.respond_to?(:presign)
        url = Refile.attachment_presign_url(object, method, host: options[:host], prefix: options[:prefix])
        options[:data].merge!(direct: true, presigned: true, url: url)
      end

      options[:data][:reference] = SecureRandom.hex
      options[:include_hidden] = false

      attachment_cache_field(object_name, method, object: object, **options) + file_field(object_name, method, options)
    end

    # Generates a hidden form field which tracks the id of the file in the cache
    # before it is permanently stored.
    #
    # @param object_name                    The name of the object to generate a field for
    # @param method                         The name of the field
    # @param [Hash] options
    # @option options [Object] object       Set by the form builder
    # @return [ActiveSupport::SafeBuffer]   The generated hidden form field
    def attachment_cache_field(object_name, method, object:, **options)
      options[:data] ||= {}
      options[:data][:reference] ||= SecureRandom.hex

      attacher_value = object.send("#{method}_data")

      hidden_options = {
        multiple: options[:multiple],
        value: attacher_value.try(:to_json),
        object: object,
        disabled: attacher_value.blank?,
        id: nil,
        data: { reference: options[:data][:reference] }
      }
      hidden_options.merge!(index: options[:index]) if options.key?(:index)

      hidden_field(object_name, method, hidden_options)
    end
  end
end
