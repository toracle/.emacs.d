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

- [CCSM — Claude Code Session Manager](docs/CCSM.md): a cmux-like manager for
  running many concurrent `claude-code-ide` sessions, with a butler/worker
  control plane. Implemented in [`init-loader/32_*`](init-loader/).
- [cc-butler — worklog & roadmap](docs/cc-butler-worklog.md): running journal of
  turning CCSM into the standalone `cc-butler` package.
