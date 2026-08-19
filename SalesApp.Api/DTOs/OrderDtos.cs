namespace SalesApp.Api.DTOs;

// --- Create (RF-06..RF-10) ---

public class CreateOrderRequest
{
    public string CustomerCode { get; set; } = string.Empty; // SAP CardCode
    public int? SalesPersonCode { get; set; }                // defaults to the caller's JWT salesEmployeeCode
    public int? Series { get; set; }                         // SAP numbering series (UserSalesSeries)
    public DateTime? DueDate { get; set; }                   // SAP DocDueDate
    public string? Comments { get; set; }

    // Optional override of the customer's assigned payment terms group.
    // Defaults to the customer's own (SAP resolves it) when null.
    public int? PaymentTermsGroupCode { get; set; }          // -> SAP PaymentGroupCode

    // Device GPS fix captured at submit time (best-effort — null if denied/
    // unavailable). Sent to SAP as "lat,long" in the U_SL_Ubicacion UDF.
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    public List<CreateOrderLineRequest> Lines { get; set; } = new();
}

public class CreateOrderLineRequest
{
    public string ItemCode { get; set; } = string.Empty;
    public decimal Quantity { get; set; }

    // Sales unit of measure only. Per client decision the electronic-invoicing
    // (TFE) UoM is NOT captured here (diverges from the original CLAUDE.md note).
    public string? SalesUnitOfMeasure { get; set; }          // -> SAP line UoMCode

    public decimal? UnitPrice { get; set; }                  // optional; SAP resolves from price list if null
    public string? WarehouseCode { get; set; }
    public string? ProjectCode { get; set; }                 // -> SAP line ProjectCode
    public string? BranchCode { get; set; }                  // "Sucursal" -> SAP line CostingCode2 (DistributionRules.FactorCode)
}

// --- Read (RF-12, RF-16) ---

public class OrderDto
{
    public int Id { get; set; }                              // SAP DocEntry
    public int DocNum { get; set; }
    public string CustomerCode { get; set; } = string.Empty; // SAP CardCode
    public string? CustomerName { get; set; }                // SAP CardName
    public DateTime? DocDate { get; set; }
    public DateTime? DueDate { get; set; }
    public int? SalesPersonCode { get; set; }
    public string? SalesPersonName { get; set; }         // resolved from SalesPersonCode
    public int? Series { get; set; }
    public string? Comments { get; set; }

    // SalesApp username that created the order (SAP UDF U_SL_UsuarioApp) — also
    // used server-side to scope "my orders" for non-Administrator users.
    public string? CreatedByAppUser { get; set; }

    // Commercial fields the order inherited from the customer at creation time.
    // Resolved to names via ICatalogResolverService.
    public int? PriceListNum { get; set; }               // SAP PriceList (raw code)
    public string? PriceListName { get; set; }
    public int? PaymentTermsGroupCode { get; set; }      // SAP PaymentGroupCode (raw code)
    public string? PaymentTermsGroupName { get; set; }

    // SAP owns approval. We only DISPLAY the procedure status, never change it.
    public string Status { get; set; } = OrderStatus.Approved; // pending|approved|rejected

    // True when every line is closed in SAP (LineStatus = bost_Close), i.e. the
    // order was closed via POST /api/orders/{id}/close. Only meaningful for
    // approved orders — Status itself doesn't change on close.
    public bool IsClosed { get; set; }

    public decimal DocTotal { get; set; }
    public List<OrderLineDto> Lines { get; set; } = new();
}

public class OrderLineDto
{
    public int LineNum { get; set; }
    public string ItemCode { get; set; } = string.Empty;
    public string? Description { get; set; }                 // SAP line ItemDescription
    public decimal Quantity { get; set; }
    public string? SalesUnitOfMeasure { get; set; }          // SAP UoMCode / MeasureUnit
    public decimal? UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
    public string? WarehouseCode { get; set; }
    public string? ProjectCode { get; set; }
    public string? BranchCode { get; set; }
    public bool IsClosed { get; set; }                        // SAP LineStatus = bost_Close
}

// The only three states we ever surface — SAP's Approval Procedure result.
public static class OrderStatus
{
    public const string Pending = "pending";
    public const string Approved = "approved";
    public const string Rejected = "rejected";
}
