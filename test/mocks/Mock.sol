// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Mock {
    uint256 private number;

    function updateNumber(uint256 _num) public {
        number = _num;
    }

    function getNumber() public view returns (uint256) {
        return number;
    }
}
