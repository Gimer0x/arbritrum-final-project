// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { dTSLA } from "../src/dTSLA.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployDTslaScript is Script {
    string constant alpacaMintSourceCode = "./functions/sources/alpacaBalance.js";
    string constant alpacaRedeemSourceCode = "";
    uint64 public constant subId = 2287;
    function run() public {
        string memory mintSource = vm.readFile(alpacaMintSourceCode);
        vm.startBroadcast();
        dTSLA dTsla = new dTSLA(mintSource, subId, alpacaRedeemSourceCode);
        vm.stopBroadcast();
        console2.log("dTSLA deployed at address: %s", address(dTsla));  
    }
        
    
} 