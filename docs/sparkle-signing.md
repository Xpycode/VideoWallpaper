# Sparkle Signing Guide for Video Wallpaper

**Created:** 2026-01-17
**Key Type:** EdDSA (Ed25519)
**Key Scope:** Shared with CropBatch

## Public Key

```
o388Mk7QoQjHQ7PBDGrTQ13HkqvO1nyzkfcnmfVumUQ=
```

This is configured in `Info.plist` as `SUPublicEDKey`.

## Private Key Location

The private key is stored in macOS Keychain:
- **Keychain:** `login.keychain-db`
- **Service:** `https://sparkle-project.org`
- **Account:** `ed25519`

**Backup location:** `~/.sparkle-keys/private-key.txt`

## Signing Updates

After building and notarizing a release DMG:

```bash
# Find the sign_update tool in DerivedData
/Users/sim/Library/Developer/Xcode/DerivedData/VideoWallpaper-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update VideoWallpaper-vX.X.dmg
```

The tool will:
1. Read the private key from Keychain
2. Generate the EdDSA signature
3. Output the signature to paste into `appcast.xml`

## Release Process

1. **Archive:** Product → Archive in Xcode
2. **Export:** Export notarized app
3. **Create DMG:** Package app into DMG
4. **Sign:** Run `sign_update` on the DMG
5. **Update appcast.xml:**
   - Add new `<item>` entry
   - Include `sparkle:edSignature` from sign_update output
   - Set correct `sparkle:version` (build number)
   - Set correct `sparkle:shortVersionString` (marketing version)
   - Set `length` (file size in bytes)
6. **Push:** Commit and push appcast.xml to main branch
7. **Release:** Create GitHub release, attach DMG

## Key History

| Date | Event |
|------|-------|
| 2025-12-02 | Key originally generated for CropBatch |
| 2026-01-17 | Key adopted for Video Wallpaper |

## Restoring the Key

If the key is lost from Keychain, restore from backup:

```bash
/path/to/DerivedData/.../Sparkle/bin/generate_keys -p "$(cat ~/.sparkle-keys/private-key.txt)"
```

## Related Files

- `Info.plist` - Contains SUFeedURL and SUPublicEDKey
- `appcast.xml` - Update feed (repo root)
- `UpdateController.swift` - Sparkle integration code
