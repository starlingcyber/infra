self: { config, pkgs, lib, ...  }:

with builtins; with lib; with self.lib.util; let
  cfg = config.services.horcrux;

  # Shorthand for the package, used below
  horcrux = self.packages.${pkgs.system}.horcrux;

in {
  options.services.horcrux = {
    enable = mkEnableOption "Enable the Horcrux threshold CometBFT signing service";

    serviceName = mkOption {
      type = types.str;
      default = "horcrux";
      description = "The name of the Horcrux service";
    };

    homeDir = mkOption {
      type = types.str;
      default = "/var/lib/${cfg.serviceName}";
      description = "The directory where the Horcrux service stores its data";
    };

    shardsDir = mkOption {
      type = types.str;
      default = "/etc/${cfg.serviceName}/shards";
      description = "The directory where the consensus key shards are stored";
    };

    privKey.path = mkOption {
      type = types.str;
      default = "/etc/${cfg.serviceName}/ecies_key";
      description = "The path to the ECIES private key of this cosigner, which should be a file containing the key encoded in Base64";
    };

    threshold = mkOption {
      type = types.int;
      description = "The number of shards required to reconstruct the secret";
    };

    address = mkOption {
      type = types.str;
      description = "The address (IP or DNS name) of this cosigner";
    };

    id = mkOption {
      type = types.ints.between 1 (1 + length (attrNames cfg.cosigners));
      description = "The ID of this cosigner as a strictly positive numerical index";
    };

    port = mkOption {
      type = types.int;
      default = 2222;
      description = "The port of this cosigner";
    };

    pubKey = mkOption {
      type = types.str;
      description = "The ECIES public key of this cosigner, encoded in Base64";
    };

    cosigners = mkOption {
      type = with types; attrsOf (submodule {
          options = {
            id = mkOption {
              type = types.ints.between 1 (1 + length (attrNames cfg.cosigners));
              description = "The ID of this other cosigner as a strictly positive numerical index";
            };
            port = mkOption {
              type = int;
              default = 2222;
              description = "The port of the other cosigner";
            };
            pubKey = mkOption {
              type = str;
              description = "The ECIES public key of the other cosigner, encoded in Base64";
            };
          };
        });
      default = {};
      description = "The other cosigners which are not this one (all must share the same list of cosigners in total), as a mapping from address (IP or DNS name) to configuration";
    };

    chainNodes = mkOption {
      type = with types; attrsOf (submodule {
        options = {
          port = mkOption {
            type = int;
            default = 1234;
            description = "The port of the chain node's privValidator server";
          };
        };
      });
      default = [];
      description = "All the chain nodes, in the form of a mapping from address (IP or DNS name) to configuration";
    };

    grpc = mkOption {
      type = with types; submodule {
        options = {
          timeout = mkOption {
            type = str;
            default = "1000ms";
            description = "The timeout in for gRPC calls, in Go duration format";
          };
          addr = mkOption {
            type = str;
            default = "";
            description = "The address of the gRPC server";
          };
        };
      };
      default = {};
      description = "gRPC configuration for this cosigner";
    };

    debug = mkOption {
      type = with types; submodule {
        options = {
          addr = mkOption {
            type = str;
            default = "";
            description = "The address of the debug server";
          };
        };
      };
      default = {};
      description = "Debug configuration for this cosigner";
    };

    raft = mkOption {
      type = with types; submodule {
        options = {
          timeout = mkOption {
            type = str;
            default = "1000ms";
            description = "The timeout for Raft consensus, in Go duration format";
          };
        };
      };
      default = {};
      description = "Raft configuration for this cosigner";
    };
  };

  config = let
    # Make an attrset of all cosigners, self and also others
    allCosigners = cfg.cosigners // {
      ${cfg.address} = {
        inherit (cfg) id port pubKey;
      };
    };

    # Get a set of all the cosigners in canonical ordering by ID:
    orderedCosigners =
      sort
        (a: b: a.id < b.id)
        (attrValues
          (mapAttrs
            (name: cosigner: {
              inherit name;
              inherit (cosigner) port pubKey id;
            })
            allCosigners));

    # Check that the cosigner IDs are unique and in bounds, and that there is exactly one cosigner
    # marked as self, extracting that ID to use in the configuration -- this check is done here
    # rather than in type-checking to prevent module system recursion
    selfId = let
      correctIds =
        let ids = map (c: c.id) orderedCosigners; in
        all (c: 1 <= c.id && c.id <= length ids) orderedCosigners &&
        unique ids == ids;
    in if correctIds
    then cfg.id
    else throw "Cosigner IDs are non-unique or out of bounds: each cosigner must have a unique ID in the range [1, N]";

    # The Horcrux configuration:
    horcruxConfig = {
      signMode =  "threshold";
      thresholdMode = {
        inherit (cfg) threshold;
        cosigners =
          map
            (cosigner: {
              shardID = cosigner.id;
              p2pAddr = "tcp://${cosigner.name}:${toString cosigner.port}";
            })
            orderedCosigners;
        grpcTimeout = cfg.grpc.timeout;
        raftTimeout = cfg.raft.timeout;
      };
      chainNodes =
        attrValues (mapAttrs
          (name: node: {
            privValAddr = "tcp://${name}:${toString node.port}";
          })
          cfg.chainNodes);
      debugAddr = cfg.debug.addr;
      grpcAddr = cfg.grpc.addr;
    };

  # The file with the pubkeys of all cosigners and the id of this one (not its private key):
  pubKeyConfig = {
    eciesPubs = map (c: c.pubKey) orderedCosigners;
    id = selfId;
  };

  in mkIf cfg.enable {
    # Add the cometbft executable to the environment
    environment.systemPackages = [ horcrux ];

    systemd.services.${cfg.serviceName} = {
      # If enabled, the service will start automatically when the network comes up
      wantedBy = [ "multi-user.target" ];
      # The `ecies_keys.json` file is a JSON file with the ECIES public keys of all the cosigners, the
      # node ID, and the ECIES private key of this cosigner: we first make a template for it that
      # *excludes* the private key because we have to read it at runtime to avoid it ending up in the
      # Nix store. Then, we write the private key into the template (reading it from the specified
      # location), write the config file to the home directory where Horcrux will look for it, and
      # start Horcrux:
      script = ''
        set -euo
        PATH=${horcrux}/bin:${pkgs.jq}/bin:$PATH
        HORCRUX_HOME='${cfg.homeDir}'
        rm -f "$HORCRUX_HOME"/*_shard.json
        for SHARD in "${cfg.shardsDir}"/*_shard.json; do
          cp -f "$SHARD" "$HORCRUX_HOME"
        done
        echo '${toJSON pubKeyConfig}' \
          | ECIES_PRIVKEY='$(< ${cfg.privKey.path})' \
            jq '.eciesKey = env.ECIES_PRIVKEY' \
          > "$HORCRUX_HOME/ecies_keys.json"
        echo '${toJSON horcruxConfig}' > "$HORCRUX_HOME/config.yaml"
        horcrux --home "$HORCRUX_HOME" start
      '';
      # The configuration of the service itself:
      serviceConfig = {
        Restart = "always";
        # This creates a directory at `/var/lib/${cfg.serviceName}` unconditionally, though it may
        # not actually be used if the home directory is overridden:
        StateDirectory = cfg.serviceName;
        StateDirectoryMode = "0600";
        # This creates a directory at `/etc/${cfg.serviceName}` unconditionally, though it may not
        # actually be used if the shards directory and privKey path are overridden:
        ConfigurationDirectory= cfg.serviceName;
        ConfigurationDirectoryMode = "0600";
      } // sandboxSystemd {
        # CometBFT needs to write to the home and data directories
        writeDirs = [ cfg.homeDir ];
        # We permit only the necessary network access
        addressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };
  };
}