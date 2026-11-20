# fade_in_batch.dart

**Purpose:** Animates newly appended list items with a gentle entrance fade transition.

**How it works:** Compares each card index against the latest batch threshold to trigger an AnimationController forward transition while respecting reduced-motion preferences.

**Key components:** `FadeInBatch`, `_FadeInBatchState`
