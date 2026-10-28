# Nemonic Flutter text-input compatibility

## Supported behavior

Flutter 3.47.8 adds TextInputClient.onFocusReceived. DeltaTextInputClient
implements that interface instead of inheriting its default method, so
DeltaTextInputService must implement the callback to compile with that SDK.
Both delta and non-delta services explicitly return false, matching Flutter's
default behavior. The callback does not claim to acquire focus or edit text.

The package keeps its Flutter 3.32.4 development/CI baseline, minimum SDK,
version 6.2.0, dependency ranges, document format, and existing IME patches.
The callback is absent from Flutter 3.32.4; only the method's old-SDK
`override_on_non_overriding_member` diagnostic is suppressed. The override
remains explicit on newer Flutter versions.

## Company maintenance line

This change targets nemonic-patch-6.2.0. Base commit
7fecd9d36280355a99f80079123605fe323fbdb4 has the same tree as Memo's previous
pin 501a3475bb55abd82e0561156c8308e67ccbb0d4. It does not include the separate
selection-geometry patch or the default main branch's unrelated changes.
Consumers should pin a reviewed fixed commit from this maintenance line.

Memo can then use this Git dependency directly and remove its app-local
AppFlowy package copy and path override. Its separate admin app must use
the same fixed AppFlowy commit.

## Verification

The missing callback was reproduced before changing the implementation.
The new focus tests check the active input connection, editing value
(including composing data), absence of edit callbacks, and absence of new
platform input calls. A populated separate composingTextRange field is not
exercised by the focus fixture; that remains additional coverage.

| SDK | Full tests | Analysis |
| --- | --- | --- |
| Flutter 3.32.4 | 915 passed | no issues |
| Flutter 3.47.8 / Dart 3.13.7 | 915 passed | no errors or warnings; 18 existing informational diagnostics |

Focused IME tests: 25 passed on the target SDK. Formatting of the changed
Dart files is checked with the repository's Flutter 3.32.4 formatter.

Commands, from the package root with the selected SDK:

```text
flutter pub get
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub test/editor/editor_component/ime --reporter expanded
```

Verification uses Memo's already resolved runtime dependency versions as
initial lock input, including image 4.9.2 and archive 4.0.9. An unconstrained
offline install instead selected image 4.11.0 with archive 4.0.9, which fails
on a missing ZLibDecoder.decodeLazy method independently of this patch.
No dependency pin or range change is included here. Package lockfiles are
not tracked in this repository.

These local checks do not prove physical keyboard/IME behavior on every
platform. Memo previously validated the same return-false implementation
in its local compatibility copy; the newly fixed Git reference still needs
consumer validation before release.
