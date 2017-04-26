require 'grpc'
require './types_services_pb'
require 'rbnacl/libsodium'
require 'rbnacl'
require 'digest'
require 'json'
require 'yaml'

class RubyCoin < Types::ABCIApplication::Service



  class Transaction

    def initialize(from, to, seq, amount, sig)
      @from = from
      @to = to
      @seq = seq
      @amount = amount
      @sig = sig
    end

    attr_reader :amount
    attr_reader :to
    attr_reader :from
    attr_reader :seq
    attr_reader :sig

  end

  @@commit_count = 0
  @@trans_count = 0

  def echo(string, _call)
    Types::ResponseEcho.new(message: "#{string.message}")
  end

  def info(app, _call)
    Types::ResponseInfo.new(data: "committed blocks: #{@@commit_count}, unhashed transactions: #{@@trans_count}")
  end

  def set_option(flag, _call)
    Types::ResponseSetOption.new(log: "no options available for RubyCoin")
  end

  def deliver_tx(trans, _call)
    file = File.read('./genesis.json')
    accounts_hash = JSON.parse(file)

    t = trans.tx.dup.to_s
    t.gsub! "\'", "\""
    t_hash = JSON.parse(t)
    p t_hash["from"]
    p t_hash["to"]
    p t_hash["amount"]
    p t_hash["seq"]
    p t_hash["sig"]

    if t_hash["from"] == nil || t_hash["to"] == nil || t_hash["amount"] == nil || t_hash["seq"] == nil || t_hash["sig"] == nil
      Types::ResponseDeliverTx.new(code: :BadNonce, log: "request must include 'from', 'to', 'seq', 'amount', and 'sig'.")
    elsif t_hash["amount"].class != Fixnum || t_hash["amount"] <= 0
      Types::ResponseDeliverTx.new(code: :BadNonce, log: "amount must be an int greater than zero")
    else
      tx = Transaction.new(t_hash["from"], t_hash["to"], t_hash["seq"], t_hash["amount"], t_hash["sig"])

      if accounts_hash[t_hash["from"]] && accounts_hash[t_hash["to"]]
        p accounts_hash
        verify_key = RbNaCl::VerifyKey.new(YAML.load(accounts_hash[t_hash["from"]]["pubkey"]))
        message = {"from" => tx.from,"to" => tx.to, "seq" => tx.seq, "amount" => tx.amount}
        jmessage = message.to_json
        if verify_key.verify([tx.sig].pack("H*"), jmessage)
          if accounts_hash[t_hash["from"]]["balance"] >= tx.amount
            if accounts_hash[t_hash["from"]]["seq"] == tx.seq
              accounts_hash[t_hash["from"]]["balance"] -= tx.amount
              accounts_hash[t_hash["from"]]["seq"] += 1
              accounts_hash[t_hash["to"]]["balance"] += tx.amount

              File.open("./genesis.json","w") do |f|
                f.truncate(0)
                f.puts JSON.pretty_generate(accounts_hash)
              end

              Types::ResponseDeliverTx.new(code: :OK, log: "transferring #{tx.amount} coins")
            else
              Types::ResponseDeliverTx.new(code: :BadNonce, log: "invalid sequence")
            end
          else
            Types::ResponseDeliverTx.new(code: :BadNonce, log: "insufficent funds")
          end
        else
          Types::ResponseDeliverTx.new(code: :BadNonce, log: "tx could not be verified")
        end
      else
        Types::ResponseDeliverTx.new(code: :BadNonce, log: "one or more account not found")
      end
    end
  end

  def check_tx(trans, _call)
    file = File.read('./genesis.json')
    accounts_hash = JSON.parse(file)

    t = trans.tx.dup.to_s
    t.gsub! "\'", "\""
    t_hash = JSON.parse(t)



    if t_hash["from"] == nil || t_hash["to"] == nil || t_hash["amount"] == nil || t_hash["seq"] == nil || t_hash["sig"] == nil
      Types::ResponseCheckTx.new(code: :BadNonce, log: "request must include 'from', 'to', 'seq', 'amount', and 'sig'.")
    elsif t_hash["amount"].class != Fixnum || t_hash["amount"] <= 0
      Types::ResponseCheckTx.new(code: :BadNonce, log: "amount must be an int greater than zero")
    else
      tx = Transaction.new(t_hash["from"], t_hash["to"], t_hash["seq"], t_hash["amount"], t_hash["sig"])

      if accounts_hash[t_hash["from"]] && accounts_hash[t_hash["to"]]
        verify_key = RbNaCl::VerifyKey.new(YAML.load(accounts_hash[t_hash["from"]]["pubkey"]))
        message = {"from" => tx.from,"to" => tx.to, "seq" => tx.seq, "amount" => tx.amount}
        jmessage = message.to_json
        if verify_key.verify([tx.sig].pack("H*"), jmessage)
          if accounts_hash[t_hash["from"]]["balance"] >= tx.amount
            if accounts_hash[t_hash["from"]]["seq"] == tx.seq
              Types::ResponseCheckTx.new(code: :OK, log: "valid tx")
            else
              Types::ResponseCheckTx.new(code: :BadNonce, log: "invalid sequence")
            end
          else
            Types::ResponseCheckTx.new(code: :BadNonce, log: "insufficent funds")
          end
        else
          Types::ResponseCheckTx.new(code: :BadNonce, log: "tx could not be verified")
        end
      else
        Types::ResponseCheckTx.new(code: :BadNonce, log: "one or more account not found")
      end
    end
  end

  def commit(commit, _call)
    if @@trans_count > 0
      @@commit_count += 1

      last_byte = @@trans_count % 256

      byte_array = []
      x = 7

      7.times do |time|
        base = 256 ** x
        digit = @@trans_count / base
        @@trans_count -= digit * base
        byte_array << digit
        x -= 1
      end

      byte_array << last_byte
      byte_string = byte_array.pack("C*")

      Types::ResponseCommit.new(data: byte_string)
    else
      Types::ResponseCommit.new(log: "no transactions to commit")
    end
  end

  def begin_block(beg, _call)
    beg
  end

  def end_block(e, _call)
    e
  end

end

def main
  s = GRPC::RpcServer.new
  s.add_http2_port('127.0.0.1:46658', :this_port_is_insecure)
  s.handle(RubyCoin)
  s.run_till_terminated
end

main
