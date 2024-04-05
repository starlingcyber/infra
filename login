# This loads all the environment variables from 1Password into a subshell which is prepared with all
# the tools needed to operate the infrastructure. It doesn't work from within the FHS VS Code on
# NixOS because of "reasons", so it has to be run from a normal terminal window.
op run --env-file="./.env" -- nix develop --command "$SHELL"