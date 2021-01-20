module Refile
  module ActiveRecord
    module Attachment
      include Refile::Attachment

      # Attachment method which hooks into ActiveRecord models
      #
      # @param [true, false] destroy  Whether to remove the stored file if its model is destroyed
      # @return [void]
      # @see Refile::Attachment#attachment
      def attachment(name, raise_errors: false, destroy: true, **options)
        super(name, raise_errors: raise_errors, **options)

        attacher = "#{name}_attacher"

        validate do
          if send(attacher).present?
            send(attacher).valid?
            errors = send(attacher).errors
            errors.each do |error_type, error|
              self.errors.add(name, error_type, **error)
            end
          end
        end

        define_method "#{name}=" do |value|
          send("#{name}_id_will_change!") if respond_to?("#{name}_id_will_change!")
          super(value)
        end

        define_method "remove_#{name}=" do |value|
          send("#{name}_id_will_change!")
          super(value)
        end

        define_method "remote_#{name}_url=" do |value|
          send("#{name}_id_will_change!")
          super(value)
        end

        before_save do
          send(attacher).store!
        end

        after_destroy do
          send(attacher).delete! if destroy
        end
      end

      # Macro which generates accessors in Active Record classes for assigning
      # multiple attachments at once. This is primarily useful together with
      # multiple file uploads. There is also a pure Ruby version of this macro.
      #
      # The name of the generated accessors will be the name of the association
      # and the name of the attachment in the associated model. So if a `Post`
      # accepts attachments for `images`, and the attachment in the `Image`
      # model is named `file`, then the accessors will be named `images_files`.
      #
      # @example in model
      #   class Post
      #     has_many :images, dependent: :destroy
      #     accepts_attachments_for :images
      #   end
      #
      # @example in associated model
      #   class Image
      #     attachment :file
      #   end
      #
      # @example in form
      #   <%= form_for @post do |form| %>
      #     <%= form.attachment_field :images_files, multiple: true %>
      #   <% end %>
      #
      # @param [Symbol]  association_name     Name of the association
      # @param [Symbol]  attachment           Name of the attachment in the associated model
      # @param [Boolean] append               If true, new files are appended instead of replacing the entire list of associated models.
      # @return [void]
      def accepts_attachments_for(association_name, attachment: :file, append: false)
        association = reflect_on_association(association_name)
        attachment_pluralized = attachment.to_s.pluralize
        name = "#{association_name}_#{attachment_pluralized}"
        collection_class = association && association.klass

        options = {
          collection_class: collection_class,
          name: name,
          attachment: attachment,
          append: append
        }

        mod = MultipleAttachments.new association_name, **options do
          define_method(:method_missing) do |method, *args|
            if method == attachment_pluralized.to_sym
              raise NoMethodError, "wrong association name #{method}, use like this #{name}"
            else
              super(method, *args)
            end
          end
        end

        include mod
      end
    end
  end
end

::ActiveRecord::Base.extend(Refile::ActiveRecord::Attachment)
