// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ZkMinimalAccount} from "src/ZkMinimalAccount.sol";
import {Mock} from "./mocks/Mock.sol";

// Openzeppelin
import {IERC20} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MessageHashUtils} from
    "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

// system
import {BOOTLOADER_FORMAL_ADDRESS} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";

contract ZkMinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    uint256 constant AMOUNT = 1e18;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant ANVIL_DEFAULT_ACCOUNT_PKEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);

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

    function testNonOwnerCanNotExecuteCommand() public {
        // Arrange
        address random = makeAddr("random");
        address dest = address(store);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSignature("updateNumber(uint256)", 50);

        Transaction memory _transaction = _createUnsignedTransaction(owner, 113, dest, value, functionData);

        // Act / Assert
        vm.prank(random);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderOrOwner.selector);
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, _transaction);
    }

    function testingZk() public {
        // Arrange
        address dest = address(store);
        uint256 value = 0;
        // bytes memory functionData = abi.encodeWithSignature("getNumber()");
        bytes memory functionData = abi.encodeWithSignature("updateNumber(uint256)", 50);

        Transaction memory _transaction = _createUnsignedTransaction(owner, 113, dest, value, functionData);
        _transaction = _signTransaction(_transaction);
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
        _transaction = _signTransaction(_transaction);

        // Act
        vm.prank(owner);
        zkMinimalAccount.executeTransactionFromOutside(_transaction);

        // Assert
        assertEq(token.balanceOf(address(zkMinimalAccount)), AMOUNT);
    }

    function testValidateTransaction() public {
        // Arrange
        address dest = address(token);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(zkMinimalAccount), AMOUNT);

        Transaction memory transaction = _createUnsignedTransaction(owner, 113, dest, value, functionData);
        transaction = _signTransaction(transaction);

        // Act
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assert(magic == ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /////////////////////////////////////
    //          Helper Function         /
    /////////////////////////////////////
    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        // Get a hash
        bytes32 unSignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        // bytes32 digest = unSignedTransactionHash.toEthSignedMessageHash();
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_ACCOUNT_PKEY, unSignedTransactionHash);
        Transaction memory signedTrasaction = transaction;
        signedTrasaction.signature = abi.encodePacked(r, s, v);

        return signedTrasaction;
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
