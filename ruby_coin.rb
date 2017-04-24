require 'grpc'
require './types_services_pb'
require 'rbnacl/libsodium'
require 'rbnacl'
require 'digest'
require 'json'

class RubyCoin < Types::ABCIApplication::Service

  class Account
    @all = []

    def initialize
      @balance = 100
      @prkey = RbNaCl::SigningKey.generate
      @pubkey = @prkey.verify_key
      @address = Digest::RMD160.digest "#{@pubkey}"
      @sequence = 0
      Account.all << self
    end

    attr_accessor :foreign_key
    attr_accessor :balance
    attr_reader :prkey
    attr_reader :pubkey
    attr_reader :address
    attr_accessor :sequence

    class << self
      attr_accessor :all
    end

  end

  class Transaction
    @all = []

    def initialize(sender, receiver, amount)
      @sender = sender
      @sender_act = nil
      @receiver = receiver
      @receiver_act = nil
      @amount = amount
      @sequence = nil
      Transaction.all << self
    end

    attr_reader :byte_self
    attr_reader :amount
    attr_reader :sender
    attr_reader :receiver
    attr_reader :destination
    attr_accessor :sender_act
    attr_accessor :receiver_act
    attr_accessor :sequence

    class << self
      attr_accessor :all
    end

  end

  accounts = []
  transactions = []
  @@commit_count = 0
  @@trans_count = 0

  a1 = Account.new
  p a1.address.unpack("H*")[0]
  a2 = Account.new
  p a2.address.unpack("H*")[0]

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
    t = trans.tx.dup.to_s
    t.gsub! "\'", "\""
    t_hash = JSON.parse(t)

    if t_hash["from"] == nil || t_hash["to"] == nil || t_hash["amount"] == nil
      Types::ResponseDeliverTx.new(code: :BadNonce, log: "request must include 'to', 'from', and 'amount'")
    elsif t_hash["amount"].class != Fixnum || t_hash["amount"] <= 0
      Types::ResponseDeliverTx.new(code: :BadNonce, log: "amount must be an int greater than zero")
    else
      tx = Transaction.new(t_hash["to"], t_hash["from"], t_hash["amount"])
      Account.all.each do |a|
        if a.address.unpack("H*")[0] == tx.sender
          tx.sender_act = a
        elsif a.address.unpack("H*")[0] == tx.receiver
          tx.receiver_act = a
        end
      end

      if tx.sender_act == nil || tx.receiver_act == nil
        Types::ResponseDeliverTx.new(code: :BadNonce, log: "at least one account not found")
      else
        tx.sequence = tx.sender_act.sequence
        byte_tx = Marshal.dump(tx)
        @signature = tx.sender_act.prkey.sign(byte_tx)
        verify_key = RbNaCl::VerifyKey.new(tx.sender_act.pubkey.to_s)
        if verify_key.verify(@signature, byte_tx)
          if tx.sender_act.balance >= tx.amount
            @@trans_count += 1
            Types::ResponseDeliverTx.new(code: :OK, log: "transferring #{tx.amount} coins")
          else
            Types::ResponseDeliverTx.new(code: :BadNonce, log: "insufficent funds")
          end
        else
          Types::ResponseDeliverTx.new(code: :BadNonce, log: "tx could not be verified")
        end
      end
    end
  end

  def check_tx(trans, _call)
    t = trans.tx.dup.to_s
    t.gsub! "\'", "\""
    t_hash = JSON.parse(t)

    if t_hash["from"] == nil || t_hash["to"] == nil || t_hash["amount"] == nil
      Types::ResponseCheckTx.new(code: :BadNonce, log: "request must include 'to', 'from', and 'amount'")
    elsif t_hash["amount"] <= 0 || t_hash["amount"].class != Fixnum
      Types::ResponseCheckTx.new(code: :BadNonce, log: "amount must be an int greater than zero")
    else
      tx = Transaction.new(t_hash["to"], t_hash["from"], t_hash["amount"])
      Account.all.each do |a|
        if a.address.unpack("H*")[0] == tx.sender
          tx.sender_act = a
        elsif a.address.unpack("H*")[0] == tx.receiver
          tx.receiver_act = a
        end
      end
      if tx.sender_act == nil || tx.receiver_act == nil
        Types::ResponseCheckTx.new(code: :BadNonce, log: "at least one account not found")
      else
        tx.sequence = tx.sender_act.sequence
        byte_tx = Marshal.dump(tx)
        @signature = tx.sender_act.prkey.sign(byte_tx)
        verify_key = RbNaCl::VerifyKey.new(tx.sender_act.pubkey.to_s)
        if verify_key.verify(@signature, byte_tx)
          if tx.sender_act.balance >= tx.amount
            Types::ResponseCheckTx.new(code: :OK, log: "tx valid")
          else
            Types::ResponseCheckTx.new(code: :BadNonce, log: "insufficent funds")
          end
        else
          Types::ResponseCheckTx.new(code: :BadNonce, log: "tx could not be verified")
        end
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

      Transaction.all.each do |t|
        t.sender_act.balance -= t.amount
        t.receiver_act.balance += t.amount
      end

      Types::ResponseCheckTx.new(data: byte_string)
    else
      Types::ResponseCheckTx.new(log: "no transactions to commit")
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
