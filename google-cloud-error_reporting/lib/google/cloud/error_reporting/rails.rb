# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "google/cloud/error_reporting/v1beta1"
require "google/cloud/credentials"

module Google
  module Cloud
    module ErrorReporting
      ##
      # Railtie
      #
      # Google::Cloud::ErrorReporting::Railtie automatically add the
      # Google::Cloud::ErrorReporting::Middleware to Rack in a Rails environment.
      # It will automatically capture Exceptions from the Rails app and report
      # them to Stackdriver Error Reporting.
      #
      # The Middleware is only added when certain conditions are met. See
      # {Railtie.use_error_reporting?} for detail.
      #
      # When loaded, the Google::Cloud::ErrorReporting::Middleware will be
      # inserted after ::ActionDispatch::DebugExceptions Middleware, which allows
      # it to actually rescue all Exceptions and throw it back up. The middleware
      # should also be initialized with correct gcp project_id, keyfile,
      # service_name, and service_version if they are defined in
      # Rails environment files as follow:
      #   config.google_cloud.project_id = "my-gcp-project"
      #   config.google_cloud.keyfile = "/path/to/secret.json"
      # or
      #   config.google_cloud.error_reporting.project_id = "my-gcp-project"
      #   config.google_cloud.error_reporting.keyfile = "/path/to/secret.json"
      #   config.google_cloud.error_reporting.service_name = "my-service-name"
      #   config.google_cloud.error_reporting.service_version = "v1"
      #
      class Railtie < ::Rails::Railtie
        config.google_cloud = ActiveSupport::OrderedOptions.new unless
                                config.respond_to? :google_cloud
        config.google_cloud.error_reporting = ActiveSupport::OrderedOptions.new

        initializer "Google.Cloud.ErrorReporting" do |app|
          if self.class.use_error_reporting? app.config
            gcp_config = app.config.google_cloud
            er_config = gcp_config.error_reporting

            project_id = er_config.project_id || gcp_config.project_id
            keyfile = er_config.keyfile || gcp_config.keyfile

            channel = self.class.grpc_channel keyfile
            service_name = er_config.service_name ||
              error_reporting.class.default_service_name
            service_version = er_config.service_version ||
              error_reporting.class.default_service_version

            error_reporting =
              Google::Cloud::ErrorReporting::V1beta1::ReportErrorsServiceApi.new channel: channel,
                                                                                 app_name: service_name,
                                                                                 app_version: service_version

            # In later versions of Rails, ActionDispatch::DebugExceptions is
            # responsible for catching exceptions. But it didn't exist until
            # Rails 3.2. So we use ShowExceptions as pivot for earlier Rails.
            rails_exception_middleware =
              if defined? ::ActionDispatch::DebugExceptions
                ::ActionDispatch::DebugExceptions
              else
                ::ActionDispatch::ShowExceptions
              end

            app.middleware.insert_after rails_exception_middleware,
                                        Google::Cloud::ErrorReporting::Middleware,
                                        project_id: project_id,
                                        error_reporting: error_reporting,
                                        service_name: service_name,
                                        service_version: service_version
          end
        end

        ##
        # Construct a gRPC Channel object from given keyfile
        #
        # @param [String, Hash] keyfile Keyfile downloaded from Google Cloud. If
        #   file path the file must be readable.
        #
        # @return [GRPC::Core::Channel] gRPC Channel object based on given
        #   keyfile
        #
        def self.grpc_channel keyfile = nil
          require "grpc"

          scopes = Google::Cloud::ErrorReporting::V1beta1::ReportErrorsServiceApi::ALL_SCOPES
          credentials = if keyfile.nil?
                          Google::Cloud::Credentials.default(
                            scope: scopes)
                        else
                          Google::Cloud::Credentials.new(
                            keyfile, scope: scopes)
                        end

          # Return nil if :this_channel_is_insecure
          return nil if credentials == :this_channel_is_insecure

          channel_cred = GRPC::Core::ChannelCredentials.new.compose \
            GRPC::Core::CallCredentials.new credentials.client.updater_proc
          host = Google::Cloud::ErrorReporting::V1beta1::ReportErrorsServiceApi::SERVICE_ADDRESS

          GRPC::Core::Channel.new host, nil, channel_cred
        end

        ##
        # Determine whether to use Stackdriver Error Reporting or not.
        #
        # Returns true if valid GCP project_id and keyfile are provided and
        # either Rails is in "production" environment or \
        # config.google_cloud.use_error_reporting is explicitly true. Otherwise
        # false.
        #
        # @param config The Rails.application.config
        #
        # @return true or false
        #
        def self.use_error_reporting? config
          gcp_config = config.google_cloud
          er_config = gcp_config.error_reporting

          # Return false if config.google_cloud.use_error_reporting is
          # explicitly false
          return false if gcp_config.key?(:use_error_reporting) &&
                          !gcp_config.use_error_reporting

          # Check credentialing. Returns false if authorization errors are
          # rescued.
          keyfile = er_config.keyfile || gcp_config.keyfile
          begin
            grpc_channel keyfile
          rescue Exception => e
            Rails.logger.warn "Google::Cloud::ErrorReporting is not " \
            "activated due to authorization error: #{e.message}"
            return false
          end

          project_id = er_config.project_id ||
                       gcp_config.project_id ||
                       ENV["ERROR_REPORTING_PROJECT"] ||
                       ENV["GOOGLE_CLOUD_PROJECT"] ||
                       Google::Cloud::Core::Environment.project_id
          if project_id.to_s.empty?
            Rails.logger.warn "Google::Cloud::ErrorReporting is not " \
            "activated due to empty project_id"
            return false
          end

          # Otherwise return true if Rails is running in production or
          # config.google_cloud.use_error_reporting is explicitly true
          Rails.env.production? ||
            (gcp_config.key?(:use_error_reporting) &&
              gcp_config.use_error_reporting)
        end
      end
    end
  end
end