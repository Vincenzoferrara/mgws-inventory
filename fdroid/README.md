# F-Droid build recipe

`it.mgws.mgws_inventory.yml` is the build recipe for F-Droid, kept in the
format that `fdroid rewritemeta` produces (no comments, fixed field order),
because the fdroiddata CI rejects any other layout.

To submit or update it:

1. Copy it to `metadata/it.mgws.mgws_inventory.yml` in a fork of
   <https://gitlab.com/fdroid/fdroiddata>, on a branch named after the app ID.
2. Check it with fdroidserver: `fdroid readmeta`, `fdroid rewritemeta`,
   `fdroid lint` and `fdroid build it.mgws.mgws_inventory`.
3. Commit as `New App: it.mgws.mgws_inventory`, push and open a merge
   request labelled "New App".

The build is reproducible: F-Droid rebuilds each tag in
`/home/vagrant/build/it.mgws.mgws_inventory`, compares it with
`mgws_inventory-fdroid.apk` from the GitHub release (`Binaries`) and ships
that APK, signed with our key (`AllowedAPKSigningKeys`).

**Keep the two builds identical.** The workflow step "Build signed F-Droid
APK" in `.github/workflows/velopack-release.yml` must run the same commands,
flags and Flutter version as this recipe:

- when `FLUTTER_VERSION` changes in the workflows, update the `flutter@X.Y.Z`
  srclib here and in fdroiddata in the same release;
- when the F-Droid build flags change, change both places.

Otherwise F-Droid's rebuild no longer matches and it stops updating the app.

Texts, screenshots and changelogs come from `fastlane/metadata/android/` in
this repository. After inclusion F-Droid builds every new `v*` tag by
itself: the release workflow writes the same version into `pubspec.yaml`,
which `UpdateCheckData` reads.
