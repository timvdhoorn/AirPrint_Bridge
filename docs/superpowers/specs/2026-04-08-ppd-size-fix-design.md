# Fix paper size in airprint_bridge.sh

## Problem

Two bugs in `airprint_bridge.sh`:

1. **URF record says 100x150mm** — line 439 hardcodes `MS_CUSTOM_100x150mm` in the URF TXT record, but the actual label size is 100x40mm (correctly defined on lines 38-41 as 284x114 pt).

2. **iOS shows all paper formats** — the `strip_ppd_to_custom_size()` function replaces `*CustomPageSize True:` with `*CustomPageSize False:`, but iOS ignores this and still offers arbitrary sizes. The awk size-replacement logic itself works correctly (verified on `TestFixtures/sample_ppd_zebra.ppd`).

## Changes

### Fix 1: URF string (line 439)

Change `MS_CUSTOM_100x150mm` to use the `CUSTOM_LABEL` variable:

```bash
# Before
add_urf_code "MS_CUSTOM_100x150mm"

# After
add_urf_code "MS_CUSTOM_${CUSTOM_LABEL}mm"
```

This makes the URF record consistent with the configured label size.

### Fix 2: Remove CustomPageSize entirely from PPD

In the awk script inside `strip_ppd_to_custom_size()`:

- **Delete** the `*CustomPageSize` line entirely instead of changing `True` to `False`
- **Delete** `*ParamCustomPageSize` lines (already done)
- **Add** `*MaxMediaWidth` and `*MaxMediaHeight` constraints based on the custom size, preventing iOS from offering larger formats

```bash
# Before
/^\*CustomPageSize True:/ { print "*CustomPageSize False: ..."; next }

# After
/^\*CustomPageSize/ { next }  # Remove entirely
```

Add max media constraints after the PaperDimension section:

```
*MaxMediaWidth: "284"
*MaxMediaHeight: "114"
```

## Files affected

- `airprint_bridge.sh` — both fixes

## Testing

1. Run `sudo ./airprint_bridge.sh -t`
2. Verify terminal output shows `MS_CUSTOM_100x40mm` in URF
3. Check stripped PPD: no `*CustomPageSize` line, `*MaxMediaWidth`/`*MaxMediaHeight` present
4. On iOS: printer should only show 100x40mm
