# catalogue_store.dart

**Purpose:** Defines the storage contract and implementations for caching font catalogue JSON payloads.

**How it works:** Persists the last-used sort response in SharedPreferences to provide immediate warm-start presentation while enabling background revalidation.

**Key components:** `CatalogueStore`, `MemoryCatalogueStore`, `SharedPreferencesCatalogueStore`
