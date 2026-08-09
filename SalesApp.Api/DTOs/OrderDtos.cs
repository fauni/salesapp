namespace SalesApp.Api.DTOs;

// --- Create (RF-06..RF-10) ---

public class CreateOrderRequest
{
    public string CustomerCode { get; set; } = string.Empty; // SAP CardCode
    public int? SalesPersonCode { get; set; }                // defaults to the caller's JWT salesEmployeeCode
    public int? Series { get; set; }                         // SAP numbering series (UserSalesSeries)
    public DateTime? DueDate { get; set; }                   // SAP DocDueDate
    public string? Comments { get; set; }
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
    public int? Series { get; set; }
    public string? Comments { get; set; }

    // SAP owns approval. We only DISPLAY the procedure status, never change it.
    public string Status { get; set; } = OrderStatus.Approved; // pending|approved|rejected

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
}

// The only three states we ever surface — SAP's Approval Procedure result.
public static class OrderStatus
{
    public const string Pending = "pending";
    public const string Approved = "approved";
    public const string Rejected = "rejected";
}
