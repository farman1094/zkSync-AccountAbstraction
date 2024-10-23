// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// zkSync Era imports
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Utils} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

// Open-Zeppelin
import {ECDSA} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
// import {MessageHashUtils} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * Lifecycle of a type 113 (0x71) transaction
 * msg.sender is the bootloader system contract
 *
 * Phase 1 Validation
 * 1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
 * 2. The zkSync API client checks to see the the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTransaction, which MUST update the nonce
 * 4. The zkSync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 * Phase 2 Execution
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
 * 8. The main node calls executeTransaction
 * 9. If a paymaster was used, the postTransaction is called
 */
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__ValidationFailed();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__BootLoaderPaymentFailed();

    constructor() Ownable(msg.sender) {}

    // so the contract can recieve fund.
    receive() external payable {}

    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    /* //////////////////////////////////////// 
                Externals Functions
    //////////////////////////////////////// */

    /**
     * @notice must increase the nonce
     * @notice must validate the transaction (check the owner signed the transaction)
     * @notice also check if we have enough money for transaction
     */
    function validateTransaction(
        bytes32, /*_txHash*/
        bytes32, /* _suggestedSignedHash */
        Transaction calldata _transaction
    ) external payable requireFromBootLoader returns (bytes4 magic) {
        magic = _validateTransaction(_transaction);
        if (magic == bytes4(0)) revert ZkMinimalAccount__ValidationFailed();
        return magic;
    }

    function executeTransaction(
        bytes32, /*_txHash*/
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
    }

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) revert ZkMinimalAccount__ValidationFailed();
        _executeTransaction(_transaction);
    }

    function payForTransaction(
        bytes32, /*_txHash*/
        bytes32, /* _suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__BootLoaderPaymentFailed();
        }
    }

    /**
     * @notice Ignoring
     */
    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    /* //////////////////////////////////////// 
                Internals Function
     //////////////////////////////////////// */

    function _validateTransaction(Transaction calldata _transaction) internal returns (bytes4 magic) {
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // check for the fee to pay
        uint256 totalRequiredBal = _transaction.totalRequiredBalance();
        if (totalRequiredBal > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // check for signature
        bytes32 transactionHash = _transaction.encodeHash();
        address signer = ECDSA.recover(transactionHash, _transaction.signature);
        console.log(signer);
        // if(verifier == )
        bool isValid = signer == owner();

        // return the magic number\
        if (isValid) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }

    function _executeTransaction(Transaction calldata _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        // confirm if contract is interacting with system contract or normal contract
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }

    /* //////////////////////////////////////// 
                Getters Function
    //////////////////////////////////////// */
    function getOwner() public view returns (address) {
        return owner();
    }
}
