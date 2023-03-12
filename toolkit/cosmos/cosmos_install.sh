#!/bin/bash

# CLEAR EENVIRONMENT

> $HOME/.bash_profile
echo -e "[\e[1m\e[32mOK\e[0m] The environment has been cleaned"


# INSTALL GO

ver="1.20.2"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
sudo rm -rf /usr/local/go > /dev/null 2>&1
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
rm "go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
echo "export GOPATH=$HOME/go" >> $HOME/.bash_profile
source $HOME/.bash_profile
echo -e "[\e[1m\e[32mOK\e[0m] Go ${ver} binaries has been installed"


# SETUP DEPENDENCIES 

sudo apt update -y > /dev/null 2>&1
sudo apt install -y curl git jq lz4 build-essential unzip > /dev/null 2>&1
echo -e "[\e[1m\e[32mOK\e[0m] Dependencies has been installed"


# BUILD BINARY

# download repository
read -e -p $'     [\e[33m?\e[0m] Provide the github project URL: ' GITHUB_URL
GITHUB_FOLDER_NAME=$(basename ${GITHUB_URL} .git)
cd ${HOME} || return
rm -rf ${HOME}/${GITHUB_FOLDER_NAME}
echo -e "[\e[1m\e[32mOK\e[0m] The folder ${HOME}/${GITHUB_FOLDER_NAME} has been removed"
git clone ${GITHUB_URL}  > /dev/null 2>&1
echo -e "[\e[1m\e[32mOK\e[0m] The Github repository ${GITHUB_FOLDER_NAME} has been downloaded"
cd ${GITHUB_FOLDER_NAME} || return

# save github url as a variable
echo "export GITHUB_URL=${GITHUB_URL}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# detect latest release
user_project=$(git config --get remote.origin.url | sed 's/.*\/\([^ ]*\/[^.]*\).*/\1/')
VERSION=$(curl https://api.github.com/repos/${user_project}/releases/latest -s | jq .name -r)
read -e -p $'     [\e[33m?\e[0m] Enter specific version or approve the latest release: ' -i "${VERSION}" version
VERSION=${version:-${VERSION}}

# build binary
git checkout ${VERSION}
make build
DAEMON_NAME=$(ls build | head -n 1)
echo "export DAEMON_NAME=${DAEMON_NAME}" >> $HOME/.bash_profile
source $HOME/.bash_profile
cd ${HOME} || return


# SETUP NODE

# setup node name
read -e -p $'     [\e[33m?\e[0m] Provide the node name: ' -i "[NODERS]TEAM" NODENAME
echo "export NODENAME=${NODENAME}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# setup chain id
read -e -p $'     [\e[33m?\e[0m] Provide the chain ID: ' CHAIN_ID
echo "export CHAIN_ID=${CHAIN_ID}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# setup port
echo "export PORT=26" >> $HOME/.bash_profile
source $HOME/.bash_profile

# setup config
${HOME}/${GITHUB_FOLDER_NAME}/build/${DAEMON_NAME} config chain-id $CHAIN_ID
echo -e "[\e[1m\e[32mOK\e[0m] Chain ID ${CHAIN_ID} has been applied for the node configuration"
${HOME}/${GITHUB_FOLDER_NAME}/build/${DAEMON_NAME} config keyring-backend os
echo -e "[\e[1m\e[32mOK\e[0m] Keyring backend OS has been applied for the node configuration"
${HOME}/${GITHUB_FOLDER_NAME}/build/${DAEMON_NAME} config node tcp://localhost:${PORT}657
echo -e "[\e[1m\e[32mOK\e[0m] The RPC port ${PORT}657 has been applied for the node configuration"
${HOME}/${GITHUB_FOLDER_NAME}/build/${DAEMON_NAME} init $NODENAME --chain-id $CHAIN_ID
echo -e "[\e[1m\e[32mOK\e[0m] The node has been initiated with the name ${NODENAME} and chain ID ${CHAIN_ID}"

# setup daemon home path
DAEMON_HOME=$HOME/$(ls -tGA | head -1)
echo "export DAEMON_HOME=${DAEMON_HOME}" >> $HOME/.bash_profile
source $HOME/.bash_profile

# setup cosmovisor
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0
mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin
mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin
mv ${HOME}/${GITHUB_FOLDER_NAME}/build/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/genesis/bin/.
cp ${DAEMON_HOME}/cosmovisor/genesis/bin/${DAEMON_NAME} ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION}/bin/.
rm -rf ${HOME}/${GITHUB_FOLDER_NAME}/build
echo -e "[\e[1m\e[32mOK\e[0m] Cosmovisor has been installed and setup"

#setup links
ln -s ${DAEMON_HOME}/cosmovisor/upgrades/${VERSION} ${DAEMON_HOME}/cosmovisor/current
mkdir -p ${HOME}/go/bin
rm ${HOME}/go/bin/${DAEMON_NAME} > /dev/null 2>&1
sudo ln -s ${DAEMON_HOME}/cosmovisor/current/bin/${DAEMON_NAME} ${HOME}/go/bin/${DAEMON_NAME}
echo -e "[\e[1m\e[32mOK\e[0m] Links has been created, current version is $(${DAEMON_NAME} version)"

