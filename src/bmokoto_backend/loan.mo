import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Map "mo:base/HashMap";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

actor LoanCanister {
    type LoanId = Nat;
    type Error = {
        #NotFound;
        #AlreadyExists;
        #NotAuthorized;
        #InvalidStatus;
    };

    type Loan = {
        borrower: Principal;
        lender: ?Principal;
        amount: Nat;
        tenor: Nat; // Duration in days
        interestRate: Float;
        status: LoanStatus;
        createdAt: Time.Time;
        invoiceId: ?Text;
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

    public shared(msg) func registerLoan(amount: Nat, tenor: Nat, interestRate: Float) : async Result.Result<LoanId, Error> {
        let loanId = nextLoanId;
        nextLoanId += 1;

        let loan : Loan = {
            borrower = msg.caller;
            lender = null;
            amount = amount;
            tenor = tenor;
            interestRate = interestRate;
            status = #Pending;
            createdAt = Time.now();
            invoiceId = null;
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
                let updatedLoan = {
                    loan with
                    status = #Repaid;
                };
                loans.put(loanId, updatedLoan);
                #ok()
            };
        }
    };

    public shared(msg) func setInvoiceId(loanId: LoanId, invoiceId: Text) : async Result.Result<(), Error> {
        switch (loans.get(loanId)) {
            case (null) { #err(#NotFound) };
            case (?loan) {
                if (loan.borrower != msg.caller) {
                    return #err(#NotAuthorized);
                };
                let updatedLoan = {
                    loan with
                    invoiceId = ?invoiceId;
                };
                loans.put(loanId, updatedLoan);
                #ok()
            };
        }
    };

    public query func getAllLoans() : async [Loan] {
        Iter.toArray(loans.vals())
    };
}