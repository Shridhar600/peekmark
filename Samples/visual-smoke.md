# PeekMark Visual Smoke

This file covers the Markdown elements most likely to regress between Finder
Quick Look and Open With rendering.

## Bullets

- First bullet with **bold text**
- Second bullet with `inline code`
- Third bullet with a [local-looking link](./visual-smoke.md)

## Numbered Steps

1. Render the same HTML in Quick Look and Open With.
2. Keep ordered list numbering aligned.
3. Avoid duplicate bullets or duplicate numbers.

## Nested Lists

- Parent item
  - Child item
  - Another child item
- Parent item two

## Table

| Area | Expected |
| --- | --- |
| Quick Look | Rendered Markdown |
| Open With | Matching rendered Markdown |
| Theme | Plain light or dark |

## Quote

> Markdown preview should be readable without decorative cards or tinted chrome.

## Code

```swift
let app = "PeekMark"
print("Previewing \(app)")
```
