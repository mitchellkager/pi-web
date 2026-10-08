# Mobile and browser behavior

## Mobile software keyboard (`hooks/useViewportHeight.ts`)
- While an editor has focus and the visual viewport is more than `KEYBOARD_MIN_HEIGHT_PX` (60px) shorter than `innerHeight / scale`, the hook writes `visualViewport.height` to `--app-viewport-height`; smaller shrinks are Safari toolbars. Always compare against that zoom-corrected height, or iOS auto-zoom and pinch zoom leave the composer behind the keyboard.
- WebKit settles the shrunken height only after the keyboard animation, often without another `resize` (bugs.webkit.org 265578), and an IME candidate bar resizes the keyboard with no viewport event at all. So every trigger, composition/input/keyup events on a focused editor included, starts one non-restarting chain of re-reads (`SETTLE_DELAYS_MS`). Reading once per event keeps the full-screen height, and `scrollTo(0, 0)` then fights the page scrolling to the caret: a jittering composer.
- The same check sets `<html data-keyboard-open>`. Under `(max-width: 640px), (pointer: coarse) and (max-height: 500px)` (phone landscape included; tablets keep their controls) CSS hides `.chat-input-controls` and `.extension-status-shelf` and drops the bottom safe-area padding the keyboard covers. `MobilePwaLayout.test.mjs` asserts each targeted class exists on its component, so a rename cannot leave a rule silently dead.

## Completion sound
- `hooks/useAudio.ts` stores the toggle in `localStorage` as `pi-sound-enabled` and reuses one `AudioContext`.
- Autoplay policy requires unlocking sound from a user gesture: `ChatInput` calls the unlock hook from interactive controls, and `ChatWindow` plays the tone from `onAgentEnd`.

## Chat display preferences (`hooks/useChatAppearance.ts`)
- Content width, font size, and minimap visibility are browser-wide `localStorage` settings (`pi-chat-content-width`, `pi-chat-content-font-size`, `pi-chat-minimap-visible`) read once at mount and applied in `ChatWindow` / `ChatInput`.
- Minimap visibility defaults on; only an explicit `"0"`/`"false"` disables it. When off, `ChatWindow` renders no `ChatMinimap` and `ChatInput` drops the 52px right padding (16px) that clears the node column — both must stay in sync, so the hook exposes one `minimapVisible` used by both.
- The switch lives in General settings › Chat (`settings.chatMinimap`); the appearance section must not grow chat display controls (`SettingsPanel.test.mjs` counts the rows and switches).
