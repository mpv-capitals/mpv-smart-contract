#!/bin/bash

set -e
set -u
set -o pipefail

# check that `jq` command exists
if ! type "jq" > /dev/null; then
  printf "%s\n%s" "\"jq\" command is required." "sudo apt-get install jq"
  return
fi

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

read_var() {
  VAR=$(grep $1 $2 | xargs)
  IFS="=" read -ra VAR <<< "$VAR"
  echo ${VAR[1]}
}

Network="$nvalue"
if [ -z "$nvalue" ]; then
  Network="development"
fi

ZosFile="$fvalue"
if [ -z "$fvalue" ]; then
  # get zos file if exists
  #ZosFile=$(ls | grep ^zos..*.json | tr -d '[:cntrl:]'| perl -pe 's/\[[0-9;]*[mGKF]//g')
  ZosFile="zos.$Network.json"
fi

contract_proxy_address() {
  cat "$ZosFile" | jq ".proxies[\"master-property-value/$1\"][0].address" | sed -e 's/"//g'
}

echo "$Network"
echo "$ZosFile"

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

echo "Pushing new logic contracts..."

# push new code to network
npx zos push --network="$Network"

echo "Updating proxies..."

# update existing contract
npx zos update MPVToken --network="$Network"
