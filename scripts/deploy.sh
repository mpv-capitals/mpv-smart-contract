#!/bin/sh

# ganache test keys
# 0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1
# 0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d

# Example usage
# $ ./deploy.sh zos.dev-1554994902267.json

# == CONFIG ==

ZosFile="$1"
if [ -z "$1" ]; then
  # get zos file if exists
  ZosFile=$(ls | grep zos.dev-*.json | tr -d '[:cntrl:]'| perl -pe 's/\[[0-9;]*[mGKF]//g')
fi

Network=development
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
BasicOwnerMultiSigWalletAddress=$(contract_address "BasicOwnerMultiSigWallet")
BasicOwnerRoleAddress=$(contract_address "BasicOwnerRole")
MasterPropertyValueAddress=$(contract_address "MasterPropertyValue")
MintingAdminMultiSigWalletAddress=$(contract_address "MintingAdminMultiSigWallet")
MintingAdminRoleAddress=$(contract_address "MintingAdminRole")
MPVTokenAddress=$(contract_address "MPVToken")
OperationAdminMultiSigWalletAddress=$(contract_address "OperationAdminMultiSigWallet")
OperationAdminRoleAddress=$(contract_address "OperationAdminRole")
RedemptionAdminMultiSigWalletAddress=$(contract_address "RedemptionAdminMultiSigWallet")
RedemptionAdminRoleAddress=$(contract_address "RedemptionAdminRole")
SuperOwnerMultiSigWalletAddress=$(contract_address "SuperOwnerMultiSigWallet")
SuperOwnerRoleAddress=$(contract_address "SuperOwnerRole")
WhitelistAddress=$(contract_address "Whitelist")

echo "Network: $Network"
echo "zos: $ZosFile"
echo "Assets: $AssetsAddress"
echo "BasicOwnerMultiSigWallet: $BasicOwnerMultiSigWalletAddress"
echo "BasicOwnerRole: $BasicOwnerRoleAddress"
echo "MasterPropertyValue: $MasterPropertyValueAddress"
echo "MintingAdminMultiSigWallet: $MintingAdminMultiSigWalletAddress"
echo "MintingAdminRole: $MintingAdminRoleAddress"
echo "MPVToken: $MPVTokenAddress"
echo "OperationAdminMultiSigWallet: $OperationAdminMultiSigWalletAddress"
echo "OperationAdminRole: $OperationAdminRoleAddress"
echo "RedemptionAdminMultiSigWallet: $RedemptionAdminMultiSigWalletAddress"
echo "RedemptionAdminRole: $RedemptionAdminRoleAddress"
echo "SuperOwnerMultiSigWallet: $SuperOwnerMultiSigWalletAddress"
echo "SuperOwnerRole: $SuperOwnerRoleAddress"
echo "Whitelist: $WhitelistAddress"

# == INITIALIZERS ==

# npx zos push --network=development

npx zos create SuperOwnerMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network" --from="$SenderAddress"
npx zos create BasicOwnerMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"
npx zos create MintingAdminMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"
npx zos create OperationAdminMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"
npx zos create RedemptionAdminMultiSigWallet --init initialize --args ["$SenderAddress"],1 --network="$Network"


ProxyAssetsAddress=$(contract_proxy_address "Assets")
ProxyBasicOwnerMultiSigWalletAddress=$(contract_proxy_address "BasicOwnerMultiSigWallet")
ProxyBasicOwnerRoleAddress=$(contract_proxy_address "BasicOwnerRole")
ProxyMasterPropertyValueAddress=$(contract_proxy_address "MasterPropertyValue")
ProxyMintingAdminMultiSigWalletAddress=$(contract_proxy_address "MintingAdminMultiSigWallet")
ProxyMintingAdminRoleAddress=$(contract_proxy_address "MintingAdminRole")
ProxyMPVTokenAddress=$(contract_proxy_address "MPVToken")
ProxyOperationAdminMultiSigWalletAddress=$(contract_proxy_address "OperationAdminMultiSigWallet")
ProxyOperationAdminRoleAddress=$(contract_proxy_address "OperationAdminRole")
ProxyRedemptionAdminMultiSigWalletAddress=$(contract_proxy_address "RedemptionAdminMultiSigWallet")
ProxyRedemptionAdminRoleAddress=$(contract_proxy_address "RedemptionAdminRole")
ProxySuperOwnerMultiSigWalletAddress=$(contract_proxy_address "SuperOwnerMultiSigWallet")
ProxySuperOwnerRoleAddress=$(contract_proxy_address "SuperOwnerRole")
ProxyWhitelistAddress=$(contract_proxy_address "Whitelist")

