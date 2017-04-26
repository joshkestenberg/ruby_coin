# ruby_coin

1. run actgen  ```ruby actgen.rb``` (even though there are already seeded accounts, you need to create an account in order to acquire a private key)
2. run keygen  ```ruby keygen.rb```--- it will prompt you for a json string like this: 

```{"from":"3ae5afa84f5b00b3f72a637f2e3a4d6fff93c53e","to":"ac128a0fd1a90515d06e1f6917f255f37e9337ae","seq":1,"amount":10,"prvkey":"--- !ruby/object:RbNaCl::Signatures::Ed25519::SigningKey\nseed: !binary |-\n  mr4rVlIW6cY8eYk+Dihnn/4jFfH6Kweset0FMOVtPIo=\nsigning_key: !binary |-\n  mr4rVlIW6cY8eYk+Dihnn/4jFfH6Kweset0FMOVtPIoQ7Bcmk9IND6Un9bxr\n  LuocPvw35XWMyUguBrlshPaUIQ==\nverify_key: !ruby/object:RbNaCl::Signatures::Ed25519::VerifyKey\n  key: !binary |-\n    EOwXJpPSDQ+lJ/W8ay7qHD78N+V1jMlILga5bIT2lCE=\n"}```

-it will then give you a json hash.. right now you just need the signature it provides.

3. run ruby_coin server ```ruby rubycoin.rb```
4. from abci-cli, make requests like so: 

```abci-cli --abci grpc deliver_tx "\"{'from': '3ae5afa84f5b00b3f72a637f2e3a4d6fff93c53e', 'to': 'ac128a0fd1a90515d06e1f6917f255f37e9337ae', 'seq': 1, 'amount': 10, 'sig': 'b6b940eeb2301a25170923fe91c1ff7d632258198b48273f5b5c869c9869261bfbe8d429ffa5de15d851b4d6b5c3631b138f1e449126e9d862e2b14ae4fdd404'}\""```

-formatting is crucial. make sure you're using the correct sequence number.
