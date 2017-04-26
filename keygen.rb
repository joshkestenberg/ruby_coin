require 'rbnacl/libsodium'
require 'rbnacl'
require 'json'
require 'yaml'

p "Input your transaction details (from, to, seq, amount, prvkey)."

s = gets

hash = JSON.parse(s)
key = YAML.load(hash["prvkey"])
hash.delete("prvkey")
jhash = hash.to_json
p jhash
sig = key.sign(jhash).unpack("H*")[0]

t = {
  from: hash["from"],
  to: hash["to"],
  amount: hash["amount"],
  seq: hash["seq"],
  sig: sig
}

t_json = t.to_json

p "Transaction: " + t_json