echo "ProxyNetwork: $ProxyNetwork"
echo "Proxyzos: $ProxyZosFile"
echo "ProxyAssets: $ProxyAssetsAddress"
echo "ProxyBasicOwnerMultiSigWallet: $ProxyBasicOwnerMultiSigWalletAddress"
echo "ProxyBasicOwnerRole: $ProxyBasicOwnerRoleAddress"
echo "ProxyMasterPropertyValue: $ProxyMasterPropertyValueAddress"
echo "ProxyMintingAdminMultiSigWallet: $ProxyMintingAdminMultiSigWalletAddress"
echo "ProxyMintingAdminRole: $ProxyMintingAdminRoleAddress"
echo "ProxyMPVToken: $ProxyMPVTokenAddress"
echo "ProxyOperationAdminMultiSigWallet: $ProxyOperationAdminMultiSigWalletAddress"
echo "ProxyOperationAdminRole: $ProxyOperationAdminRoleAddress"
echo "ProxyRedemptionAdminMultiSigWallet: $ProxyRedemptionAdminMultiSigWalletAddress"
echo "ProxyRedemptionAdminRole: $ProxyRedemptionAdminRoleAddress"
echo "ProxySuperOwnerMultiSigWallet: $ProxySuperOwnerMultiSigWalletAddress"
echo "ProxySuperOwnerRole: $ProxySuperOwnerRoleAddress"
echo "ProxyWhitelist: $ProxyWhitelistAddress"

npx zos create Whitelist --init initialize --args "$ProxyOperationAdminMultiSigWalletAddress","$ProxyBasicOwnerMultiSigWalletAddress","$MasterPropertyValueAddress" --network="$Network"

npx zos create MPVToken --init initialize --args '"Master Property Value"','"MPV"',18,"$ProxyWhitelistAddress","$MasterPropertyValueAddress","$MintingAdminRoleAddress","$RedemptionAdminRoleAddress","$ProxySuperOwnerMultiSigWalletAddress" --network="$Network"

npx zos create Assets --init initialize --args 1000,"$RedemptionFeeReceiverWallet","$MintingAdminRoleAddress","$RedemptionAdminRoleAddress","$ProxyRedemptionAdminMultiSigWalletAddress","$ProxyBasicOwnerMultiSigWalletAddress","$MPVTokenAddress","$MasterPropertyValueAddress" --network="$Network"

npx zos create SuperOwnerRole --init initialize --args "$ProxySuperOwnerMultiSigWalletAddress","$MasterPropertyValueAddress" --network="$Network"

npx zos create BasicOwnerRole --init initialize --args "$ProxyBasicOwnerMultiSigWalletAddress","$MintingAdminRoleAddress" --network="$Network"

npx zos create MintingAdminRole --init initialize --args "$ProxyMintingAdminMultiSigWalletAddress","$AssetsAddress","$MPVTokenAddress","$SuperOwnerRoleAddress","$BasicOwnerRoleAddress","$MintingReceiverWallet","$MasterPropertyValueAddress" --network="$Network"

npx zos create MasterPropertyValue --init initialize --args "$MPVTokenAddress","$AssetsAddress","$WhitelistAddress" --network="$Network"

npx zos create Pausable --init initialize --network="$Network"

npx zos create RedemptionAdminRole --init initialize --args "$ProxyRedemptionAdminMultiSigWalletAddress","$ProxyBasicOwnerMultiSigWalletAddress","$AssetsAddress","$MPVTokenAddress","$MasterPropertyValueAddress" --network="$Network"
