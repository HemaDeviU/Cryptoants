// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {Script} from 'forge-std/Script.sol';

import {Test, console2} from 'forge-std/Test.sol';

import {ICryptoAnts, CryptoAnts} from 'contracts/CryptoAnts.sol';
import {IEgg, Egg} from 'contracts/Egg.sol';




contract Deploy is Script {
  ICryptoAnts internal _cryptoAnts;
  address public deployer;
  IEgg internal _eggs;
  address public governor;
  address public vrfCoordinatorV2_5;

  function run() external {
    deployer = vm.rememberKey(vm.envUint('DEPLOYER_PRIVATE_KEY'));
    uint256 subscriptionId = vm.envUint('SUBSCRIPTION_ID');
    governor = vm.envAddress('GOVERNOR_ADDRESS');
    vrfCoordinatorV2_5 = vm.envAddress('VRF_COORDINATOR');
    vm.startBroadcast(deployer);
    _eggs = IEgg(computeCreateAddress(deployer, 1));
    _cryptoAnts = new CryptoAnts(address(_eggs), subscriptionId, governor, vrfCoordinatorV2_5);

    _eggs = new Egg(address(_cryptoAnts));

    vm.stopBroadcast();
  }
}
