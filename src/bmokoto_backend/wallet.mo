import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Error "mo:base/Error";

actor Wallet {
    type Account = { owner : Principal; subaccount : ?[Nat8] };
    type TransferArgs = {
        memo : Nat64;
        amount : { e8s : Nat64 };
        fee : { e8s : Nat64 };
        from_subaccount : ?[Nat8];
        to : Text;
        created_at_time : ?Nat64;
    };
    type Tokens = { e8s : Nat64 };
    type Result = { #Ok : Nat64; #Err : Text };

    // This should be the principal of the ICP ledger canister
    let LEDGER_CANISTER_ID : Text = "ryjl3-tyaaa-aaaaa-aaaba-cai";

    public shared(msg) func transferICP(to: Text, amount: Nat64) : async Result.Result<Nat64, Text> {
        let icpCanister = actor(LEDGER_CANISTER_ID) : actor {
            transfer : shared TransferArgs -> async Result;
        };

        let transferArgs : TransferArgs = {
            memo = 0;
            amount = { e8s = amount };
            fee = { e8s = 10000 }; // 0.0001 ICP
            from_subaccount = null;
            to = to;
            created_at_time = null;
        };

        try {
            let result = await icpCanister.transfer(transferArgs);
            switch (result) {
                case (#Ok(blockIndex)) {
                    #ok(blockIndex)
                };
                case (#Err(text)) {
                    #err(text)
                };
            }
        } catch (error) {
            #err("Unexpected error: " # Error.message(error))
        }
    };

    public func getBalance(account: Account) : async Result.Result<Tokens, Text> {
        let icpCanister = actor(LEDGER_CANISTER_ID) : actor {
            account_balance : shared query Account -> async Tokens;
        };

        try {
            let balance = await icpCanister.account_balance(account);
            #ok(balance)
        } catch (error) {
            #err("Failed to get balance: " # Error.message(error))
        }
    };
}