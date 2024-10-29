// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test, console2} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'contracts/CryptoAnts.sol';
import {IEgg, Egg} from 'contracts/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';
import {console} from 'forge-std/console.sol';
import {Vm} from 'forge-std/Vm.sol';

contract E2ECryptoAnts is Test, TestUtils {
  uint256 internal constant FORK_BLOCK = 17_052_487;
  ICryptoAnts internal _cryptoAnts;
  address internal _owner = makeAddr('owner');
  address internal _user1 = makeAddr('user1');
  address internal _user2 = makeAddr('user2');
  IEgg internal _eggs;
  uint256 public subscriptionId;
  address public governor;
  uint256 public constant STARTING_USER_BALANCE = 10 ether;
  uint256 public constant EGG_PRICE = 1 ether;
  uint256 public constant COOLDOWN_PERIOD = 10 minutes;

  function setUp() public {
    // string memory rpcurl = vm.envString('MAINNET_RPC');
    //vm.createSelectFork(rpcurl, FORK_BLOCK);
    _eggs = IEgg(addressFrom(address(this), 1));
    subscriptionId = vm.envUint('SUBSCRIPTION_ID');
    governor = vm.envAddress('GOVERNOR_ADDRESS');
    _cryptoAnts = new CryptoAnts(address(_eggs), subscriptionId, governor);
    _eggs = new Egg(address(_cryptoAnts));
    vm.deal(_user1, STARTING_USER_BALANCE);
    vm.deal(_user2, STARTING_USER_BALANCE);
  }

  function testOnlyAllowCryptoAntsToMintEggs() public {
    vm.prank(_user1);
    vm.expectRevert();
    _eggs.mint(_user1, 1);
    uint256 initialBalance = _eggs.balanceOf(_user1);
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: 1 ether}(1);
    assertEq(_eggs.balanceOf(_user1), initialBalance + 1, 'Egg should be minted by CryptoAnts contract');
    vm.stopPrank();
  }

  function testBuyAnEggAndCreateNewAnt() public {
    vm.prank(_user1);
    vm.expectRevert();
    _eggs.mint(_user1, 1);

    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.balanceOf(_user1), 1, 'User should own the ant');
    vm.stopPrank();
    //check burn
  }

  function testSendFundsToTheUserWhoSellsAnts() public {
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.balanceOf(_user1), 1, 'User should own the ant');
    uint256 initialUserBalance = _user1.balance;
    _cryptoAnts.sellAnt(_antId);
    assertEq(_user1.balance, initialUserBalance + _cryptoAnts.getAntPrice(), 'User1 should receive the ant sale price');
    vm.stopPrank();
  }

  function testBurnTheAntAfterTheUserSellsIt() public {
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.balanceOf(_user1), 1, 'User1 should own the ant');
    _cryptoAnts.sellAnt(_antId);
    assertEq(_cryptoAnts.balanceOf(_user1), 0, 'User1 should no longer own any ants');
    vm.expectRevert('Ant does not exist');
    _cryptoAnts.ownerOf(_antId);

    vm.stopPrank();
  }

  /*
    This is a completely optional test.
    Hint: you may need `warp` to handle the egg creation cooldown
  */
  function testBeAbleToCreate100AntsWithOnlyOneInitialEgg() public {
    vm.startPrank(_user2);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    _cryptoAnts.createAnt();
    while (_cryptoAnts.balanceOf(_user2) < 100) {
      vm.warp(block.timestamp + 10 minutes);
      _cryptoAnts.createAnt();
    }
    assertEq(_cryptoAnts.balanceOf(_user2), 100, 'User2 should have 100 ants');
    vm.stopPrank();
  }

  function testLayEggs() public {
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    vm.recordLogs();
    uint256 reqId = _cryptoAnts.layEggs(_antId);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    bytes32 requestId = entries[1].topics[1];
    assert(uint256(requestId) > 0);
  }

  function testFulillRandomness() public {
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    vm.recordLogs();
    uint256 reqId = _cryptoAnts.layEggs(_antId);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    console2.logBytes32(entries[1].topics[1]);
    bytes32 requestId = entries[1].topics[1];
  }
}
