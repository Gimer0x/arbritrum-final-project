-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil scopefile deploy-bridges

deploy :; forge script script/DeployDTsla.s.sol:DeployDTslaScript \ 
--sender {$PUBLIC_KEY} \
--account defaultKey \
--rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} \
--priority-gas-price 1 \
--broadcast


test :; forge test