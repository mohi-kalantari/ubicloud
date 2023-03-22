#!/bin/env ruby
# frozen_string_literal: true

unless (vm_name = ARGV.shift)
  puts "need vm name as argument"
  exit 1
end

# "Global Unicast" subnet, i.e. a subnet for exchanging packets with
# the internet.
unless (gua = ARGV.shift)
  puts "need global unicast subnet as argument"
  exit 1
end

unless (unix_user = ARGV.shift)
  puts "need unix user as argument"
  exit 1
end

unless (ssh_public_key = ARGV.shift)
  puts "need ssh public key as argument"
  exit 1
end

unless (boot_image = ARGV.shift)
  puts "need boot image as an argument"
  exit 1
end

require "fileutils"
require_relative "../lib/common"
require_relative "../lib/vm_setup"

VmSetup.new(vm_name).prep(unix_user, ssh_public_key, gua, boot_image)
