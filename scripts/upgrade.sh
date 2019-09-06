#!/bin/bash

ZosFile="zos.rinkeby.json"
Network=rinkeby

contract_proxy_address() {
  cat "$ZosFile" | jq ".proxies[\"master-property-value/$1\"][0].address" | sed -e 's/"//g'
}

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

# push new code to network
npx zos push --network="$Network" --force

# update existing contract
npx zos update MPVToken --network="$Network"
