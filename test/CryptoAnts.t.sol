// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test, console2} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from '../src/CryptoAnts.sol';
import {IEgg, Egg} from '../src/Egg.sol';
import {TestUtils} from './utils/TestUtils.sol';
import {console} from 'forge-std/console.sol';
import {Vm} from 'forge-std/Vm.sol';
import {VRFCoordinatorV2_5Mock} from '@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol';
//import {LinkToken} from "../test/mocks/LinkToken.sol";

contract TestCryptoAnts is Test, TestUtils {
  //uint256 internal constant FORK_BLOCK = 17_052_487;
  ICryptoAnts internal _cryptoAnts;
  address internal owner = makeAddr('owner');
  address internal _user1 = makeAddr('user1');
  address internal _user2 = makeAddr('user2');
  IEgg internal _eggs;
  uint256 public subscriptionId;
  address public governor;
  uint256 public constant STARTING_USER_BALANCE = 200 ether;
  uint256 public constant EGG_PRICE = 0.01 ether;
  uint256 public constant COOLDOWN_PERIOD = 10 minutes;
  address vrfCoordinatorV2_5;

  function setUp() public {
    //string memory rpcurl = vm.envString('MAINNET_RPC');
    //vm.createSelectFork(rpcurl, FORK_BLOCK);
    vm.deal(owner, STARTING_USER_BALANCE);
    vm.startPrank(owner);
    VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(0.25 ether, 1e9, 4e15);
    vrfCoordinatorV2_5 = address(vrfCoordinatorV2_5Mock);
    subscriptionId = vrfCoordinatorV2_5Mock.createSubscription();
    
    vrfCoordinatorV2_5Mock.fundSubscription(subscriptionId, 100 ether);
      governor = vm.envAddress('GOVERNOR_ADDRESS');
    console.log("Governor address:", governor);

   // _eggs = IEgg(addressFrom(address(this), 1));
    uint256 ownerNonce = vm.getNonce(owner);
   address predictedAddress = addressFrom(owner,ownerNonce+1);
   _eggs = IEgg(predictedAddress);
   
    _cryptoAnts = new CryptoAnts(address(_eggs), subscriptionId, governor, address(vrfCoordinatorV2_5));  
    _eggs = new Egg(address(_cryptoAnts));

   
    vrfCoordinatorV2_5Mock.addConsumer(subscriptionId, address(_cryptoAnts));
    assertEq(address(_eggs),predictedAddress);
    vm.stopPrank();
    vm.deal(_user1, STARTING_USER_BALANCE);
    vm.deal(_user2, STARTING_USER_BALANCE);
  }

  function testDontOnlyAllowCryptoAntsToMintEggs() public {
    vm.startPrank(_user1);
    vm.expectRevert();
    _eggs.mint(_user1, 1);
    vm.stopPrank();

  }
  function testOnlyAllowCryptoAntsToMintEggs() public {

    uint256 initialBalance = _eggs.balanceOf(_user1);
    vm.prank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
   // vm.stopPrank();
    assertEq(_eggs.balanceOf(_user1), initialBalance + 1, 'Egg should be minted by CryptoAnts contract');
  }

  function testBuyAnEggAndCreateNewAnt() public {
    
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
    _cryptoAnts.sellAnt(_antId,3000000000000000);
    assertEq(_user1.balance, initialUserBalance + 3000000000000000, 'User1 should receive the ant sale price');
    vm.stopPrank();
  }

  function testBurnTheAntAfterTheUserSellsIt() public {
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    assertEq(_cryptoAnts.balanceOf(_user1), 1, 'User1 should own the ant');
    _cryptoAnts.sellAnt(_antId,4000000000000000);
    assertEq(_cryptoAnts.balanceOf(_user1), 0, 'User1 should no longer own any ants');
    vm.expectRevert();
    _cryptoAnts.ownerOf(_antId);

    vm.stopPrank();
  }

  /*
    This is a completely optional test.
    Hint: you may need `warp` to handle the egg creation cooldown
  
  function testBeAbleToCreate100AntsWithOnlyOneInitialEgg() public {
    address _user4 = makeAddr('user4');
    vm.startPrank(_user4);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    vm.warp(block.timestamp + 10 minutes);
    _cryptoAnts.createAnt();
    while (_cryptoAnts.balanceOf(_user4) < 100) {
      uint256 currentAntBal = _cryptoAnts.balanceOf(_user4);
      for(uint i=0; i< currentAntBal; i++)
      {
      _cryptoAnts.layEggs(_antId); //retriv?
      vm.warp(block.timestamp + 10 minutes);
      _cryptoAnts.createAnt();
    } 
    }
    assertEq(_cryptoAnts.balanceOf(_user4), 100, 'User4 should have 100 ants');
    vm.stopPrank();
  } */


  function testLayEggs() public {
    vm.startPrank(_user1);
    uint256 initialEggBalance = _eggs.balanceOf(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    uint256 EggBalanceAfterBuy = _eggs.balanceOf(_user1);
    assertEq(_eggs.balanceOf(_user1), initialEggBalance + 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    vm.recordLogs();
    Vm.Log[] memory entries = vm.getRecordedLogs();
    //bytes32 requestId = entries[1].topics[1];
    uint256 requestId = _cryptoAnts.layEggs(_antId);
    assert(uint256(requestId) > 0);
  }

  function testFulillRandomnessAntDies() public {
    vm.startPrank(_user1);
    uint256 initialEggBalance = _eggs.balanceOf(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    uint256 EggBalanceAfterEggBuy = _eggs.balanceOf(_user1);
    console.log('EggBalanceAfterEggBuy is :',EggBalanceAfterEggBuy);
    uint256 _antId = _cryptoAnts.createAnt();
    uint256 EggBalanceAfterCreateAnt = _eggs.balanceOf(_user1);
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    vm.recordLogs();
    uint256 reqId = _cryptoAnts.layEggs(_antId);
    Vm.Log[] memory entries = vm.getRecordedLogs();
   // console2.logBytes32(entries[0].topics[1]);
    //bytes32 requestId = entries[0].topics[1];

    uint256[] memory randomWords = new uint256[](2);
    randomWords[0] = 4;
    randomWords[1] = 3;
    VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWordsWithOverride(reqId, address(_cryptoAnts), randomWords);
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    vm.expectRevert();
    _cryptoAnts.layEggs(_antId);
    vm.stopPrank();
  }

  function testFulillRandomnessAntLives() public {
    vm.startPrank(_user1);
    _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
    assertEq(_eggs.balanceOf(_user1), 1, 'User1 should own the eggs');
    uint256 _antId = _cryptoAnts.createAnt();
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    vm.recordLogs();
    uint256 reqId = _cryptoAnts.layEggs(_antId);
    Vm.Log[] memory entries = vm.getRecordedLogs();
    //console2.logBytes32(entries[1].topics[1]);
    //bytes32 requestId = entries[1].topics[1];
    uint256[] memory randomWords2 = new uint256[](2);
    randomWords2[0] = 10;
    randomWords2[1] = 8;
    VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWordsWithOverride(reqId, address(_cryptoAnts), randomWords2);
    vm.warp(block.timestamp + COOLDOWN_PERIOD);
    _cryptoAnts.layEggs(_antId);
    assertEq(_eggs.balanceOf(_user1), 8, 'user1 should have 8 eggs now');
    assertTrue(_cryptoAnts.isAlive(_antId), 'Ant should still be alive');
    vm.stopPrank();
  }
    function testBuyEgg() public {
        //vm.prank(_cryptoAnts,_user1);
            vm.prank(_user1);

        _cryptoAnts.buyEggs{value: EGG_PRICE}(1);
        assertEq(_eggs.balanceOf(_user1), 1, "User should own 1 egg after purchase");
    }
}
