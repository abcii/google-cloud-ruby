# Copyright 2015 Google Inc. All rights reserved.
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


module Google
  module Cloud
    module Bigquery
      ##
      # # CopyJob
      #
      # A {Job} subclass representing a copy operation that may be performed on
      # a {Table}. A CopyJob instance is created when you call {Table#copy_job}.
      #
      # @see https://cloud.google.com/bigquery/docs/tables#copy-table Copying
      #   an Existing Table
      # @see https://cloud.google.com/bigquery/docs/reference/v2/jobs Jobs API
      #   reference
      #
      # @example
      #   require "google/cloud/bigquery"
      #
      #   bigquery = Google::Cloud::Bigquery.new
      #   dataset = bigquery.dataset "my_dataset"
      #   table = dataset.table "my_table"
      #   destination_table = dataset.table "my_destination_table"
      #
      #   copy_job = table.copy_job destination_table
      #
      #   copy_job.wait_until_done!
      #   copy_job.done? #=> true
      #
      class CopyJob < Job
        ##
        # The table from which data is copied. This is the table on
        # which {Table#copy_job} was called.
        #
        # @return [Table] A table instance.
        #
        def source
          table = @gapi.configuration.copy.source_table
          return nil unless table
          retrieve_table table.project_id,
                         table.dataset_id,
                         table.table_id
        end

        ##
        # The table to which data is copied.
        #
        # @return [Table] A table instance.
        #
        def destination
          table = @gapi.configuration.copy.destination_table
          return nil unless table
          retrieve_table table.project_id,
                         table.dataset_id,
                         table.table_id
        end

        ##
        # Checks if the create disposition for the job is `CREATE_IF_NEEDED`,
        # which provides the following behavior: If the table does not exist,
        # the copy operation creates the table. This is the default create
        # disposition for copy jobs.
        #
        # @return [Boolean] `true` when `CREATE_IF_NEEDED`, `false` otherwise.
        #
        def create_if_needed?
          disp = @gapi.configuration.copy.create_disposition
          disp == "CREATE_IF_NEEDED"
        end

        ##
        # Checks if the create disposition for the job is `CREATE_NEVER`, which
        # provides the following behavior: The table must already exist; if it
        # does not, an error is returned in the job result.
        #
        # @return [Boolean] `true` when `CREATE_NEVER`, `false` otherwise.
        #
        def create_never?
          disp = @gapi.configuration.copy.create_disposition
          disp == "CREATE_NEVER"
        end

        ##
        # Checks if the write disposition for the job is `WRITE_TRUNCATE`, which
        # provides the following behavior: If the table already exists, the copy
        # operation overwrites the table data.
        #
        # @return [Boolean] `true` when `WRITE_TRUNCATE`, `false` otherwise.
        #
        def write_truncate?
          disp = @gapi.configuration.copy.write_disposition
          disp == "WRITE_TRUNCATE"
        end

        ##
        # Checks if the write disposition for the job is `WRITE_APPEND`, which
        # provides the following behavior: If the table already exists, the copy
        # operation appends the data to the table.
        #
        # @return [Boolean] `true` when `WRITE_APPEND`, `false` otherwise.
        #
        def write_append?
          disp = @gapi.configuration.copy.write_disposition
          disp == "WRITE_APPEND"
        end

        ##
        # Checks if the write disposition for the job is `WRITE_EMPTY`, which
        # provides the following behavior: If the table already exists and
        # contains data, the job will have an error. This is the default write
        # disposition for copy jobs.
        #
        # @return [Boolean] `true` when `WRITE_EMPTY`, `false` otherwise.
        #
        def write_empty?
          disp = @gapi.configuration.copy.write_disposition
          disp == "WRITE_EMPTY"
        end
      end
    end
  end
end
