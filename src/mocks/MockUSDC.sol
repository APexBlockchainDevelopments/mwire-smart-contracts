// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals()); // Mint 1M USDC to deployer
    }

    function mint(address _receiver, uint256 _amount) public {
        _mint(_receiver, _amount);
    }
}