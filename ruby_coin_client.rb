require 'grpc'
require './types_services_pb'

def main
  stub = Types::ABCIApplication::Stub.new('localhost:46658', :this_channel_is_insecure)
end
