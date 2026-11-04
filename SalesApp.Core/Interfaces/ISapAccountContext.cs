namespace SalesApp.Core.Interfaces;

// Which SapAccount the current call to SAP should log in as. Implemented in
// the Api from the caller's JWT ("sapAccountId" claim); null = no user or no
// account assigned -> the technical account from Parameters.
public interface ISapAccountContext
{
    int? SapAccountId { get; }
}
