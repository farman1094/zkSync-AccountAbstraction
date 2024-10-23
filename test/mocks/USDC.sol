// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    address constant USER = 0x701477467321474712bACA6779FE8926528B3c93;

    constructor() ERC20("USDC", "USDC") {
        _mint(USER, 10e18);
    }
}
