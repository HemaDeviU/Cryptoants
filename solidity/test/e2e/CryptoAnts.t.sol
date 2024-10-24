// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'contracts/CryptoAnts.sol';
import {IEgg, Egg} from 'contracts/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';
import {console} from 'forge-std/console.sol';

contract E2ECryptoAnts is Test, TestUtils {
  uint256 internal constant FORK_BLOCK = 17_052_487;
  ICryptoAnts internal _cryptoAnts;
  address internal _owner = makeAddr('owner');
  IEgg internal _eggs;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    _eggs = IEgg(addressFrom(address(this), 1));
    _cryptoAnts = new CryptoAnts(address(_eggs));
    _eggs = new Egg(address(_cryptoAnts));
  }

  function testOnlyAllowCryptoAntsToMintEggs() public {}
  function testBuyAnEggAndCreateNewAnt() public {}
  function testSendFundsToTheUserWhoSellsAnts() public {}
  function testBurnTheAntAfterTheUserSellsIt() public {}

  /*
    This is a completely optional test.
    Hint: you may need `warp` to handle the egg creation cooldown
  */
  function testBeAbleToCreate100AntsWithOnlyOneInitialEgg() public {}
}
