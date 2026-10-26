---
name: react-native-expo
description: Builds and reviews React Native apps on Expo - secure storage, biometrics, certificate pinning, root and jailbreak detection, WebSocket reconnect, OTA update policy and the store release flow. Use when writing or reviewing mobile app code, its native configuration (app.json, app.config, eas.json), or a mobile release. Not for web front ends (frontend-ui-engineering).
---

# React Native with Expo

## Overview

A mobile app runs on a device you do not control, on networks that drop, and ships through stores that
take days to review. Keep secrets off the device where possible and in the platform keystore otherwise,
treat client-side checks as signals, survive reconnects, and make every release reversible.

## Project

- Pin the Expo SDK; add native dependencies with `npx expo install` so versions match the SDK.
- Change native configuration through config plugins (Continuous Native Generation), not by hand-editing
  `ios/` and `android/`. If the project is bare, say so in the README.
- EAS Build profiles for development, preview and production in `eas.json`.

## Secure Storage

- Tokens and credentials go in `expo-secure-store` (Keychain and Keystore), with
  `keychainAccessible: WHEN_UNLOCKED_THIS_DEVICE_ONLY`. Never in AsyncStorage or unencrypted storage.
- Clear them on logout. Variables prefixed `EXPO_PUBLIC_` are compiled into the bundle and are public;
  real secrets stay on the server.

## Biometrics

- `expo-local-authentication` is a local gate, not server authentication. Use it to unlock a token stored
  with `requireAuthentication: true` in SecureStore.
- Handle a changed biometric enrolment by invalidating the protected token.
- Never send "biometric check passed" to the server as proof of anything.

## Certificate Pinning

- Expo does not pin certificates by default; add it through a config plugin or a native module.
- Pin public-key (SPKI) hashes, with at least one backup pin, and plan the rotation before the certificate
  expires.
- A pinning failure is a hard failure that is reported. Test it: through an intercepting proxy, requests
  must fail.

## Root and Jailbreak Detection

- A signal, not a guarantee; it can be bypassed.
- Combine it with server-side device attestation (Play Integrity, App Attest or DeviceCheck), and decide per
  action whether to warn, restrict or block.

## WebSocket Reconnect

- One connection manager per socket; no duplicates.
- Exponential backoff with jitter and a cap; reconnect when the app returns to the foreground (`AppState`)
  and when connectivity returns (NetInfo).
- Heartbeats with a timeout to detect half-open sockets. Refresh the auth token before reconnecting.
- After reconnecting, resubscribe and resynchronise: snapshot plus deltas, checked by sequence number.

## OTA Updates

- EAS Update ships JavaScript and assets only; native changes need a store build. Tie `runtimeVersion` to
  the native fingerprint so an update never reaches an incompatible binary.
- One channel per environment, staged rollouts by percentage, and a rollback (republish the previous
  update). Sign updates with code signing.
- Stay within store rules for what an OTA update may change. For a security fix that cannot wait, enforce a
  minimum app version from the server.

## Store Release Flow

- Bump `version` and the build number (`buildNumber`, `versionCode`); build with
  `eas build --profile production`.
- Internal track or TestFlight first; release notes; the iOS privacy manifest and the Play data-safety form
  match what the app collects.
- `eas submit`, then a phased release with crash monitoring and source maps uploaded. Rolling back means
  halting the phased release and shipping a fix.

## Other Checks

- Validate deep links; a URL parameter never bypasses authentication.
- WebViews get a narrow `originWhitelist` and no JavaScript for untrusted content.
- Hide sensitive screens in the app-switcher snapshot; strip debug logging from production builds.

## Verify Before Done

```bash
npx expo-doctor
npx tsc --noEmit
npx expo lint
npm test
# Public config ships inside the app: expect 0
npx expo config --type public | grep -ciE 'secret|private|password|api[_-]?key'
# Credentials belong in SecureStore, not AsyncStorage
grep -rnE 'AsyncStorage\.(setItem|multiSet)\([^)]*(token|secret|password|key)' src/ app/
# The JavaScript bundle builds for both platforms
npx expo export --platform all --output-dir dist-check
# Before a store release (needs an Expo account)
eas build --profile preview --platform all --non-interactive
```
