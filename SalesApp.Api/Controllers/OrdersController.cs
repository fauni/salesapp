using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Interfaces;
using SalesApp.Infrastructure.Catalog;

namespace SalesApp.Api.Controllers;

// Sales orders. Business rules baked in from CLAUDE.md:
//  - SAP owns approval: we only DISPLAY status, never approve/reject.
//  - No credit-limit validation (out of scope, confirmed with client).
//  - Order lines carry only the SALES UoM (client decision; no TFE UoM).
// Approved orders live in SAP's `Orders`; pending/rejected live in `Drafts`.
[ApiController]
[Route("api/orders")]
[Authorize]
public class OrdersController : ControllerBase
{
    private readonly ISapServiceLayerClient _sapClient;
    private readonly ICatalogResolverService _catalogResolver;

    // Same field set for Orders and Drafts (Drafts mirror the document schema).
    // PaymentGroupCode is the payment-terms field the order inherited from the
    // customer — surfaced (as a name) in the order detail. (Price list is not a
    // valid document-header field in this SAP version, so it's not selected.)
    private const string OrderSelect =
        "DocEntry,DocNum,CardCode,CardName,DocDate,DocDueDate,SalesPersonCode,Series,"
        + "Comments,DocTotal,PaymentGroupCode,DocumentLines";

    // SAP BoObjectTypes value for a Sales Order (used to filter Drafts).
    private const string SalesOrderObjectCode = "17";

    public OrdersController(
        ISapServiceLayerClient sapClient, ICatalogResolverService catalogResolver)
    {
        _sapClient = sapClient;
        _catalogResolver = catalogResolver;
    }

