import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Map "mo:base/HashMap";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import InvoiceTypes "types";

actor {


    private var invoices = Map.HashMap<InvoiceTypes.InvoiceId, InvoiceTypes.Invoice>(0, Text.equal, Text.hash);

    public shared(msg) func registerInvoice(invoiceId: InvoiceTypes.InvoiceId, amount: Nat, dueDate: Time.Time) : async Result.Result<(), InvoiceTypes.ErrorInvoice> {
        switch (invoices.get(invoiceId)) {
            case (?_) { #err(#AlreadyExists) };
            case (null) {
                let invoice : InvoiceTypes.Invoice = {
                    issuer = msg.caller;
                    amount = amount;
                    dueDate = dueDate;
                    status = #Pending;
                    createdAt = Time.now();
                };
                invoices.put(invoiceId, invoice);
                #ok()
            };
        }
    };

    public query func getInvoice(invoiceId: InvoiceTypes.InvoiceId) : async Result.Result<InvoiceTypes.Invoice, InvoiceTypes.ErrorInvoice> {
        switch (invoices.get(invoiceId)) {
            case (null) { #err(#NotFound) };
            case (?invoice) { #ok(invoice) };
        }
    };

    public shared(msg) func verifyInvoice(invoiceId: InvoiceTypes.InvoiceId) : async Result.Result<(), InvoiceTypes.ErrorInvoice> {
        switch (invoices.get(invoiceId)) {
            case (null) { #err(#NotFound) };
            case (?invoice) {
                if (invoice.status != #Pending) {
                    return #err(#InvalidStatus);
                };
                // In a real-world scenario, you'd implement proper authorization checks here
                let updatedInvoice = {
                    invoice with
                    status = #Verified;
                };
                invoices.put(invoiceId, updatedInvoice);
                #ok()
            };
        }
    };

    public shared(msg) func updateInvoiceStatus(invoiceId: InvoiceTypes.InvoiceId, newStatus: InvoiceTypes.InvoiceStatus) : async Result.Result<(), InvoiceTypes.ErrorInvoice> {
        switch (invoices.get(invoiceId)) {
            case (null) { #err(#NotFound) };
            case (?invoice) {
                if (invoice.issuer != msg.caller) {
                    return #err(#NotAuthorized);
                };
                let updatedInvoice = {
                    invoice with
                    status = newStatus;
                };
                invoices.put(invoiceId, updatedInvoice);
                #ok()
            };
        }
    };

    public func checkOverdueInvoices() : async () {
        let currentTime = Time.now();
        for ((id, invoice) in invoices.entries()) {
            if (invoice.status == #Verified and invoice.dueDate < currentTime) {
                let updatedInvoice = {
                    invoice with
                    status = #Overdue;
                };
                invoices.put(id, updatedInvoice);
            };
        };
    };

    public query func getAllInvoices() : async [InvoiceTypes.Invoice] {
        Iter.toArray(invoices.vals())
    };
}