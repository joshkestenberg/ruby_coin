require 'rbnacl/libsodium'
require 'rbnacl'
require 'digest'
require 'json'
require 'yaml'

class Account

  def initialize
    @balance = 100
    @prkey = RbNaCl::SigningKey.generate
    @pubkey = @prkey.verify_key.to_yaml
    add = Digest::RMD160.digest "#{@pubkey}"
    @address = add.unpack("H*")[0]
    @seq = 0
  end

  attr_reader :prkey
  attr_reader :address
  attr_reader :seq
  attr_reader :balance
  attr_reader :pubkey

end

a = Account.new

p "Private key: " + a.prkey.to_yaml
p "Address: #{a.address}"
p "Your sequence# is 0 and will increment by 1 with every transaction you send. Keep track of all of this information."

hash = JSON.load(File.read('./genesis.json'))

hash[a.address] = {
  balance: a.balance,
  pubkey: a.pubkey,
  seq: a.seq
}

File.open("./genesis.json","w") do |f|
  f.puts JSON.pretty_generate(hash)
end
