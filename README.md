# WETH10 CTF Challenge Repository

This repository contains the challenge's POC, the WETH10 contract is vulnerable to reentrancy attacks due to insufficient protection in its withdrawAll() function. The vulnerability allows attackers to drain the contract of its tokens using a specific set of steps.

## Contents

`./src/Attacker.sol`: Contains the exploit code that allows an attacker to exploit the vulnerability in the WETH10 contract.``
`./src/weth10.sol`: Contains the WETH10 contract, which is vulnerable to reentrancy attacks.
`./test/weth10.t.sol`: Contains the test cases that demonstrate the vulnerability in the WETH10 contract.

## Vulnerability

The `withdrawAll()` function in WETH10 is vulnerable to reentrancy attacks because it does not provide the necessary protection even though it uses a reentrancy guard. The `nonReentrant` modifier is used to prevent the same function from being called again within the same transaction, but other functions like `ERC20._transfer()`, `ERC20.transfer()`, and `ERC20.transferFrom()` which are not protected by the `nonReentrant` modifier can still be used to perform reentrant attacks.

Here is the vulnerable function:

    function withdrawAll() external nonReentrant {   
        Address.sendValue(payable(msg.sender), balanceOf(msg.sender));    
        burnAll();
    }
  
This function performs an external call, which can be used by an attacker contract to transfer tokens from their wallet before `_burnAll()` is called.

## Attacker Steps

The attacker deploys a contract with an `exploit()` function which:

1. Calls `WETH10.deposit()` to deposit 1 ether.
2. Calls `WETH10.withdrawAll()` to withdraw 1 ether.
3. Sends ether to the attacker contract to trigger the `fallback()` function which transfers all WETH10 tokens in the contract to an external address owned by the attacker.
4. After the `fallback()` function returns, `WETH10._burnAll()` is called, which burns the token balance inside the attacker contract, but since all tokens have been transferred out, it burns none of them.
5. The attacker pulls back the tokens from the attacker contract.
6. The attacker repeats steps 2 to 5 until all tokens are drained.

## Mitigation

To mitigate this vulnerability, developers should carefully consider their use of reentrancy guards and ensure that all relevant functions are protected. As a community, it's important that we continue to share information and best practices to build a more secure and reliable blockchain ecosystem.

## How to run tests

Inside the repo's main folder, run `forge test`

