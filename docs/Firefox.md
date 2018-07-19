You must restart Firefox after running the `configure` script.

### Mac

The `configure` script creates a file, `twitch-developer-rig.js` in the `/Applications/Firefox.app/Contents/Resources/default/prefs` folder.

Due to a [Firefox bug](https://bugzilla.mozilla.org/show_bug.cgi?id=1300420), the `configure` script adds the `ssl/cacert.crt` file to Firefox's trust store.

### Windows

The `configure` script creates a file, `twitch-developer-rig.js` in the `%ProgramFiles%\Mozilla Firefox\defaults\prefs` folder.
