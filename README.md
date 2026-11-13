# Freer for iOS

Freer for iPhone and iPad: wallet, identity, chat, calls and publishing on Freecash.

This is the third Freer client, beside [Freer for Android](https://github.com/nobodyoffc/Freer)
and [Freer for macOS](https://github.com/nobodyoffc/freer-mac). It is laid out like the
Android app and built from the Mac app's Swift code.

**Status: early.** It builds, runs in the simulator, opens every screen and reads the
live network. Sending, chat, calls and the file flows have not been tested yet.

## Building

The app's logic — cryptography, transactions, transport, storage, the protocols — is
not in this repository. It lives in the Mac repo's Swift packages, which this project
references by path. Check the two out like this:

    MacApp/FreerForMac/         https://github.com/nobodyoffc/freer-mac
    iosapp/freerforios/         this repository

Then open `Freer.xcodeproj` in Xcode (16 or later) and run on an iOS 17+ simulator,
or run `tools/build.sh`.

`CLAUDE.md` describes how the project is organised and how the Mac views are adapted.
