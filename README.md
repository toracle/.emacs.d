Clone this repository to ~/.emacs.d/ directory and run a command belows.

To install Cask:

```
make init
```

To install elisp packages via Cask:

```
make package
```

To install external libraries:

```
make external
```

## Documentation

- [cc-butler](cc-butler/README.md): a cmux-like manager for running many
  concurrent `claude-code-ide` sessions, with a butler/worker control plane, a
  per-session document panel, and a self-maintained document repository. A
  standalone package under [`cc-butler/`](cc-butler/), loaded from `init.el`.
  - [Reference](docs/cc-butler-reference.md) · [worklog & roadmap](docs/cc-butler-worklog.md)
