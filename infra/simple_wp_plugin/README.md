# simple_wp_plugin

`plugin-shell.zip` — a one-file WordPress plugin that executes commands as the web
server user. Upload it through **Plugins → Add New → Upload Plugin** on a WordPress
instance you have admin on; no activation is needed, the file is reachable as soon as
it is unpacked.

```text
http://<target>/wp-content/plugins/plugin-shell/plugin-shell.php?cmd=id
```

It stays zipped because that is the format the WordPress plugin uploader takes. The
archive holds a single 834-byte `plugin-shell.php`; adapted from
[leonjza/wordpress-shell](https://github.com/leonjza/wordpress-shell).

`setup_links` skips this directory by name, so the zip is never symlinked into
`~/.local/bin` despite its executable bit.

An unauthenticated command-execution endpoint on a live host is about as loud and as
dangerous as artifacts get. Record the upload in your host notes when you make it
(`target -F "uploaded plugin-shell to <host>"`) so it makes it onto the cleanup list,
and remove the plugin when you are done.
