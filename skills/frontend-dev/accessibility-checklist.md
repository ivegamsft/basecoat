# Accessibility Checklist — WCAG 2.1 AA

Use this checklist when building, reviewing, or auditing a UI component or page. Every item must pass before the feature ships. Mark each item: ✅ Pass, ❌ Fail (file a GitHub Issue), or N/A.

---

## 1. Perceivable

Information and UI components must be presentable to users in ways they can perceive.

### 1.1 Text Alternatives

- [ ] All non-text content (images, icons, charts) has a text alternative via `alt`, `aria-label`, or `aria-labelledby`.
- [ ] Decorative images use `alt=""` so screen readers skip them.
- [ ] Icons used as interactive controls have accessible names (not just a visual icon).
- [ ] Complex images (charts, diagrams) have a long description available (`longdesc`, adjacent prose, or `aria-describedby`).

### 1.2 Time-Based Media

- [ ] Prerecorded audio-only content has a text transcript.
- [ ] Prerecorded video-only content has a text or audio alternative.
- [ ] Prerecorded video with audio has synchronized captions.
- [ ] If audio plays automatically for more than 3 seconds, there is a mechanism to pause or stop it.

### 1.3 Adaptable

- [ ] Information and relationships conveyed through presentation are also programmatically determinable (not conveyed only through color or visual layout).
- [ ] Sequence of content in the DOM matches the visual reading order.
- [ ] Instructions do not rely solely on sensory characteristics (shape, color, position, sound) to identify content.
- [ ] Content does not restrict orientation (portrait/landscape) unless essential.

### 1.4 Distinguishable

- [ ] Color is not used as the sole visual means of conveying information, indicating an action, or distinguishing a visual element.
- [ ] Body text color contrast ratio is at least **4.5:1** against its background.
- [ ] Large text (18pt / 14pt bold or larger) color contrast ratio is at least **3:1**.
- [ ] UI components (inputs, buttons, focus indicators) have a contrast ratio of at least **3:1** against adjacent colors.
- [ ] Text can be resized to 200% without loss of content or functionality.
- [ ] No information is lost when text spacing is adjusted (line height 1.5×, letter spacing 0.12em, word spacing 0.16em, paragraph spacing 2em).
- [ ] Content does not require horizontal scrolling at 320px width (400% zoom equivalent).
- [ ] Background audio is at least 20 dB quieter than foreground speech, or can be turned off.

---

## 2. Operable

UI components and navigation must be operable.

### 2.1 Keyboard Accessible

- [ ] All functionality is operable via keyboard without requiring specific timing.
- [ ] No keyboard traps — focus can always move away from a component using standard keys.
- [ ] If a keyboard shortcut uses a single character, it can be turned off or remapped.

### 2.2 Enough Time

- [ ] If there is a time limit, users can turn it off, adjust it, or extend it (unless it is essential).
- [ ] Moving, blinking, or scrolling content that starts automatically and lasts more than 5 seconds can be paused, stopped, or hidden.
- [ ] Auto-updating content can be paused, stopped, or controlled by the user.

### 2.3 Seizures and Physical Reactions

- [ ] No content flashes more than three times per second.
- [ ] No general flash threshold or red flash threshold is exceeded.

### 2.4 Navigable

- [ ] Skip navigation links are provided so keyboard users can bypass repeated navigation blocks.
- [ ] Pages have a descriptive `<title>` element.
- [ ] Focus order follows a logical, meaningful sequence.
- [ ] The purpose of each link is clear from the link text alone, or from context.
- [ ] Multiple ways to find a page exist (search, site map, navigation).
- [ ] Headings and labels are descriptive.
- [ ] Keyboard focus is always visible — never set `outline: none` without a replacement focus style.

### 2.5 Input Modalities

- [ ] All functionality that uses a path-based gesture (drag, swipe) can also be operated with a single pointer.
- [ ] Pointer-activated functions can be cancelled (e.g., the up-event, not the down-event, triggers the action).
- [ ] Controls activated by motion (shaking, tilting) can also be activated through UI and can be disabled.
- [ ] Target size for pointer inputs is at least **24×24 CSS pixels**.

---

## 3. Understandable

Information and the operation of the UI must be understandable.

### 3.1 Readable

- [ ] `<html lang="...">` is set to the correct language of the page.
- [ ] Any passage in a different language is marked with `lang` on the element.

### 3.2 Predictable

- [ ] Changing focus does not automatically trigger a context change (e.g., navigating away from the page).
- [ ] Changing an input's value does not automatically submit the form or navigate.
- [ ] Navigation is consistent across pages of the same site.
- [ ] Components with the same function are identified consistently.

### 3.3 Input Assistance

- [ ] Input errors are identified automatically and described to the user in text.
- [ ] Labels or instructions are provided for inputs that require a specific format.
- [ ] Error messages suggest how to correct the input.
- [ ] For important actions (submit, delete, purchase), a review step, undo mechanism, or confirmation is provided.

---

## 4. Robust

Content must be robust enough that it can be interpreted by a wide variety of user agents, including assistive technologies.

### 4.1 Compatible

- [ ] HTML is valid — no duplicate IDs, no unclosed tags, no missing required attributes.
- [ ] All UI components have accessible names, roles, and values that are programmatically determinable.
- [ ] ARIA roles, states, and properties are used correctly according to the ARIA specification.
- [ ] Status messages (e.g., "3 items added to cart") are announced to assistive technologies via `role="status"` or `aria-live` without requiring focus.

---

## Filing an Accessibility Issue

When any item above fails, file a GitHub Issue immediately:

```bash
gh issue create \
  --title "[Accessibility] <short description>" \
  --label "tech-debt,frontend,accessibility" \
  --body "## Accessibility Failure

**WCAG Criterion:** <e.g., 1.4.3 Contrast (Minimum)>
**Level:** AA
**Component / Page:** <path or name>
**Line(s):** <optional>

### What Failed
<description of the specific failure>

### Impact
<who is affected and how — e.g., keyboard users cannot activate the submit button>

### Recommended Fix
<concise fix recommendation>

### Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>"
```
