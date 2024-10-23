// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/ZkMinimalAccount.sol";
// import {USDC} from "./USDC.sol";
import {Mock} from "./mocks/Mock.sol";
import {IERC20} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Transaction} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {console} from "forge-std/console.sol";

contract ZkMinimalAccountTest is Test {
    uint256 constant AMOUNT = 1e18;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address owner;

    ZkMinimalAccount zkMinimalAccount;
    Mock store;
    ERC20Mock token;

    function setUp() public {
        zkMinimalAccount = new ZkMinimalAccount();
        zkMinimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);

        store = new Mock();
        token = new ERC20Mock();
        vm.deal(address(zkMinimalAccount), AMOUNT);
        owner = zkMinimalAccount.owner();
    }

    function testingZk() public {
        // Arrange
        address dest = address(store);
        uint256 value = 0;
        // bytes memory functionData = abi.encodeWithSignature("getNumber()");
        bytes memory functionData = abi.encodeWithSignature("updateNumber(uint256)", 50);

        Transaction memory _transaction = _createUnsignedTransaction(owner, 113, dest, value, functionData);

        // Act
        vm.prank(owner);
        zkMinimalAccount.executeTransactionFromOutside(_transaction);

        // Assert
        uint256 actual = store.getNumber();
        uint256 expected = 50;
        assertEq(actual, expected);
    }

    function testAccountOwnerCanExecuteCmd() public {
        // Arrange
        address dest = address(token);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

        Transaction memory _transaction = _createUnsignedTransaction(owner, 113, dest, value, functionData);

        // Act
        vm.prank(owner);
        zkMinimalAccount.executeTransactionFromOutside(_transaction);

        // Assert
        assertEq(token.balanceOf(address(zkMinimalAccount)), AMOUNT);
    }

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory _data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(zkMinimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType, // type 113 (0x71)
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: _data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}