    // POST /api/orders  (RF-06..RF-10)
    [HttpPost]
    public async Task<ActionResult<OrderDto>> Create(CreateOrderRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.CustomerCode))
            return BadRequest(new { message = "CustomerCode is required." });
        if (request.Lines.Count == 0)
            return BadRequest(new { message = "An order needs at least one line." });

        var body = BuildOrderBody(request);

        // NOTE: no credit-limit check here — intentionally out of scope.
        // SAP validation errors surface via SapExceptionFilter (400/502).
        var json = await _sapClient.PostAsync("Orders", body, ct);
        using var doc = JsonDocument.Parse(json);
        var created = MapOrder(doc.RootElement, OrderStatus.Approved);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    // GET /api/orders?status=pending|approved|rejected  (RF-12)
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OrderDto>>> List(
        [FromQuery] string? status, CancellationToken ct)
    {
        status = (status ?? OrderStatus.Approved).Trim().ToLowerInvariant();

        var salesFilter = BuildSalesPersonFilter();

        string entity;
        var filters = new List<string>();

        switch (status)
        {
            case OrderStatus.Approved:
                // Approved (or no approval needed) => real Orders.
                entity = "Orders";
                break;

            case OrderStatus.Pending:
            case OrderStatus.Rejected:
                // Pending/rejected sit in Drafts of type Sales Order.
                // TODO(client-config): distinguishing pending vs rejected requires
                // the draft's ApprovalRequests.Status — not wired yet. Until then
                // both statuses return the same sales-order drafts set. Confirm the
                // client's Approval Procedure config before relying on this split.
                entity = "Drafts";
                filters.Add($"DocObjectCode eq '{SalesOrderObjectCode}'");
                break;

            default:
                return BadRequest(new { message = "status must be pending, approved or rejected." });
        }

        if (salesFilter != null) filters.Add(salesFilter);

        var query = $"{entity}?$select={OrderSelect}&$orderby=DocDate desc&$top=50";
        if (filters.Count > 0)
            query += $"&$filter={Uri.EscapeDataString(string.Join(" and ", filters))}";

        var json = await _sapClient.GetAsync(query, ct);
        using var doc = JsonDocument.Parse(json);
        var orders = doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(e => MapOrder(e, status))
            .ToList();
        return Ok(orders);
    }

    // GET /api/orders/{id}?status=pending|approved|rejected
    // Approved orders live in SAP's `Orders`; pending/rejected are `Drafts`.
    // The caller (order list) already knows the status, so it tells us which
    // entity to read — otherwise a draft id would 404 against Orders.
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDto>> GetById(
        int id, [FromQuery] string? status, CancellationToken ct)
    {
        var normalized = (status ?? OrderStatus.Approved).Trim().ToLowerInvariant();
        var isDraft = normalized is OrderStatus.Pending or OrderStatus.Rejected;
        var entity = isDraft ? "Drafts" : "Orders";
        var displayStatus = isDraft ? normalized : OrderStatus.Approved;

        var json = await _sapClient.GetAsync($"{entity}({id})?$select={OrderSelect}", ct);
        using var doc = JsonDocument.Parse(json);
        var dto = MapOrder(doc.RootElement, displayStatus);
        await ResolveNamesAsync(dto, ct);
        return Ok(dto);
    }

    // GET /api/orders/{id}/pdf  (RF-16)
    [HttpGet("{id:int}/pdf")]
    public async Task<IActionResult> GetPdf(int id, CancellationToken ct)
    {
        // Validate the order exists first. If it doesn't, SapExceptionFilter
        // turns SAP's 404 into a 404 for us before we reach the 501 below.
        await _sapClient.GetAsync($"Orders({id})?$select=DocEntry", ct);

        // SAP B1 Service Layer has NO native "render document as PDF" endpoint;
        // print layouts live in Crystal/EFM, not in OData. This needs a decision:
        // generate the PDF server-side (e.g. QuestPDF) from the order data, or hook
        // a client-side SAP print mechanism. Not implemented yet by design.
        return StatusCode(StatusCodes.Status501NotImplemented, new
        {
            message = "PDF generation is not implemented yet. SAP Service Layer does "
                    + "not expose order PDFs; a server-side generator must be chosen."
        });
    }

    // POST /api/orders/{id}/duplicate  (RF-15)
    [HttpPost("{id:int}/duplicate")]
    public async Task<ActionResult<OrderDto>> Duplicate(int id, CancellationToken ct)
    {
        var srcJson = await _sapClient.GetAsync($"Orders({id})?$select={OrderSelect}", ct);
        OrderDto source;
        using (var srcDoc = JsonDocument.Parse(srcJson))
            source = MapOrder(srcDoc.RootElement, OrderStatus.Approved);

        // Rebuild a fresh create request from the source. Dates and doc numbers are
        // left to SAP; prices are NOT copied so the new order re-prices against the
        // current price list.
        var clone = new CreateOrderRequest
        {
            CustomerCode = source.CustomerCode,
            SalesPersonCode = source.SalesPersonCode,
            Series = source.Series,
            Comments = source.Comments,
            Lines = source.Lines.Select(l => new CreateOrderLineRequest
            {
                ItemCode = l.ItemCode,
                Quantity = l.Quantity,
                SalesUnitOfMeasure = l.SalesUnitOfMeasure,
                WarehouseCode = l.WarehouseCode
            }).ToList()
        };

        var json = await _sapClient.PostAsync("Orders", BuildOrderBody(clone), ct);
        using var doc = JsonDocument.Parse(json);
        var created = MapOrder(doc.RootElement, OrderStatus.Approved);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    // --- helpers ---

    // Builds the SAP order payload, omitting null/empty fields so we never
    // overwrite SAP defaults with nulls.
    private Dictionary<string, object> BuildOrderBody(CreateOrderRequest request)
    {
        var salesPersonCode = request.SalesPersonCode ?? CurrentSalesPersonCode();

        var lines = new List<Dictionary<string, object>>();
        foreach (var l in request.Lines)
        {
            var line = new Dictionary<string, object>
            {
                ["ItemCode"] = l.ItemCode,
                ["Quantity"] = l.Quantity
            };
            if (!string.IsNullOrWhiteSpace(l.SalesUnitOfMeasure))
                line["UoMCode"] = l.SalesUnitOfMeasure;
            // The rep enters the gross (VAT-inclusive) unit price. In SAP that is
            // the line's "price after VAT" — DB field RDR1.PriceAfVAT, exposed by
            // the Service Layer as PriceAfterVAT. SAP back-calculates the net
            // UnitPrice from it. (Setting UnitPrice instead is wrong when the
            // document works with gross prices — SAP overwrites it.)
            if (l.UnitPrice.HasValue)
                line["PriceAfterVAT"] = l.UnitPrice.Value;
            if (!string.IsNullOrWhiteSpace(l.WarehouseCode))
                line["WarehouseCode"] = l.WarehouseCode;
            lines.Add(line);
        }

        var body = new Dictionary<string, object>
        {
            ["CardCode"] = request.CustomerCode,
            ["DocumentLines"] = lines
        };
        if (salesPersonCode.HasValue) body["SalesPersonCode"] = salesPersonCode.Value;
        if (request.Series.HasValue) body["Series"] = request.Series.Value;
        if (request.DueDate.HasValue) body["DocDueDate"] = request.DueDate.Value.ToString("yyyy-MM-dd");
        if (!string.IsNullOrWhiteSpace(request.Comments)) body["Comments"] = request.Comments;

        return body;
    }

    // Reps only see/own their orders; Administrators see everything.
    private string? BuildSalesPersonFilter()
    {
        if (User.IsInRole("Administrator")) return null;
        var code = CurrentSalesPersonCode();
        return code.HasValue ? $"SalesPersonCode eq {code.Value}" : null;
    }

    private int? CurrentSalesPersonCode() =>
        int.TryParse(User.FindFirst("salesEmployeeCode")?.Value, out var code) ? code : null;

    private static OrderDto MapOrder(JsonElement e, string status)
    {
        var dto = new OrderDto
        {
            Id = Int(e, "DocEntry") ?? 0,
            DocNum = Int(e, "DocNum") ?? 0,
            CustomerCode = Str(e, "CardCode") ?? string.Empty,
            CustomerName = Str(e, "CardName"),
            DocDate = Dtm(e, "DocDate"),
            DueDate = Dtm(e, "DocDueDate"),
            SalesPersonCode = Int(e, "SalesPersonCode"),
            Series = Int(e, "Series"),
            Comments = Str(e, "Comments"),
            DocTotal = Dec(e, "DocTotal") ?? 0m,
            PaymentTermsGroupCode = Int(e, "PaymentGroupCode"),
            Status = status
        };

        if (e.TryGetProperty("DocumentLines", out var lines) && lines.ValueKind == JsonValueKind.Array)
        {
            foreach (var l in lines.EnumerateArray())
            {
                dto.Lines.Add(new OrderLineDto
                {
                    LineNum = Int(l, "LineNum") ?? 0,
                    ItemCode = Str(l, "ItemCode") ?? string.Empty,
                    // Service Layer exposes the item description as `ItemDescription`.
                    // `Dscription` is only the underlying RDR1 column name — kept as
                    // a fallback in case of an older Service Layer build.
                    Description = Str(l, "ItemDescription") ?? Str(l, "Dscription"),
                    Quantity = Dec(l, "Quantity") ?? 0m,
                    SalesUnitOfMeasure = Str(l, "UoMCode") ?? Str(l, "MeasureUnit"),
                    // Surface the gross (VAT-inclusive) price the rep entered —
                    // SAP's PriceAfterVAT — falling back to the net UnitPrice.
                    UnitPrice = Dec(l, "PriceAfterVAT") ?? Dec(l, "UnitPrice"),
                    LineTotal = Dec(l, "LineTotal") ?? 0m,
                    WarehouseCode = Str(l, "WarehouseCode")
                });
            }
        }

        return dto;
    }

    // Resolves the commercial code fields to human-readable names (salesperson,
    // price list, payment terms) via the cached catalog resolver. Kept separate
    // from MapOrder because it's async and only needed for single-order reads.
    private async Task ResolveNamesAsync(OrderDto dto, CancellationToken ct)
    {
        if (dto.SalesPersonCode is int slp && slp > 0)
        {
            var name = await _catalogResolver.GetSalesPersonNameAsync(slp, ct);
            dto.SalesPersonName = string.IsNullOrEmpty(name) ? null : name;
        }
        if (dto.PaymentTermsGroupCode is int pt && pt > 0)
        {
            var name = await _catalogResolver.GetPaymentTermsNameAsync(pt, ct);
            dto.PaymentTermsGroupName = string.IsNullOrEmpty(name) ? null : name;
        }
    }

    private static string? Str(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String
            ? v.GetString()
            : null;

    private static int? Int(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetInt32()
            : null;

    private static decimal? Dec(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.Number
            ? v.GetDecimal()
            : null;

    private static DateTime? Dtm(JsonElement e, string prop) =>
        e.TryGetProperty(prop, out var v) && v.ValueKind == JsonValueKind.String
            && DateTime.TryParse(v.GetString(), CultureInfo.InvariantCulture,
                DateTimeStyles.RoundtripKind, out var dt)
            ? dt
            : null;
}
