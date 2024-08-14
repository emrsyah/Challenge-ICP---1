import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {
    public type InvoiceId = Text;
    public type ErrorInvoice = {
        #NotFound;
        #AlreadyExists;
        #NotAuthorized;
        #InvalidStatus;
    };

    public type Invoice = {
        issuer: Principal;
        amount: Nat;
        dueDate: Time.Time;
        status: InvoiceStatus;
        createdAt: Time.Time;
    };

    public type InvoiceStatus = {
        #Pending;
        #Verified;
        #Paid;
        #Overdue;
    };
}