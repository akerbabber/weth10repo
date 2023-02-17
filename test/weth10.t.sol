pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/weth10.sol";
import "../src/Attacker.sol";

contract Weth10Test is Test {
    WETH10 public weth;
    Attacker public attacker;
    address owner;
    address bob;

    function setUp() public {
        weth = new WETH10();
        bob = makeAddr("bob");
        attacker = new Attacker(payable(address(weth)), payable(bob));

        vm.deal(address(weth), 10 ether);
        vm.deal(address(bob), 1 ether);
    }

    function testHack() public {
        assertEq(
            address(weth).balance,
            10 ether,
            "weth contract should have 10 ether"
        );

        vm.startPrank(bob);

        // hack time!
        weth.approve(address(attacker), 11 ether);
        attacker.exploit{value:1 ether}();


        vm.stopPrank();
        console.logUint(address(weth).balance);
        assertEq(address(weth).balance, 0, "empty weth contract");
        assertEq(bob.balance, 11 ether, "player should end with 11 ether");
    }
}
