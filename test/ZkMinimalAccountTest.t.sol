// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/ZkMinimalAccount.sol";
import {USDC} from "./USDC.sol"; 
import {IERC20} from "lib/foundry-era-contracts/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Transaction} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {console} from "forge-std/console.sol";



contract ZkMinimalAccountTest is Test {

    address constant USER = 0x701477467321474712bACA6779FE8926528B3c93;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    uint256 constant amountToTransfer = 5 ether;
    ZkMinimalAccount zkMinimalAccount;
    IERC20 token;
    // Transaction transaction;

    function setUp() public{
        vm.startBroadcast(msg.sender);
        zkMinimalAccount = new ZkMinimalAccount();
        token = new USDC();
        vm.stopBroadcast();
    }

    

    function testToConfirmOwner() public view {
        address expected = zkMinimalAccount.getOwner();
        assert(expected == msg.sender);
    }

    // function testMinimalAccountOwnerCanExecuteCommands1() public {
    //     // Arrange 
    //     address random = makeAddr("random");
    //     uint256 initialBalance = 10 ether;
    //     vm.startPrank(USER);
    //     vm.deal(USER, initialBalance);
    //     (bool sent,) = address(zkMinimalAccount).call{value: 1 ether}("");

    //     token.balanceOf(USER);
    //     token.approve(zkMinimalAccount.owner(), 5e18);
    //     uint num = token.allowance(USER,owner2);
        
    //     vm.stopPrank();
    //     // vm.startPrank(owner2);
    //     // token.transferFrom(USER, owner2,5e18);
    //     // vm.stopPrank();
    //     address dest = address(token);
    //     uint256 value = 0;

    //     // function allowance(address owner, address spender) external view returns (uint256);

    //     //     function transferFrom(address from, address to, uint256 amount) external returns (bool);
    //     // bytes memory functionData = abi.encodeWithSignature("transferFrom(address, address, uint256)", USER, random, 5e18);
    //     bytes memory functionData = abi.encodeWithSelector(token.transferFrom.selector, USER, owner2, 5e18);
    //     // bytes memory functionData = abi.encodeWithSelector(IERC20.transfer.selector);
    //     // bytes memory functionData = abi.encodeWithSelector(IERC20.totalSupply.selector);
    //     Transaction memory transaction = _createUnsignedTransaction(zkMinimalAccount.owner(), 113 ,dest,value,functionData );
        

    //     address owner = zkMinimalAccount.owner();
        
    //     // Act
    //     vm.prank(owner);
    //     zkMinimalAccount.executeTransactionFromOutside(transaction);

    //     // Assert
    //     uint bal1 = token.balanceOf(owner2);
    //     uint bal = token.balanceOf(USER);
    //     assertEq(bal1, bal);
    // }

        function testMinimalAccountOwnerCanExecuteCmd() public {
            // Arrange
            address random = makeAddr("random");
            address owner = zkMinimalAccount.owner();
            
            vm.prank(USER);
            token.approve(owner, 5e18);


            address dest = address(token);
            uint256 value = 0;
            // bytes memory functionData = abi.encodeWithSignature("transferFrom(address, adddress, uint256)", USER, random, 5e18);
            // bytes memory functionData = abi.encodeWithSelector(IERC20.totalSupply.selector);
            // bytes memory functionData = abi.encodeWithSelector(IERC20.transferFrom.selector, USER, random, amountToTransfer);
           bytes memory functionData = hex"23b872dd000000000000000000000000701477467321474712baca6779fe8926528b3c9300000000000000000000000042a3d6e125aad539ac15ed04e1478eb0a4dc14890000000000000000000000000000000000000000000000004563918244f40000";


            Transaction memory transaction = _createUnsignedTransaction(owner, 113, dest, value, functionData);

            // Act
            vm.prank(owner);
            zkMinimalAccount.executeTransactionFromOutside(transaction);


            //Assert
            uint bal = token.balanceOf(USER);
            uint eq = token.balanceOf(random);
            assertEq(bal, eq);
        }


        function testTokenWorkingFine() public { 
        address owner2 = zkMinimalAccount.owner();
        address random = makeAddr("random");
            vm.prank(USER);
            token.approve(random, 5e18);

            vm.startPrank(random);
            bytes memory functionData = abi.encodeWithSelector(IERC20.transferFrom.selector, USER, random, amountToTransfer);

            // console.log("jatt");
            console.logBytes(functionData);

            // address(token).call{}(functionData);
            (bool success, ) = address(token).call(functionData);
            require(success);
            vm.stopPrank();

           uint256 num = token.balanceOf(USER);
           uint256 num1 = token.balanceOf(owner2);
            assertEq(num, num1);
         }




    ///////////////////////////////////
    //    Helpers Function
    ///////////////////////////////////

    function _createUnsignedTransaction(address from, uint8 transactionType, address to, uint256 value, bytes memory _data) internal view returns (Transaction memory) {
          uint256 nonce = vm.getNonce(address(zkMinimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction ({
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
            reserved: [uint256(0),uint256(0),uint256(0),uint256(0)],
            data: _data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""



        });
    }
}


/** Multiple issues
    write function wouldn't work

    validation is not working 

 */


 // 0x23b872dd000000000000000000000000701477467321474712baca6779fe8926528b3c9300000000000000000000000042a3d6e125aad539ac15ed04e1478eb0a4dc14890000000000000000000000000000000000000000000000004563918244f40000

//  0xfb8f41b2000000000000000000000000b730f1c602804a67b453a3d28e8cc4ed0a7ef90b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004563918244f40000

// 0x23b872dd000000000000000000000000701477467321474712baca6779fe8926528b3c9300000000000000000000000042a3d6e125aad539ac15ed04e1478eb0a4dc14890000000000000000000000000000000000000000000000004563918244f40000


// token = 0x23b872dd000000000000000000000000701477467321474712baca6779fe8926528b3c9300000000000000000000000042a3d6e125aad539ac15ed04e1478eb0a4dc14890000000000000000000000000000000000000000000000004563918244f40000
// sent  = 0x23b872dd000000000000000000000000701477467321474712baca6779fe8926528b3c9300000000000000000000000042a3d6e125aad539ac15ed04e1478eb0a4dc14890000000000000000000000000000000000000000000000004563918244f40000
// reci  = 0xfb8f41b2000000000000000000000000b730f1c602804a67b453a3d28e8cc4ed0a7ef90b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004563918244f40000
