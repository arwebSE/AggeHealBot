# Local extra-button simulator

This is a separate development addon, excluded from AggeHealBot release packages.
It exercises the actual Identify buttons UI handler without extra mouse hardware.

Install this directory as `Interface/AddOns/AggeHealBotButtonTest`, then `/reload`.
If WoW does not discover the new addon after a reload, return to character
selection and log back in. Open it with `/ahbtest` or `/ahbtest 6`.

Press a quick-test button (6–11), or enter any number from 1 through 31 and press
Simulate button. Pick an optional modifier. The main AggeHealBot window selects
and highlights the simulated button; use its normal picker to assign a spell.
Stop identifying in the main window before continuing normal editing. Closing
the tester also stops capture, but keeps your detected buttons and saved bindings.

This tool does **not** emulate a real HID mouse or perform protected spell casts.
It cannot prove that a physical mouse sends Button 6 or that hardware click
routing works. Windows' standard SendInput mouse interface exposes only left,
right, middle and the two X buttons (buttons 4 and 5), so sending a real Button 6
is not an ordinary small input-injection app feature:

- https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-mouseinput
- https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-xbuttondown

The tester does not override global input APIs, install drivers or touch the
game process. It only calls the addon's UI-event handler when you press a test
button. Remove or disable this addon when finished testing.
