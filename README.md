# Antigravity Jail

This flake wraps Google's Antigravity agentic editor into a strict bubblewrap jail to protect your system and secrets.
It relies on upstream antigravity packaged for nix [jacopone/antigravity-nix](https://github.com/jacopone/antigravity-nix/tree/master), as well as [jail.nix](https://git.sr.ht/~alexdavid/jail.nix) for the sandboxing.


The jail:
* Hides your whole filesystem from the editor except for:
  + Files needed by antigravity and chromium to work.
  + The project dir you start antigravity on (as command line argument)
* Gives access to a predefined set of commands within the editor.
* Shadows `.env` file in the project directory (by mounting an empty file in place).


## Usage

To use the flake directly, you may run:

```sh
nix run github:cmdoret/antigravity-jail ~/my-project
```

### Note
On Ubuntu you might need to define an AppArmor policy to enable unprivileged user namespaces for bwrap.
To do so e.g. add `/etc/apparmor.d/bwrap` 

```sh
abi <abi/4.0>,
include <tunables/global>

profile bwrap /nix/store/*/bin/bwrap flags=(unconfined) {
  userns,

  # Site-specific additions and overrides. See local/README for details.
  include if exists <local/bwrap>
}
```

## Caveats

The editor is run in verbose mode, because for some unlogged reason, it crashes without the --verbose flag (likely due to something missing in the sandbox).
