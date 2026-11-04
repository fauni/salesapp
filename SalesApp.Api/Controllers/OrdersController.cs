using System.Globalization;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SalesApp.Api.DTOs;
using SalesApp.Core.Exceptions;
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
    private readonly IAllowedWarehouses _allowedWarehouses;

    // Same field set for Orders and Drafts (Drafts mirror the document schema).
    // PaymentGroupCode is the payment-terms group — defaults from the customer
    // but can be overridden on create (CreateOrderRequest.PaymentTermsGroupCode);
    // surfaced (as a name) in the order detail either way. (Price list is not a
    // valid document-header field in this SAP version, so it's not selected.)
    // U_SL_UsuarioApp is our own UDF (set on create, see BuildOrderBody) holding
    // the SalesApp username that created the order — used to scope "my orders".
    private const string OrderSelect =
        "DocEntry,DocNum,CardCode,CardName,DocDate,DocDueDate,SalesPersonCode,Series,"
        + "Comments,DocTotal,PaymentGroupCode,U_SL_UsuarioApp,DocumentLines";

    // SAP BoObjectTypes value for a Sales Order (used to filter Drafts).
    private const string SalesOrderObjectCode = "17";

    public OrdersController(
        ISapServiceLayerClient sapClient,
        ICatalogResolverService catalogResolver,
        IAllowedWarehouses allowedWarehouses)
    {
        _sapClient = sapClient;
        _catalogResolver = catalogResolver;
        _allowedWarehouses = allowedWarehouses;
    }

    // POST /api/orders  (RF-06..RF-10)
    [HttpPost]
    public async Task<ActionResult<OrderDto>> Create(CreateOrderRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.CustomerCode))
            return BadRequest(new { message = "CustomerCode is required." });
        if (request.Lines.Count == 0)
            return BadRequest(new { message = "An order needs at least one line." });
        if (!PickupByValues.IsValid(request.PickupBy))
            return BadRequest(new { message = "PickupBy is required: C, V or T." });
        if (!await IsCustomerAllowedAsync(request.CustomerCode, ct))
            return BadRequest(new { message = "Customer not allowed." });

        var warehouseError = await ValidateWarehousesAsync(request.Lines, ct);
        if (warehouseError != null) return BadRequest(new { message = warehouseError });

        // NOTE: no credit-limit check here — intentionally out of scope.
        // SAP validation errors surface via SapExceptionFilter (400/502).
        var created = await CreateInSapAsync(request, ct);
        return CreatedResult(created);
    }

    // GET /api/orders?status=pending|approved|rejected  (RF-12)
    [HttpGet]
    public async Task<ActionResult<IEnumerable<OrderDto>>> List(
        [FromQuery] string? status, CancellationToken ct)
    {
        status = (status ?? OrderStatus.Approved).Trim().ToLowerInvariant();

        // The tab is decided by the SAP approval request of each draft
        // (ApprovalRequests.Status), not by the draft itself:
        //   pending  -> drafts awaiting authorization      (arsPending)
        //   rejected -> drafts rejected by the authorizer  (arsNotApproved)
        //   approved -> drafts authorized but not yet turned into an Order
        //               (arsApproved, IsDraft = true — "Generar orden" in the app)
        //               followed by the real SAP Orders.
        // Drafts already converted (arsGenerated) appear only as their Order.
        switch (status)
        {
            case OrderStatus.Pending:
                return Ok(await ListDraftsByApprovalAsync(ApprovalPending, status, ct));

            case OrderStatus.Rejected:
                return Ok(await ListDraftsByApprovalAsync(ApprovalRejected, status, ct));

            case OrderStatus.Approved:
                var toGenerate = await ListDraftsByApprovalAsync(ApprovalApproved, status, ct);
                var orders = await ListOrdersAsync(ct);
                return Ok(toGenerate.Concat(orders));

            default:
                return BadRequest(new { message = "status must be pending, approved or rejected." });
        }
    }

    // GET /api/orders/{id}?status=pending|approved|rejected[&draft=true|false]
    // Approved orders live in SAP's `Orders`; pending/rejected are `Drafts`.
    // The caller (order list) already knows the status, so it tells us which
    // entity to read — otherwise a draft id would 404 against Orders. An
    // approved-but-not-generated draft is status=approved&draft=true.
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDto>> GetById(
        int id, [FromQuery] string? status, [FromQuery] bool? draft, CancellationToken ct)
    {
        var normalized = (status ?? OrderStatus.Approved).Trim().ToLowerInvariant();
        var isDraft = draft ?? normalized is OrderStatus.Pending or OrderStatus.Rejected;
        var entity = isDraft ? "Drafts" : "Orders";
        var displayStatus = normalized is OrderStatus.Pending or OrderStatus.Rejected
            ? normalized
            : OrderStatus.Approved;

        var json = await _sapClient.GetAsync($"{entity}({id})?$select={OrderSelect}", ct);
        using var doc = JsonDocument.Parse(json);
        var dto = MapOrder(doc.RootElement, displayStatus, isDraft);
        if (!IsOwnedByCaller(dto)) return OrderNotFound();
        await ResolveNamesAsync(dto, ct);
        return Ok(dto);
    }

    // POST /api/orders/{id}/generate — {id} = DocEntry of a DRAFT.
    // Turns a draft that SAP ALREADY AUTHORIZED into the real Sales Order: the
    // same as pressing "Add" on the approved draft in SAP. This is NOT an
    // approval (SAP still owns that): drafts whose approval request isn't
    // arsApproved are refused.
    [HttpPost("{id:int}/generate")]
    public async Task<ActionResult<OrderDto>> Generate(int id, CancellationToken ct)
    {
        OrderDto draft;
        string docObjectCode;
        var draftJson = await _sapClient.GetAsync(
            $"Drafts({id})?$select={OrderSelect},DocObjectCode", ct);
        using (var draftDoc = JsonDocument.Parse(draftJson))
        {
            draft = MapOrder(draftDoc.RootElement, OrderStatus.Approved, isDraft: true);
            // SaveDraftToDocument needs the draft's document type too, or SAP
            // fails with -5001 "Object type for draft is missing". Echo back
            // exactly what SAP returned (e.g. "oOrders").
            docObjectCode = Str(draftDoc.RootElement, "DocObjectCode") ?? "oOrders";
        }

        // Same ownership rule as the lists: users act only on their own orders.
        if (!IsOwnedByCaller(draft)) return OrderNotFound();

        var approved = await DraftEntriesByApprovalAsync(ApprovalApproved, ct);
        if (!approved.Contains(id))
            return BadRequest(new { message = "This order is not authorized in SAP, or it was already generated." });

        // Returns 204 (no body) — the new Order is looked up below. Service
        // Layer services are root-level actions ("DraftsService_..."), NOT
        // nested under the entity set: "Drafts/DraftsService_..." is accepted
        // but fails with -5001 "Object type for draft is missing".
        await _sapClient.PostAsync("DraftsService_SaveDraftToDocument",
            new { Document = new { DocEntry = id, DocObjectCode = docObjectCode } }, ct);

        // Exact lookup via the approval request (ObjectEntry = new Order);
        // newest-order-for-customer only as a fallback.
        OrderDto? created = null;
        if (await GeneratedOrderEntryAsync(id, ct) is int orderEntry)
        {
            try
            {
                var orderJson = await _sapClient.GetAsync($"Orders({orderEntry})?$select={OrderSelect}", ct);
                using var orderDoc = JsonDocument.Parse(orderJson);
                created = MapOrder(orderDoc.RootElement, OrderStatus.Approved);
            }
            catch (SapException) { /* fall through to the fallback below */ }
        }
        created ??= await FindNewestAsync("Orders", draft.CustomerCode, draft.CreatedByAppUser,
                        OrderStatus.Approved, isDraft: false, ct)
                    // Generated but not found (shouldn't happen): still a success;
                    // the app just refreshes the list.
                    ?? new OrderDto { CustomerCode = draft.CustomerCode, Status = OrderStatus.Approved };
        return CreatedResult(created);
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

    // POST /api/orders/{id}/close — closes an already-approved SAP Order (all
    // lines -> bost_Close). Not reversible from the app. Only valid for Orders
    // (approved) — Drafts don't support this SAP action.
    [HttpPost("{id:int}/close")]
    public async Task<ActionResult<OrderDto>> Close(int id, CancellationToken ct)
    {
        // Ownership check BEFORE closing — the close itself is irreversible.
        var ownerJson = await _sapClient.GetAsync($"Orders({id})?$select=DocEntry,U_SL_UsuarioApp", ct);
        using (var ownerDoc = JsonDocument.Parse(ownerJson))
        {
            if (!IsOwnedByCaller(MapOrder(ownerDoc.RootElement, OrderStatus.Approved)))
                return OrderNotFound();
        }

        await _sapClient.PostAsync($"Orders({id})/Close", new { }, ct);

        var json = await _sapClient.GetAsync($"Orders({id})?$select={OrderSelect}", ct);
        using var doc = JsonDocument.Parse(json);
        var dto = MapOrder(doc.RootElement, OrderStatus.Approved);
        await ResolveNamesAsync(dto, ct);
        return Ok(dto);
    }

    // POST /api/orders/{id}/duplicate  (RF-15)
    [HttpPost("{id:int}/duplicate")]
    public async Task<ActionResult<OrderDto>> Duplicate(int id, CancellationToken ct)
    {
        var srcJson = await _sapClient.GetAsync($"Orders({id})?$select={OrderSelect}", ct);
        OrderDto source;
        using (var srcDoc = JsonDocument.Parse(srcJson))
            source = MapOrder(srcDoc.RootElement, OrderStatus.Approved);
        if (!IsOwnedByCaller(source)) return OrderNotFound();
        // The customer may have been reassigned to another salesperson since.
        if (!await IsCustomerAllowedAsync(source.CustomerCode, ct))
            return BadRequest(new { message = "Customer not allowed." });

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
                QuantityInLiters = l.QuantityInLiters,
                WarehouseCode = l.WarehouseCode,
                ProjectCode = l.ProjectCode,
                BranchCode = l.BranchCode
            }).ToList()
        };

        // The source order may use a warehouse that has since been disallowed.
        var warehouseError = await ValidateWarehousesAsync(clone.Lines, ct);
        if (warehouseError != null) return BadRequest(new { message = warehouseError });

        var created = await CreateInSapAsync(clone, ct);
        return CreatedResult(created);
    }

    // --- helpers ---

    // Lines may only use globally allowed warehouses (AllowedWarehouses table).
    // A line without a warehouse is left to SAP's default. Returns the error
    // message, or null if every line is fine.
    private async Task<string?> ValidateWarehousesAsync(
        IEnumerable<CreateOrderLineRequest> lines, CancellationToken ct)
    {
        var allowed = await _allowedWarehouses.GetCodesAsync(ct);
        var invalid = lines
            .Select(l => l.WarehouseCode)
            .Where(code => !string.IsNullOrWhiteSpace(code) && !allowed.Contains(code))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return invalid.Count == 0
            ? null
            : $"Warehouse not allowed: {string.Join(", ", invalid)}.";
    }

    // Reps may only order for their own customers (see CustomerScope) — checked
    // here too, not just in the customer list, since the code could be typed
    // in by hand. Administrators skip the SAP lookup.
    private async Task<bool> IsCustomerAllowedAsync(string customerCode, CancellationToken ct)
    {
        var scope = CustomerScope.For(User);
        if (scope.All) return true;
        if (scope.None) return false;

        var key = Uri.EscapeDataString(customerCode.Replace("'", "''"));
        var json = await _sapClient.GetAsync(
            $"BusinessPartners('{key}')?$select=CardCode,SalesPersonCode", ct);
        using var doc = JsonDocument.Parse(json);
        return scope.Allows(Int(doc.RootElement, "SalesPersonCode"));
    }

    // SAP error code Service Layer returns when an Approval Procedure turned
    // the new Order into a Draft: the draft IS created, but SL then tries to
    // read the new document back from Orders, finds nothing and fails with
    // {"error":{"code":-2028,"message":{"value":"No matching records found (ODBC -2028)"}}}.
    private const int SapApprovalDraftCreatedCode = -2028;

    // POSTs the order. Normal case: SAP returns the created Order (approved).
    // Approval case: -2028 means "created as a Draft, pending authorization" —
    // a SUCCESS for us, never an error, or the rep would resubmit and create a
    // duplicate draft. We then look up that draft to return its numbers.
    private async Task<OrderDto> CreateInSapAsync(CreateOrderRequest request, CancellationToken ct)
    {
        try
        {
            var json = await _sapClient.PostAsync("Orders", BuildOrderBody(request), ct);
            using var doc = JsonDocument.Parse(json);
            return MapOrder(doc.RootElement, OrderStatus.Approved);
        }
        catch (SapException ex) when (IsApprovalDraftCreated(ex))
        {
            return await FindNewestAsync("Drafts", request.CustomerCode, User.Identity?.Name,
                       OrderStatus.Pending, isDraft: true, ct)
                   // Draft not found (shouldn't happen): still report success
                   // as pending, without an id — the app falls back to the list.
                   ?? new OrderDto { CustomerCode = request.CustomerCode, Status = OrderStatus.Pending };
        }
    }

    private static bool IsApprovalDraftCreated(SapException ex)
    {
        if (ex.StatusCode != StatusCodes.Status404NotFound) return false;
        try
        {
            using var doc = JsonDocument.Parse(ex.ResponseBody);
            return doc.RootElement.TryGetProperty("error", out var err)
                   && err.TryGetProperty("code", out var code)
                   && code.ValueKind == JsonValueKind.Number
                   && code.TryGetInt32(out var c)
                   && c == SapApprovalDraftCreatedCode;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    // Newest sales order (entity "Orders") or sales-order draft ("Drafts") of
    // this app user for this customer — the one just created by a POST (a rep
    // doesn't submit two orders for the same customer in the same instant).
    // Best-effort: a lookup failure must not turn a successful creation into
    // an error.
    private async Task<OrderDto?> FindNewestAsync(
        string entity, string customerCode, string? appUsername,
        string status, bool isDraft, CancellationToken ct)
    {
        var filters = new List<string> { $"CardCode eq '{customerCode.Replace("'", "''")}'" };
        if (isDraft)
            filters.Add($"DocObjectCode eq '{SalesOrderObjectCode}'");
        if (!string.IsNullOrWhiteSpace(appUsername))
            filters.Add($"U_SL_UsuarioApp eq '{appUsername.Replace("'", "''")}'");

        var query = $"{entity}?$select={OrderSelect}&$orderby=DocEntry desc&$top=1"
                    + $"&$filter={Uri.EscapeDataString(string.Join(" and ", filters))}";
        try
        {
            var json = await _sapClient.GetAsync(query, ct);
            using var doc = JsonDocument.Parse(json);
            var first = doc.RootElement.GetProperty("value").EnumerateArray().FirstOrDefault();
            return first.ValueKind == JsonValueKind.Object
                ? MapOrder(first, status, isDraft)
                : null;
        }
        catch (SapException)
        {
            return null;
        }
    }

    // SAP approval request statuses (ApprovalRequests.Status) we map to tabs.
    // arsGenerated (draft already turned into an Order) and arsCancelled are
    // deliberately not listed as drafts.
    private const string ApprovalPending = "arsPending";
    private const string ApprovalApproved = "arsApproved";
    private const string ApprovalRejected = "arsNotApproved";

    // DocEntry of every draft whose approval request has the given status AND
    // is still a draft. Verified against the client's SAP: generating the
    // Order from an approved draft does NOT change Status (stays arsApproved);
    // instead the request flips IsDraft 'Y' -> 'N' and ObjectEntry gets the new
    // Order's DocEntry (and the draft itself becomes DocumentStatus bost_Close).
    // Filtering IsDraft in the query (not in memory) matters: generated
    // requests stay arsApproved forever and would otherwise crowd the page.
    // Not filtered by document type — the Drafts query that consumes these
    // entries already restricts to sales orders (draft DocEntries are unique
    // across document types).
    // NOTE: Service Layer pages at 20 rows by default (see ItemsController), so
    // this sees the 20 newest requests in that status — enough for in-flight
    // approvals; old rejections beyond that drop off the Rejected tab.
    private async Task<HashSet<int>> DraftEntriesByApprovalAsync(string approvalStatus, CancellationToken ct)
    {
        var filter = $"Status eq '{approvalStatus}' and IsDraft eq 'Y'";
        var query = "ApprovalRequests?$select=Code,DraftEntry&$orderby=Code desc"
                    + $"&$filter={Uri.EscapeDataString(filter)}";
        var json = await _sapClient.GetAsync(query, ct);
        using var doc = JsonDocument.Parse(json);

        var entries = new HashSet<int>();
        foreach (var r in doc.RootElement.GetProperty("value").EnumerateArray())
        {
            if (Int(r, "DraftEntry") is int entry and > 0)
                entries.Add(entry);
        }
        return entries;
    }

    // DocEntry of the Order generated from a draft (ApprovalRequests.ObjectEntry
    // once IsDraft is 'N'), or null if not generated / not found.
    private async Task<int?> GeneratedOrderEntryAsync(int draftEntry, CancellationToken ct)
    {
        var query = "ApprovalRequests?$select=Code,IsDraft,ObjectEntry"
                    + $"&$filter={Uri.EscapeDataString($"DraftEntry eq {draftEntry}")}";
        try
        {
            var json = await _sapClient.GetAsync(query, ct);
            using var doc = JsonDocument.Parse(json);
            foreach (var r in doc.RootElement.GetProperty("value").EnumerateArray())
            {
                if (Str(r, "IsDraft") == "N" && Int(r, "ObjectEntry") is int entry and > 0)
                    return entry;
            }
        }
        catch (SapException)
        {
            // Best-effort — caller falls back to FindNewestAsync.
        }
        return null;
    }

    // Sales-order drafts (scoped to the caller like every list) whose approval
    // request is in the given status.
    private async Task<List<OrderDto>> ListDraftsByApprovalAsync(
        string approvalStatus, string displayStatus, CancellationToken ct)
    {
        var entries = await DraftEntriesByApprovalAsync(approvalStatus, ct);
        if (entries.Count == 0) return new List<OrderDto>();

        var filters = new List<string>
        {
            $"DocObjectCode eq '{SalesOrderObjectCode}'",
            // Belt and braces with IsDraft above: a generated draft is closed.
            "DocumentStatus eq 'bost_Open'",
            "(" + string.Join(" or ", entries.Select(e => $"DocEntry eq {e}")) + ")"
        };
        var ownerFilter = BuildAppUserFilter();
        if (ownerFilter != null) filters.Add(ownerFilter);

        var query = $"Drafts?$select={OrderSelect}&$orderby=DocEntry desc"
                    + $"&$filter={Uri.EscapeDataString(string.Join(" and ", filters))}";
        var json = await _sapClient.GetAsync(query, ct);
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(e => MapOrder(e, displayStatus, isDraft: true))
            .ToList();
    }

    private async Task<List<OrderDto>> ListOrdersAsync(CancellationToken ct)
    {
        var query = $"Orders?$select={OrderSelect}&$orderby=DocDate desc&$top=50";
        var ownerFilter = BuildAppUserFilter();
        if (ownerFilter != null)
            query += $"&$filter={Uri.EscapeDataString(ownerFilter)}";

        var json = await _sapClient.GetAsync(query, ct);
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("value")
            .EnumerateArray()
            .Select(e => MapOrder(e, OrderStatus.Approved))
            .ToList();
    }

    // 201 pointing at the right entity: drafts need ?status=&draft=true so
    // GetById reads Drafts instead of Orders.
    private ActionResult<OrderDto> CreatedResult(OrderDto created)
    {
        if (created.Id == 0)
            return StatusCode(StatusCodes.Status201Created, created);
        return created.IsDraft
            ? CreatedAtAction(nameof(GetById),
                new { id = created.Id, status = created.Status, draft = true }, created)
            : CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

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
            // Custom SAP field (UDF on order rows): liters entered by the rep for
            // items sold by liters. Quantity already holds liters / InventoryWeight.
            if (l.QuantityInLiters.HasValue)
                line["U_TF_CANTLT"] = l.QuantityInLiters.Value;
            // The rep enters the gross (VAT-inclusive) unit price. In SAP that is
            // the line's "price after VAT" — DB field RDR1.PriceAfVAT, exposed by
            // the Service Layer as PriceAfterVAT. SAP back-calculates the net
            // UnitPrice from it. (Setting UnitPrice instead is wrong when the
            // document works with gross prices — SAP overwrites it.)
            if (l.UnitPrice.HasValue)
            {
                line["PriceAfterVAT"] = l.UnitPrice.Value;
                // The price's own currency. Omitted, SAP takes the number in
                // the document currency (the customer's) — e.g. a 10 USD list
                // price saved as 10 Bs. With it, SAP converts at the day's
                // exchange rate (which must exist in SAP for that currency).
                if (!string.IsNullOrWhiteSpace(l.Currency))
                    line["Currency"] = l.Currency.Trim();
            }
            if (!string.IsNullOrWhiteSpace(l.WarehouseCode))
                line["WarehouseCode"] = l.WarehouseCode;
            if (!string.IsNullOrWhiteSpace(l.ProjectCode))
                line["ProjectCode"] = l.ProjectCode;
            // "Sucursal" — 2nd distribution-rule dimension on the line.
            if (!string.IsNullOrWhiteSpace(l.BranchCode))
                line["CostingCode2"] = l.BranchCode;
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
        // Omitted => SAP inherits the customer's own payment terms group.
        if (request.PaymentTermsGroupCode.HasValue)
            body["PaymentGroupCode"] = request.PaymentTermsGroupCode.Value;

        // Custom SAP field (UDF on Orders): the SalesApp username that created
        // the order, from the JWT — not the SAP user. Set on every create,
        // including "Duplicar pedido" (the current caller, not the source
        // order's original creator).
        var appUsername = User.Identity?.Name;
        if (!string.IsNullOrWhiteSpace(appUsername))
            body["U_SL_UsuarioApp"] = appUsername;

        // Custom SAP field (UDF on Orders): device GPS fix captured at submit
        // time, as "lat,long". Best-effort on the app side — omitted entirely
        // when unavailable (denied permission, GPS off, timeout), never blocks
        // order creation. InvariantCulture is required: a server locale using
        // a comma as decimal separator would otherwise corrupt the "lat,long"
        // format (e.g. "-17,78" instead of "-17.78").
        if (request.Latitude.HasValue && request.Longitude.HasValue)
        {
            body["U_SL_Ubicacion"] = string.Format(CultureInfo.InvariantCulture,
                "{0},{1}", request.Latitude.Value, request.Longitude.Value);
        }

        // Custom SAP field (UDF on Orders): who picks the order up (C/V/T).
        // Required on create (validated in Create); "Duplicar pedido" doesn't
        // carry it, so it's omitted there.
        if (!string.IsNullOrWhiteSpace(request.PickupBy))
            body["U_SL_Recoge"] = request.PickupBy;

        return body;
    }

    // Reps only see/act on the orders THEY created in the app (by app username,
    // U_SL_UsuarioApp — not by SalesPersonCode, which can be shared across
    // app users); Administrators see and act on everything. Null = no filter.
    private string? BuildAppUserFilter()
    {
        if (User.IsInRole("Administrator")) return null;
        // A JWT always carries the username; if it somehow doesn't, match
        // nothing rather than everything.
        var username = User.Identity?.Name ?? string.Empty;
        // Escape single quotes for the OData literal (SAP's own escaping rule:
        // a literal quote is written as two quotes).
        var escaped = username.Replace("'", "''");
        return $"U_SL_UsuarioApp eq '{escaped}'";
    }

    // Single-order counterpart of BuildAppUserFilter.
    private bool IsOwnedByCaller(OrderDto order)
    {
        if (User.IsInRole("Administrator")) return true;
        var username = User.Identity?.Name;
        return !string.IsNullOrWhiteSpace(username)
               && string.Equals(order.CreatedByAppUser, username, StringComparison.OrdinalIgnoreCase);
    }

    // 404 (not 403) for someone else's order: don't reveal that it exists.
    private NotFoundObjectResult OrderNotFound() =>
        NotFound(new { message = "Order not found." });

    private int? CurrentSalesPersonCode() =>
        int.TryParse(User.FindFirst("salesEmployeeCode")?.Value, out var code) ? code : null;

    private static OrderDto MapOrder(JsonElement e, string status, bool isDraft = false)
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
            CreatedByAppUser = Str(e, "U_SL_UsuarioApp"),
            Status = status,
            IsDraft = isDraft
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
                    // UDF defaults to 0 on lines that never set it — treat as "none".
                    QuantityInLiters = Dec(l, "U_TF_CANTLT") is > 0 and var liters ? liters : null,
                    // Surface the gross (VAT-inclusive) price the rep entered —
                    // SAP's PriceAfterVAT — falling back to the net UnitPrice.
                    UnitPrice = Dec(l, "PriceAfterVAT") ?? Dec(l, "UnitPrice"),
                    Currency = Str(l, "Currency"),
                    LineTotal = Dec(l, "LineTotal") ?? 0m,
                    WarehouseCode = Str(l, "WarehouseCode"),
                    ProjectCode = Str(l, "ProjectCode"),
                    BranchCode = Str(l, "CostingCode2"),
                    IsClosed = Str(l, "LineStatus") == "bost_Close"
                });
            }
        }

        // The order is closed only once every line was closed via POST .../Close.
        dto.IsClosed = dto.Lines.Count > 0 && dto.Lines.All(l => l.IsClosed);

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
