self: { config, pkgs, lib, ...  }:

with lib; with self.lib.util; let
  cfg = config.services.cometbft;

  # Shorthand for the package, used below
  cometbft = self.packages.${pkgs.system}.cometbft;

  # Write a config.toml file for CometBFT given the configuration options
  configToml = (pkgs.formats.toml {}).generate "penumbra-cometbft-config" {
    version = cometbft.version;
    proxy_app = "tcp://${cfg.proxyApp.ip}:${toString cfg.proxyApp.port}";
    moniker = cfg.moniker;
    block_sync = true;
    db_backend = "goleveldb";
    db_dir = cfg.dataDir;
    log_level = "info";
    log_format = "plain";
    priv_validator_key_file = cfg.privValidator.keyFile;
    priv_validator_state_file = cfg.privValidator.stateFile;
    node_key_file = cfg.nodeKeyFile;
    priv_validator_laddr =
      if cfg.privValidator.laddr.enable
      then "tcp://${cfg.privValidator.laddr.ip}:${toString cfg.privValidator.laddr.port}"
      else "";
    abci = "socket";
    filter_peers = false;
    rpc = if cfg.rpc.enable then {
      laddr = "tcp://${cfg.rpc.ip}:${toString cfg.rpc.port}";
      cors_allowed_origins = [];
      cors_allowed_methods = ["HEAD" "GET" "POST"];
      cors_allowed_headers = ["Origin" "Accept" "Content-Type" "X-Requested-With" "X-Server-Time"];
      grpc_laddr = "";
      grpc_max_open_connections = 900;
      unsafe = false;
      max_open_connections = 900;
      max_subscription_clients = 100;
      max_subscriptions_per_client = 5;
      timeout_broadcast_tx_commit = "10000ms";
      max_body_bytes = 1000000;
      max_header_bytes = 1048576;
      tls_cert_file = "";
      tls_key_file = "";
      pprof_laddr = "";
    } else {};
    p2p = {
      laddr = "tcp://${cfg.p2p.ip}:${toString cfg.p2p.port}";
      external_address = cfg.p2p.externalAddress;
      seeds = concatStringsSep "," cfg.p2p.seeds;
      persistent_peers = concatStringsSep "," cfg.p2p.persistentPeers;
      addr_book_file = cfg.p2p.addrBookFile;
      addr_book_strict = cfg.p2p.addrBookStrict;
      max_num_inbound_peers = cfg.p2p.maxPeers.inbound;
      max_num_outbound_peers = cfg.p2p.maxPeers.outbound;
      unconditional_peer_ids = concatStringsSep "," cfg.p2p.unconditionalPeerIds;
      persistent_peers_max_dial_period = "0s";
      flush_throttle_timeout = "100ms";
      max_packet_msg_payload_size = 1024;
      send_rate = 5120000;
      recv_rate = 5120000;
      pex = cfg.p2p.pex;
      seed_mode = cfg.p2p.seedMode;
      private_peer_ids = concatStringsSep "," cfg.p2p.privatePeerIds;
      allow_duplicate_ip = cfg.p2p.allowDuplicateIp;
      handshake_timeout = cfg.p2p.handshakeTimeout;
      dial_timeout = cfg.p2p.dialTimeout;
    };
    mempool = {
      recheck = true;
      broadcast = true;
      wal_dir = "";
      size = 5000;
      max_txs_bytes = 1073741824;
      cache_size = 10000;
      keep-invalid-txs-in-cache = false;
      max_tx_bytes = 1048576;
      max_batch_bytes = 0;
    };
    consensus = {
      wal_file = "${cfg.dataDir}/cs.wal/wal";
      timeout_propose = "3000ms";
      timeout_propose_delta = "500ms";
      timeout_prevote = "1000ms";
      timeout_prevote_delta = "500ms";
      timeout_precommit = "1000ms";
      timeout_precommit_delta = "500ms";
      timeout_commit = "5000ms";
      double_sign_check_height = cfg.consensus.doubleSignCheckHeight;
      skip_timeout_commit = false;
      create_empty_blocks = true;
      create_empty_blocks_interval = "0ms";
      peer_gossip_sleep_duration = "100ms";
      peer_query_maj23_sleep_duration = "2000ms";
    };
    instrumentation = {
      prometheus = cfg.prometheus.enable;
      prometheus_listen_addr = ":${toString cfg.prometheus.port}";
      max_open_connections = cfg.prometheus.maxOpenConnections;
      namespace = cfg.serviceName;
    };
    storage.discard_abci_responses = false;
    tx_index.indexer = cfg.txIndex.indexer;
    tx_index.psql_conn = cfg.txIndex.psqlConn;
    statesync.enable = false;
  };

  # Start script for the service

  # Note: this *very intentionally* uses `yes n` to answer "no" to the prompt to overwrite the
  # genesis file, but uses cp -f to overwrite the config file. This is because the genesis file
  # could be overwritten by the pd bootstrap-from-a-snapshot process, while the config file is
  # expected to be updated by the user through Nix configuration, so it should always mirror exactly
  # what's in the Nix store.
  startScript = pkgs.writeShellScript "cometbft" ''
    set -euxo
    PATH="${pkgs.coreutils}/bin:${cometbft}/bin:$PATH"

    mkdir -p "${cfg.homeDir}"
    mkdir -p "${cfg.dataDir}"
    chmod 0600 "${cfg.homeDir}"
    chmod 0600 "${cfg.dataDir}"
    mkdir -p "${cfg.homeDir}/config"
    cp -f "${configToml}" "${cfg.homeDir}/config/config.toml"
    ${pkgs.coreutils}/bin/cp -f "${cfg.genesis.file}" "${cfg.homeDir}/config/genesis.json"
    rm -f "${cfg.homeDir}/config/priv_validator_key.json"
    cometbft init --home "${cfg.homeDir}"
    cometbft start --home "${cfg.homeDir}"
  '';
