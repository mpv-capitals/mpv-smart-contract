#!/bin/bash

set -e
set -u
set -o pipefail

fvalue=""
nvalue=""

while getopts 'f:n:' OPTION; do
  case "$OPTION" in
    f)
      fvalue="$OPTARG"
      ;;
    n)
      nvalue="$OPTARG"
      ;;
    ?)
      echo "script usage: $(basename $0) [-f zos_file] [-n network]" >&2
      ;;
  esac
done
shift "$(($OPTIND -1))"

# ganache test keys
# 0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1
# 0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d

# Example usage
# $ ./deploy.sh zos.dev-1554994902267.json

# == CONFIG ==

ZosFile="$fvalue"
if [ -z "$fvalue" ]; then
  # get zos file if exists
  ZosFile=$(ls | grep zos..*.json | tr -d '[:cntrl:]'| perl -pe 's/\[[0-9;]*[mGKF]//g')
fi

Network="$nvalue"
if [ -z "$nvalue" ]; then
  Network="development"
fi

SenderAddress=0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1
RedemptionFeeReceiverWallet="$SenderAddress"
MintingReceiverWallet="$SenderAddress"

# == SETUP ==

contract_address() {
  cat "$ZosFile" | jq ".contracts.$1.address" | sed -e 's/"//g'
}

contract_proxy_address() {
  cat "$ZosFile" | jq ".proxies[\"master-property-value/$1\"][0].address" | sed -e 's/"//g'
}

AssetsAddress=$(contract_address "Assets")
BasicProtectorMultiSigWalletAddress=$(contract_address "BasicProtectorMultiSigWallet")
BasicProtectorRoleAddress=$(contract_address "BasicProtectorRole")
MasterPropertyValueAddress=$(contract_address "MasterPropertyValue")
MintingAdminMultiSigWalletAddress=$(contract_address "MintingAdminMultiSigWallet")
MintingAdminRoleAddress=$(contract_address "MintingAdminRole")
MPVTokenAddress=$(contract_address "MPVToken")
OperationAdminMultiSigWalletAddress=$(contract_address "OperationAdminMultiSigWallet")
OperationAdminRoleAddress=$(contract_address "OperationAdminRole")
RedemptionAdminMultiSigWalletAddress=$(contract_address "RedemptionAdminMultiSigWallet")
RedemptionAdminRoleAddress=$(contract_address "RedemptionAdminRole")
SuperProtectorMultiSigWalletAddress=$(contract_address "SuperProtectorMultiSigWallet")
SuperProtectorRoleAddress=$(contract_address "SuperProtectorRole")
WhitelistAddress=$(contract_address "Whitelist")

echo "Network: $Network"
echo "zos: $ZosFile"
echo "Assets: $AssetsAddress"
echo "BasicProtectorMultiSigWallet: $BasicProtectorMultiSigWalletAddress"
echo "BasicProtectorRole: $BasicProtectorRoleAddress"
echo "MasterPropertyValue: $MasterPropertyValueAddress"
echo "MintingAdminMultiSigWallet: $MintingAdminMultiSigWalletAddress"
echo "MintingAdminRole: $MintingAdminRoleAddress"
echo "MPVToken: $MPVTokenAddress"
echo "OperationAdminMultiSigWallet: $OperationAdminMultiSigWalletAddress"
echo "OperationAdminRole: $OperationAdminRoleAddress"
echo "RedemptionAdminMultiSigWallet: $RedemptionAdminMultiSigWalletAddress"
echo "RedemptionAdminRole: $RedemptionAdminRoleAddress"
echo "SuperProtectorMultiSigWallet: $SuperProtectorMultiSigWalletAddress"
echo "SuperProtectorRole: $SuperProtectorRoleAddress"
echo "Whitelist: $WhitelistAddress"

# == INITIALIZERS ==

# npx zos push --network=development

npx zos create SuperProtectorMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network" --from="$SenderAddress"
npx zos create BasicProtectorMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"
npx zos create MintingAdminMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"
npx zos create OperationAdminMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"
npx zos create RedemptionAdminMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"


ProxyAssetsAddress=$(contract_proxy_address "Assets")
ProxyBasicProtectorMultiSigWalletAddress=$(contract_proxy_address "BasicProtectorMultiSigWallet")
ProxyBasicProtectorRoleAddress=$(contract_proxy_address "BasicProtectorRole")
ProxyMasterPropertyValueAddress=$(contract_proxy_address "MasterPropertyValue")
ProxyMintingAdminMultiSigWalletAddress=$(contract_proxy_address "MintingAdminMultiSigWallet")
ProxyMintingAdminRoleAddress=$(contract_proxy_address "MintingAdminRole")
ProxyMPVTokenAddress=$(contract_proxy_address "MPVToken")
ProxyOperationAdminMultiSigWalletAddress=$(contract_proxy_address "OperationAdminMultiSigWallet")
ProxyOperationAdminRoleAddress=$(contract_proxy_address "OperationAdminRole")
ProxyRedemptionAdminMultiSigWalletAddress=$(contract_proxy_address "RedemptionAdminMultiSigWallet")
ProxyRedemptionAdminRoleAddress=$(contract_proxy_address "RedemptionAdminRole")
ProxySuperProtectorMultiSigWalletAddress=$(contract_proxy_address "SuperProtectorMultiSigWallet")
ProxySuperProtectorRoleAddress=$(contract_proxy_address "SuperProtectorRole")
ProxyWhitelistAddress=$(contract_proxy_address "Whitelist")

