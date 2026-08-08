using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SalesApp.Core.Interfaces
{
    public interface ISapServiceLayerClient
    {
        Task<string> GetAsync(string resourcePath, CancellationToken ct = default);
        Task<string> PostAsync(string resourcePath, object body, CancellationToken ct = default);
        Task<string> PatchAsync(string resourcePath, object body, CancellationToken ct = default);
    }
}