in {
  options.services.cometbft = {
    enable = mkEnableOption "Enables just CometBFT without automatically starting the Penumbra daemon";

    homeDir = mkOption {
      type = types.path;
      default = "/var/lib/${cfg.serviceName}";
      description = "The home directory for CometBFT";
    };

    dataDir = mkOption {
      type = types.str;
      default = "${cfg.homeDir}/data";
      description = "The home directory for CometBFT (if a relative path, it will be relative to the home directory)";
    };

    privValidator.laddr.enable = mkEnableOption "Enables an external private validator";

    privValidator.laddr.ip = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The IP address CometBFT will listen on for an external private validator";
    };

    privValidator.laddr.port = mkOption {
      type = types.port;
      default = 1234;
      description = "The port CometBFT will listen on for an external private validator";
    };

    privValidator.keyFile = mkOption {
      type = types.path;
      description = "The file containing the private validator key";
      default = "${cfg.homeDir}/config/priv_validator_key.json";
    };

    privValidator.stateFile = mkOption {
      type = types.path;
      description = "The file containing the private validator state";
      default = "${cfg.homeDir}/data/priv_validator_state.json";
    };

    nodeKeyFile = mkOption {
      type = types.path;
      description = "The file containing the node key";
      default = "${cfg.homeDir}/config/node_key.json";
    };

    genesis.file = mkOption {
      type = types.path;
      description = "The file containing the genesis information for the chain";
    };

    moniker = mkOption {
      type = types.str;
      default = "anonymous";
      description = "The moniker for CometBFT's self-identification to the world";
    };

    proxyApp.port = mkOption {
      type = types.port;
      default = 26658;
      description = "The port CometBFT will listen on for the proxy application";
    };

    proxyApp.ip = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The IP address of the application for which CometBFT is running consensus";
    };

    p2p.port = mkOption {
      type = types.port;
      default = 26656;
      description = "The port CometBFT will listen on";
    };

    p2p.ip = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "The IP address CometBFT will listen on";
    };

    p2p.externalAddress = mkOption {
      type = types.str;
      default = "";
      description = "The external address CometBFT will advertise to peers";
    };

    p2p.seeds = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The list of seed nodes CometBFT will use to bootstrap p2p";
    };

    p2p.persistentPeers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The list of persistent peers with which CometBFT will maintain connections";
    };

    p2p.addrBookFile = mkOption {
      type = types.str;
      default = "config/addrbook.json";
      description = "The file containing the address book for CometBFT";
    };

    p2p.addrBookStrict = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to only allow connections to peers in the address book";
    };

    p2p.maxPeers.inbound = mkOption {
      type = types.int;
      default = 100;
      description = "The maximum number of inbound peers CometBFT will accept";
    };

    p2p.maxPeers.outbound = mkOption {
      type = types.int;
      default = 50;
      description = "The maximum number of outbound peers CometBFT will connect to";
    };

    p2p.unconditionalPeerIds = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The list of peer IDs CometBFT will always attempt to connect to";
    };

    p2p.pex = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable peer exchange";
    };

    p2p.seedMode = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable seed mode, which crawls the network looking for peers to broadcast";
    };

    p2p.privatePeerIds = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The list of peer IDs CometBFT will never gossip to the network";
    };

    p2p.allowDuplicateIp = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow multiple connections from the same IP address";
    };

    p2p.handshakeTimeout = mkOption {
      type = types.str;
      default = "20s";
      description = "The amount of time to wait for a handshake to complete";
    };

    p2p.dialTimeout = mkOption {
      type = types.str;
      default = "3s";
      description = "The amount of time to wait for a dial to complete";
    };

    rpc.enable = mkEnableOption "Enables the RPC server for CometBFT";

    rpc.port = mkOption {
      type = types.port;
      default = 26657;
      description = "The port CometBFT will listen on for RPC";
    };

    rpc.ip = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The IP address CometBFT will listen on for RPC";
    };

    txIndex.indexer = mkOption {
      type = types.str;
      default = "null";
      description = "The indexer to use for transactions";
    };

    txIndex.psqlConn = mkOption {
      type = types.str;
      default = "";
      description = "The connection string for the PostgreSQL database to use for indexing transactions";
    };

    consensus.doubleSignCheckHeight = mkOption {
      type = types.int;
      default = 0;
      description = "How many blocks to look back to check existence of the node's consensus votes before joining consensus";
    };

    prometheus.enable = mkEnableOption "Enables Prometheus metrics for CometBFT";

    prometheus.port = mkOption {
      type = types.port;
      default = 26660;
      description = "The port Prometheus will scrape for metrics";
    };

    prometheus.maxOpenConnections = mkOption {
      type = types.int;
      default = 3;
      description = "The maximum number of open connections to Prometheus";
    };

    serviceName = mkOption {
      type = types.str;
      default = "cometbft";
      description = "The name of the systemd service for CometBFT";
    };
  };

  config = mkIf cfg.enable {
    # Add the cometbft executable to the environment
    environment.systemPackages = [ cometbft ];

    systemd.services.${cfg.serviceName} = {
      # If enabled, the service will start automatically when the network comes up
      wantedBy = [ "multi-user.target" ];
      # The configuration of the service itself:
      serviceConfig =  {
        Restart = "always";
        # This creates a directory at `/var/lib/${cfg.serviceName}` unconditionally, though it may
        # not actually be used if the home directory and/or data directory are both overridden:
        StateDirectory = cfg.serviceName;
        StateDirectoryMode = "0600";
        ExecStart = startScript;
      } // sandboxSystemd {
        # CometBFT needs to write to the home and data directories
        writeDirs = [ cfg.homeDir cfg.dataDir ];
        # We permit only the necessary network access
        addressFamilies = [ "AF_INET" "AF_INET6" ];
      };
    };
  };
}