echo "ProxyAssets: $ProxyAssetsAddress"
echo "ProxyBasicProtectorMultiSigWallet: $ProxyBasicProtectorMultiSigWalletAddress"
echo "ProxyBasicProtectorRole: $ProxyBasicProtectorRoleAddress"
echo "ProxyMasterPropertyValue: $ProxyMasterPropertyValueAddress"
echo "ProxyMintingAdminMultiSigWallet: $ProxyMintingAdminMultiSigWalletAddress"
echo "ProxyMintingAdminRole: $ProxyMintingAdminRoleAddress"
echo "ProxyMPVToken: $ProxyMPVTokenAddress"
echo "ProxyOperationAdminMultiSigWallet: $ProxyOperationAdminMultiSigWalletAddress"
echo "ProxyOperationAdminRole: $ProxyOperationAdminRoleAddress"
echo "ProxyRedemptionAdminMultiSigWallet: $ProxyRedemptionAdminMultiSigWalletAddress"
echo "ProxyRedemptionAdminRole: $ProxyRedemptionAdminRoleAddress"
echo "ProxySuperProtectorMultiSigWallet: $ProxySuperProtectorMultiSigWalletAddress"
echo "ProxySuperProtectorRole: $ProxySuperProtectorRoleAddress"
echo "ProxyWhitelist: $ProxyWhitelistAddress"

npx zos create Whitelist --init initialize --args "$ProxyOperationAdminMultiSigWalletAddress","$ProxyBasicProtectorMultiSigWalletAddress","$MasterPropertyValueAddress" --network="$Network"

ProxyWhitelistAddress=$(contract_proxy_address "Whitelist")
echo "ProxyWhitelist: $ProxyWhitelistAddress"

npx zos create MPVToken --init initialize --args '"Master Property Value"','"MPV"',18,"$ProxyWhitelistAddress","$MasterPropertyValueAddress","$SenderAddress","$SenderAddress","$ProxySuperProtectorMultiSigWalletAddress" --network="$Network"

ProxyMPVTokenAddress=$(contract_proxy_address "MPVToken")
echo "ProxyMPVToken: $ProxyMPVTokenAddress"

npx zos create Assets --init initialize --args 1000,"$RedemptionFeeReceiverWallet","$MintingAdminRoleAddress","$RedemptionAdminRoleAddress","$ProxyRedemptionAdminMultiSigWalletAddress","$ProxyBasicProtectorMultiSigWalletAddress","$ProxyMPVTokenAddress","$MasterPropertyValueAddress" --network="$Network"

ProxyAssetsAddress=$(contract_proxy_address "Assets")
echo "ProxyAssets: $ProxyAssetsAddress"

npx zos create SuperProtectorRole --init initialize --args "$ProxySuperProtectorMultiSigWalletAddress","$MasterPropertyValueAddress" --network="$Network"

ProxySuperProtectorRoleAddress=$(contract_proxy_address "SuperProtectorRole")

npx zos create BasicProtectorRole --init initialize --args "$ProxyBasicProtectorMultiSigWalletAddress" --network="$Network"

ProxyBasicProtectorRoleAddress=$(contract_proxy_address "BasicProtectorRole")

echo "$ProxyMintingAdminMultiSigWalletAddress"
echo "$ProxyAssetsAddress"

npx zos create MintingAdminRole --init initialize --args "$ProxyMintingAdminMultiSigWalletAddress","$ProxyAssetsAddress","$ProxyMPVTokenAddress","$ProxySuperProtectorRoleAddress","$ProxyBasicProtectorRoleAddress","$MintingReceiverWallet","$MasterPropertyValueAddress" --network="$Network"

npx zos create MasterPropertyValue --init initialize --args "$MPVTokenAddress","$ProxyAssetsAddress","$WhitelistAddress" --network="$Network"

ProxyMasterPropertyValueAddress=$(contract_proxy_address "MasterPropertyValue")

npx zos create Pausable --init initialize --network="$Network"

npx zos create RedemptionAdminRole --init initialize --args "$ProxyRedemptionAdminMultiSigWalletAddress","$ProxyBasicProtectorMultiSigWalletAddress","$ProxySuperProtectorMultiSigWalletAddress","$ProxyAssetsAddress","$ProxyMPVTokenAddress","$ProxyMasterPropertyValueAddress" --network="$Network"