# modify gas price
read -e -p $'     [\e[33m?\e[0m] Provide the blockchain currency (denom): ' DENOM
echo "export DENOM=${DENOM}" >> $HOME/.bash_profile
source $HOME/.bash_profile
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.0001$DENOM\"/" ${DAEMON_HOME}/config/app.toml
echo -e "[\e[1m\e[32mOK\e[0m] Minimum gas prices have been changed to 0.0001${DENOM}"

# apply pruning settings
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="10"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" ${DAEMON_HOME}/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" ${DAEMON_HOME}/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" ${DAEMON_HOME}/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" ${DAEMON_HOME}/config/app.toml
echo -e "[\e[1m\e[32mOK\e[0m] Pruning settings has been applied (100/0/10)"

# adjust peers settings
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" ${DAEMON_HOME}/config/config.toml
sed -i 's/max_num_inbound_peers =.*/max_num_inbound_peers = 50/g' ${DAEMON_HOME}/config/config.toml
sed -i 's/max_num_outbound_peers =.*/max_num_outbound_peers = 50/g' ${DAEMON_HOME}/config/config.toml
echo -e "[\e[1m\e[32mOK\e[0m] Peers settings have been adjusted (filter peers enabled, inbound peers set to 50, outbound peers set to 50)"

# disable indexer
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" ${DAEMON_HOME}/config/config.toml
echo -e "[\e[1m\e[32mOK\e[0m] Indexer has been disabled"

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" ${DAEMON_HOME}/config/config.toml
echo -e "[\e[1m\e[32mOK\e[0m] Prometheus has been enabled"

# download genesis
read -e -p $'     [\e[33m?\e[0m] Provide the download URL for genesis: ' GENESIS_URL
curl -s ${GENESIS_URL} > ${DAEMON_HOME}/config/genesis.json
echo -e "[\e[1m\e[32mOK\e[0m] Genesis file has been downloaded and applied"

# download addrbook
read -e -p $'     [\e[33m?\e[0m] Provide the download link for address book: ' ADDRBOOK_URL
curl -s ${ADDRBOOK_URL} > ${DAEMON_HOME}/config/addrbook.json
echo -e "[\e[1m\e[32mOK\e[0m] Address book file has been downloaded and applied"

# setup seeds and peers
read -e -p $'     [\e[33m?\e[0m] Provide the seeds (comma separated): ' SEEDS
read -e -p $'     [\e[33m?\e[0m] Provide the peers (comma separated): ' PEERS
sed -i 's|^seeds *=.*|seeds = "'$SEEDS'"|; s|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' ${DAEMON_HOME}/config/config.toml
echo -e "[\e[1m\e[32mOK\e[0m] Seeds and peers have been applied"

# reset data
${DAEMON_NAME} tendermint unsafe-reset-all --home ${DAEMON_HOME} --keep-addr-book
echo -e "[\e[1m\e[32mOK\e[0m] The node data has been reseted"

# statesync
cp ${DAEMON_HOME}/data/priv_validator_state.json ${DAEMON_HOME}/priv_validator_state.json.backup
read -e -p $'     [\e[33m?\e[0m] Provide the RPC node for statesync: ' SNAP_RPC
LATEST_HEIGHT=$(curl -s $SNAP_RPC/block | jq -r .result.block.header.height)
BLOCK_HEIGHT=$((LATEST_HEIGHT - 2000))
TRUST_HASH=$(curl -s "$SNAP_RPC/block?height=$BLOCK_HEIGHT" | jq -r .result.block_id.hash)
sed -i 's|^enable *=.*|enable = true|' ${DAEMON_HOME}/config/config.toml
sed -i 's|^rpc_servers *=.*|rpc_servers = "'$SNAP_RPC,$SNAP_RPC'"|' ${DAEMON_HOME}/config/config.toml
sed -i 's|^trust_height *=.*|trust_height = '$BLOCK_HEIGHT'|' ${DAEMON_HOME}/config/config.toml
sed -i 's|^trust_hash *=.*|trust_hash = "'$TRUST_HASH'"|' ${DAEMON_HOME}/config/config.toml
mv ${DAEMON_HOME}/priv_validator_state.json.backup ${DAEMON_HOME}/data/priv_validator_state.json
echo -e "[\e[1m\e[32mOK\e[0m] Statesync settings: latest height ${LATEST_HEIGHT}, block height ${BLOCK_HEIGHT}, trust hash ${TRUST_HASH}"


# RUN

# create service
sudo tee "/etc/systemd/system/${DAEMON_NAME}.service" > /dev/null << EOF
[Unit]
Description=${DAEMON_NAME} node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=${DAEMON_HOME}"
Environment="DAEMON_NAME=${DAEMON_NAME}"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="UNSAFE_SKIP_BACKUP=true"

[Install]
WantedBy=multi-user.target
EOF

# launch
sudo systemctl daemon-reload
sudo systemctl enable ${DAEMON_NAME}
sudo systemctl restart ${DAEMON_NAME}
sudo journalctl -fu ${DAEMON_NAME} --no-hostname -o cat
