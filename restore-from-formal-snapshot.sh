#!/bin/bash

function error {
    echo "error: $@"
    exit 1
}

function restore_with_formal() {
    docker run --rm \
        -v ./genesis.blob:/opt/iota/config/genesis.blob \
        -v ./validator.yaml:/opt/iota/config/fullnode.yaml \
        -v ./iotadb/authorities_db:/opt/iota/db \
        -w /iota \
        -e RUST_LOG=debug=true \
        -e MAINNET_FORMAL_UNSIGNED_BUCKET=iota-testnet-formal \
        -e AWS_SNAPSHOT_ENDPOINT=https://formal-snapshot.testnet.iota.cafe \
        -e FORMAL_SNAPSHOT_ARCHIVE_BUCKET=iota-testnet-archive \
        -e AWS_ARCHIVE_ENDPOINT=https://archive.testnet.iota.cafe \
        -e AWS_ARCHIVE_VIRTUAL_HOSTED_REQUESTS=true \
        iotaledger/iota-tools:testnet \
        /usr/local/bin/iota-tool download-formal-snapshot \
        --latest \
        --genesis /opt/iota/config/genesis.blob \
        --path /opt/iota/db \
        --num-parallel-downloads 20 \
        --no-sign-request \
        --verify normal \
        --verbose || error "restoring from formal snapshot"
}


read -p "Really restore database from formal snapshot (y/*)?" restore_choice

[[ "$restore_choice" != "y" ]] && error "aborted"

docker compose down -t1 || error "stopping iota-node-docker setup"

BACKUP="backup-$( date +"%Y-%m-%d-%H-%M-%S" )"

mkdir -p ./iotadb/${BACKUP} &> /dev/null || error "creating backup directory"

find ./iotadb/ -maxdepth 1 -type d -name "authorities_db" -or -name "consensus_db" -exec mv {} ./iotadb/${BACKUP}/ \;

echo "moved old directories to ${BACKUP} directory"

restore_with_formal

read -p "Do you want to start the iota node now? (y/n): " start_node

if [ "$start_node" == "y" ]; then
    docker compose up -d
fi

