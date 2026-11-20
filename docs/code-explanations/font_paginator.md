# font_paginator.dart

**Purpose:** Manages incremental client-side windowing and batch pagination over an in-memory font catalogue.

**How it works:** Maintains a visible count cursor that reveals items in fixed-size batches as the user scrolls, without re-requesting the API.

**Key components:** `FontPaginator`, `loadNextPage`, `reset`, `visibleItems`, `hasMore`
