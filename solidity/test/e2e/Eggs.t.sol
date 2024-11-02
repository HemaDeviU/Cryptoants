pragma solidity 0.8.20;

import {Test, console2} from 'forge-std/Test.sol';
import {Vm} from 'forge-std/Vm.sol';
import {Egg} from 'solidity/contracts/Egg.sol';
contract EggTest is Test {
    Egg public egg;
    address public owner;
    address public user1;
    address public user2;
    uint256 public constant INITIAL_AMOUNT = 1000;


    function setUp() public {
        owner = makeAddr("owner");
        user1 =makeAddr("user1");
        user2 =makeAddr("user2");
        vm.prank(owner);
        egg = new Egg(owner);
    }
   function test_state() public view {
    assertEq(egg.owner(),owner);
    assertEq(egg.I_ANTS(),owner);
   }
   function test_Mint() public {
    vm.startPrank(owner);
    egg.mint(user1, INITIAL_AMOUNT);
        assertEq(egg.balanceOf(user1), INITIAL_AMOUNT);
        vm.stopPrank();
    

   }
   function test_BurnEgg() public {
    vm.prank(owner);
    egg.mint(user1, INITIAL_AMOUNT);
    vm.prank(owner);
    egg.burnEgg(user1, 10);
    assertEq(egg.balanceOf(user1), INITIAL_AMOUNT -10);
   }
}