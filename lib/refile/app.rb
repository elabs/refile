require "json"
require "sinatra/base"

module Refile
  class App < Sinatra::Base
    configure do
      set :show_exceptions, false
      set :raise_errors, false
      set :sessions, false
      set :logging, false
      set :dump_errors, false
    end

    before do
      content_type ::File.extname(request.path), default: "application/octet-stream"
      if Refile.allow_origin
        response["Access-Control-Allow-Origin"] = Refile.allow_origin
        response["Access-Control-Allow-Headers"] = request.env["HTTP_ACCESS_CONTROL_REQUEST_HEADERS"].to_s
        response["Access-Control-Allow-Method"] = request.env["HTTP_ACCESS_CONTROL_REQUEST_METHOD"].to_s
      end
    end

    head "/:backend/:id" do
      unless backend.exists?(params[:id])
        status 404
      end
    end

    get "/:backend/:id/:filename" do
      set_expires_header
      stream_file(file)
    end

    get "/:backend/:processor/:id/:file_basename.:extension" do
      set_expires_header
      stream_file processor.call(file, format: params[:extension])
    end

    get "/:backend/:processor/:id/:filename" do
      set_expires_header
      stream_file processor.call(file)
    end

    get "/:backend/:processor/*/:id/:file_basename.:extension" do
      set_expires_header
      stream_file processor.call(file, *params[:splat].first.split("/"), format: params[:extension])
    end

    get "/:backend/:processor/*/:id/:filename" do
      set_expires_header
      stream_file processor.call(file, *params[:splat].first.split("/"))
    end

    options "/:backend" do
      ""
    end

    post "/:backend" do
      backend = Refile.backends[params[:backend]]
      halt 404 unless backend && Refile.direct_upload.include?(params[:backend])
      tempfile = request.params.fetch("file").fetch(:tempfile)
      file = backend.upload(tempfile)
      content_type :json
      { id: file.id }.to_json
    end

    not_found do
      content_type :text
      "not found"
    end

    error do |error_thrown|
      log_error("Error -> #{error_thrown}")
      error_thrown.backtrace.each do |line|
        log_error(line)
      end
      content_type :text
      "error"
    end

  private

    def set_expires_header
      expires Refile.content_max_age, :public, :must_revalidate
    end

    def logger
      Refile.logger
    end

    def stream_file(file)
      stream do |out|
        file.each do |chunk|
          out << chunk
        end
      end
    end

    def backend
      backend = Refile.backends[params[:backend]]
      unless backend
        log_error("Could not find backend: #{params[:backend]}")
        halt 404
      end
      backend
    end

    def file
      file = backend.get(params[:id])
      unless file.exists?
        log_error("Could not find attachment by id: #{params[:id]}")
        halt 404
      end
      file
    end

    def processor
      processor = Refile.processors[params[:processor]]
      unless processor
        log_error("Could not find processor: #{params[:processor]}")
        halt 404
      end
      processor
    end

    def log_error(message)
      logger.error "#{self.class.name}: #{message}"
    end
  end
end
