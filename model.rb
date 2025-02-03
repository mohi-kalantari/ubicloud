# frozen_string_literal: true

require_relative "db"
require "sequel/model"

if ENV["RACK_ENV"] == "development"
  Sequel::Model.cache_associations = false
end

Sequel::Model.plugin :auto_validations
Sequel::Model.plugin :require_valid_schema
Sequel::Model.plugin :singular_table_names
Sequel::Model.plugin :subclasses unless ENV["RACK_ENV"] == "development"
Sequel::Model.plugin :column_encryption do |enc|
  enc.key 0, Config.clover_column_encryption_key
end
Sequel::Model.plugin :many_through_many
Sequel::Model.plugin :insert_conflict
Sequel::Model.plugin :inspect_pk
Sequel::Model.plugin :static_cache_cache, "cache/static_cache.cache"
Sequel::Model.plugin :pg_auto_constraint_validations, cache_file: "cache/pg_auto_constraint_validations.cache"
Sequel::Model.plugin :pg_eager_any_typed_array

def Sequel.any_type(array, type)
  Sequel.function(:ANY, Sequel.pg_array(array, type))
end

def Sequel.any_uuid(array)
  if array.is_a?(Array)
    any_type(array, :uuid)
  else
    array
  end
end

if (level = Config.database_logger_level) || Config.test?
  require "logger"
  LOGGER = Logger.new($stdout, level: level || "fatal")
  DB.loggers << LOGGER
end

module SequelExtensions
  def delete(force: false, &)
    # Do not error if this is a plain dataset that does not respond to destroy
    return super(&) unless respond_to?(:destroy)

    rodaauth_in_callstack = !caller.grep(/rodauth/).empty?
    destroy_in_callstack = !caller.grep(/sequel\/model\/base.*_destroy_delete/).empty?
    unless rodaauth_in_callstack || destroy_in_callstack || force
      raise "Calling delete is discouraged as it skips hooks such as before_destroy, which " \
            "we use to archive records. Use destroy instead. If you know what you are doing " \
            "and still want to use delete, you can pass force: true to trigger delete."
    end

    if is_a?(Sequel::Dataset)
      super(&)
    else
      super()
    end
  end
end

module Sequel
  class Dataset
    prepend SequelExtensions
  end

  class Model
    prepend SequelExtensions
  end
end
