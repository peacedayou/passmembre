// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {PassMembre} from "../src/PassMembre.sol";

/// ADMIN=0x... BASE_URI=https://.../ forge script script/Deploy.s.sol --rpc-url $RPC_URL --account deployer --broadcast
contract Deploy is Script {
    function run() external returns (PassMembre p) {
        vm.startBroadcast();
        p = new PassMembre("PassMembre", "PASS", vm.envString("BASE_URI"), vm.envAddress("ADMIN"));
        vm.stopBroadcast();
        console.log("PassMembre:", address(p));
    }
}
