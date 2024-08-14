import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Map "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Invoice "canister:invoice";
import Types "types";

actor {
    type LoanId = Nat;
    type Error = {
        #NotFound;
        #AlreadyExists;
        #NotAuthorized;
        #InvalidStatus;
        #TransferFailed;
    };

    type Loan = {
        borrower: Principal;
        lender: ?Principal;
        amount: Nat64;
        tenor: Nat; // Duration in days
        interestRate: Float;
        status: LoanStatus;
        createdAt: Time.Time;
        invoiceId: Text;
    };

    type LoanStatus = {
        #Pending;
        #Active;
        #Repaid;
        #Defaulted;
    };

    // Custom hash function for Nat
    private func natHash(n : Nat) : Hash.Hash {
        Text.hash(Nat.toText(n))
    };

    private stable var nextLoanId : Nat = 0;
    private var loans = Map.HashMap<LoanId, Loan>(0, Nat.equal, natHash);

    let WALLET_CANISTER_ID : Text = ""; // Replace with your Wallet Canister ID

    public shared(msg) func registerLoan(amount: Nat64, tenor: Nat, interestRate: Float) : async Result.Result<LoanId, Error> {
        let loanId = nextLoanId;
        nextLoanId += 1;

        let ress = await Invoice.registerInvoice("10", 10, Time.now());
        
        let loan : Loan = {
            borrower = msg.caller;
            lender = null;
            amount = amount;
            tenor = tenor;
            interestRate = interestRate;
            status = #Pending;
            createdAt = Time.now();
            invoiceId = "10";
        };
        
        loans.put(loanId, loan);
        #ok(loanId)
    };

    public query func getLoan(loanId: LoanId) : async Result.Result<Loan, Error> {
        switch (loans.get(loanId)) {
            case (null) { #err(#NotFound) };
            case (?loan) { #ok(loan) };
        }
    };

    public shared(msg) func acceptLoan(loanId: LoanId) : async Result.Result<(), Error> {
        switch (loans.get(loanId)) {
            case (null) { #err(#NotFound) };
            case (?loan) {
                if (loan.status != #Pending) {
                    return #err(#InvalidStatus);
                };
                
                // Transfer ICP from lender to borrower
                let walletCanister = actor(WALLET_CANISTER_ID) : actor {
                    transferICP : shared (Text, Nat64) -> async Result.Result<Nat64, Text>;
                };
                
                let borrowerAddress = Principal.toText(loan.borrower);
                let transferResult = await walletCanister.transferICP(borrowerAddress, loan.amount);
                
                switch (transferResult) {
                    case (#err(message)) {
                        return #err(#TransferFailed);
                    };
                    case (#ok(_)) {
                        let updatedLoan = {
                            loan with
                            lender = ?msg.caller;
                            status = #Active;
                        };
                        loans.put(loanId, updatedLoan);
                        #ok()
                    };
                }
            };
        }
    };

   public shared(msg) func repayLoan(loanId: LoanId) : async Result.Result<(), Error> {
    switch (loans.get(loanId)) {
        case (null) { #err(#NotFound) };
        case (?loan) {
            if (loan.borrower != msg.caller) {
                return #err(#NotAuthorized);
            };
            if (loan.status != #Active) {
                return #err(#InvalidStatus);
            };
            
            switch (loan.lender) {
                case (null) { return #err(#InvalidStatus) };
                case (?lender) {
                    // Calculate repayment amount (principal + interest)
                    let principal = Float.fromInt64(Int64.fromNat64(loan.amount));
                    let interestAmount = principal * loan.interestRate * (Float.fromInt(loan.tenor) / 365.0);
                    let totalRepayment = principal + interestAmount;
                    
                    // Convert the float repayment amount to Nat64
                    let repaymentAmount = Nat64.fromNat(Int.abs(Float.toInt(totalRepayment)));
                    
                    // Transfer ICP from borrower to lender
                    let walletCanister = actor(WALLET_CANISTER_ID) : actor {
                        transferICP : shared (Text, Nat64) -> async Result.Result<Nat64, Text>;
                    };
                    
                    let lenderAddress = Principal.toText(lender);
                    let transferResult = await walletCanister.transferICP(lenderAddress, repaymentAmount);
                    
                    switch (transferResult) {
                        case (#err(message)) {
                            return #err(#TransferFailed);
                        };
                        case (#ok(_)) {
                            let updatedLoan = {
                                loan with
                                status = #Repaid;
                            };
                            loans.put(loanId, updatedLoan);
                            #ok()
                        };
                    }
                };
            }
        };
    }
};

    // public shared(msg) func setInvoiceId(loanId: LoanId, invoiceId: Text) : async Result.Result<(), Error> {
    //     switch (loans.get(loanId)) {
    //         case (null) { #err(#NotFound) };
    //         case (?loan) {
    //             if (loan.borrower != msg.caller) {
    //                 return #err(#NotAuthorized);
    //             };
    //             let updatedLoan = {
    //                 loan with
    //                 invoiceId = ?invoiceId;
    //             };
    //             loans.put(loanId, updatedLoan);
    //             #ok()
    //         };
    //     }
    // };

    public query func getAllLoans() : async [Loan] {
        Iter.toArray(loans.vals())
    };
}