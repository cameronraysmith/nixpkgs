import ./make-test-python.nix ({pkgs, ...}: let
  actionsFileUnpinned = pkgs.writeText "github-actions-unpinned.yml" ''
    name: "CI"
    on:
      push:
        branches: [main]
      pull_request:
        types: [opened, reopened, synchronize]

    jobs:
      test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4.1.4
          - name: Install Nix
            uses: DeterminateSystems/nix-installer-action@v11
          - uses: cachix/cachix-action@v14
            with:
              name: nix-community
          - name: command
            run: |-
              ls -l
  '';
  actionsFilePinned = pkgs.writeText "github-actions-pinned.yml" ''
    name: "CI"
    on:
      push:
        branches: [main]
      pull_request:
        types: [opened, reopened, synchronize]

    jobs:
      test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@0ad4b8fadaa221de15dcec353f45205ec38ea70b # ratchet:actions/checkout@v4.1.4
          - name: Install Nix
            uses: DeterminateSystems/nix-installer-action@8cdf194da984e4f12b2f8c36d1fa107c1dd67f5c # ratchet:DeterminateSystems/nix-installer-action@v11
          - uses: cachix/cachix-action@18cf96c7c98e048e10a83abd92116114cd8504be # ratchet:cachix/cachix-action@v14
            with:
              name: nix-community
          - name: command
            run: |-
              ls -l
  '';
in {
  name = "ratchet";
  meta = with pkgs.lib.maintainers; {
    maintainers = [cameronraysmith];
  };

  nodes = {
    machine = {...}: {
      environment.systemPackages = [pkgs.ratchet];
      environment.etc."github-actions-unpinned.yml".source = actionsFileUnpinned;
      environment.etc."github-actions-pinned.yml".source = actionsFilePinned;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    machine.succeed("ratchet --version")
    machine.succeed("ratchet --help")

    # Copy test files to working tmp directory
    machine.execute("cp /etc/github-actions-pinned.yml github-actions-pinned.yml")
    machine.execute("chmod u+w github-actions-pinned.yml")
    machine.execute("cp /etc/github-actions-unpinned.yml github-actions-unpinned.yml")
    machine.execute("chmod u+w github-actions-unpinned.yml")

    # Execute ratchet check
    statusUnpinned, unpinnedOutput = machine.execute("ratchet check github-actions-unpinned.yml")
    assert statusUnpinned == 1
    assert "" in unpinnedOutput

    statusPinned, pinnedOutput = machine.execute("ratchet check github-actions-pinned.yml")
    assert statusPinned == 0
    assert "" in pinnedOutput
  '';
})
