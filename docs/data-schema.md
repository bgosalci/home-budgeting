# Home Budgeting Data Schema

All three platform implementations (web, Android, and iOS) persist data using the same JSON structure so data exported from one platform can be imported into another without transformation. The root payload mirrors the historical web storage contract that lives under the `budget.local.v1` key in browser storage.

## Root Object

The root object has the following shape:

```json
{
  "version": 1,
  "months": {
    "2024-01": {
      "incomes": [],
      "transactions": [],
      "categories": {}
    }
  },
  "mapping": {
    "exact": {},
    "tokens": {}
  },
  "descMap": {
    "exact": {},
    "tokens": {}
  },
  "ui": {
    "collapsed": {}
  },
  "descList": [],
  "notes": []
}
```

Field descriptions:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `version` | `number` | Schema version. Currently `1` for backwards compatibility with the web app. |
| `months` | `object` | Dictionary of month keys (`YYYY-MM`) mapped to [`BudgetMonth`](#budgetmonth) payloads. |
| `mapping` | `object` | Learnt category prediction map with `exact` (description keys) and `tokens` (word token keys). Mirrors `store.mapping` in the web implementation. |
| `descMap` | `object` | Learnt description prediction map keyed by category. `exact` stores description frequency, `tokens` stores per-word counts. |
| `ui` | `object` | Stores presentation preferences. Currently used only for storing collapsed category groups with the structure `{ collapsed: { [monthKey]: { [groupName]: boolean } } }`. |
| `descList` | `array` | Ordered list of known descriptions used for autocomplete suggestions. |
| `notes` | `array` | Global notes array containing [`Note`](#note) entries. |

## `BudgetMonth`

Each month contains:

| Field | Type | Notes |
| ----- | ---- | ----- |
| `incomes` | `array` | List of [`Income`](#income) items. |
| `transactions` | `array` | List of [`Transaction`](#transaction) items. |
| `categories` | `object` | Dictionary keyed by category name storing [`Category`](#category) metadata. |

### `Income`

```json
{
  "id": "sr4jz9s",
  "name": "Salary",
  "amount": 3200.0
}
```

| Field | Type | Notes |
| ----- | ---- | ----- |
| `id` | `string` | Unique identifier. |
| `name` | `string` | Source of the income. |
| `amount` | `number` | Amount stored as a positive decimal. |

### `Category`

```json
"Groceries": {
  "group": "Food",
  "budget": 320.0
}
```

| Field | Type | Notes |
| ----- | ---- | ----- |
| `group` | `string` | Category group label. |
| `budget` | `number` | Planned spend for the category. |

### `Transaction`

```json
{
  "id": "tx-102",
  "date": "2024-01-18",
  "desc": "Waitrose",
  "amount": 42.55,
  "category": "Groceries"
}
```

| Field | Type | Notes |
| ----- | ---- | ----- |
| `id` | `string` | Unique identifier. |
| `date` | `string` | ISO `YYYY-MM-DD` date. |
| `desc` | `string` | Transaction description. |
| `amount` | `number` | Positive numbers represent spend. Refunds or credits use negative values. |
| `category` | `string` | Category name linking back to the `categories` dictionary. |

### `Note`

```json
{
  "id": 1715442342342,
  "desc": "Holiday",
  "data": "Book flights",
  "time": 1715442342342
}
```

| Field | Type | Notes |
| ----- | ---- | ----- |
| `id` | `number` | Millisecond timestamp identifier. |
| `desc` | `string` | Short label describing the note. |
| `data` | `string` | Body content for the note. |
| `time` | `number` | Millisecond timestamp when the note was last updated. |

## Import/Export Expectations

* The entire object is persisted as JSON. Platforms load the document on startup and write it back to disk when data changes.
* Partial exports follow the same structures used by the web app today:
  * `transactions`: array of [`Transaction`](#transaction) for a specific month.
  * `categories`: object with a single `categories` dictionary mirroring the month payload.
  * `prediction`: object containing `mapping`, `descMap`, and `descList`.
  * `all`: the full root object.
* New keys must be optional to keep backwards compatibility with existing saves. Mobile apps ignore unknown keys and preserve them on write.

The Android and iOS implementations both serialize their native model types to this schema so users can seamlessly move data between devices.
