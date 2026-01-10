/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/VaultMultisig.sol";
import "forge-std/console.sol";

contract VaultMultisigTest is Test {
    VaultMultisig vault;
    uint256 quorum = 2;

    address[] signers;

    address signer1 = vm.addr(1);
    address signer2 = vm.addr(2);
    address signer3 = vm.addr(3);
    address defaultRecipient = vm.addr(999);
    address stranger = vm.addr(777);

    function setUp() public {
        signers.push(signer1);
        signers.push(signer2);
        signers.push(signer3);

        vault = new VaultMultisig(signers, quorum);
    }

    function test_InitiateTransferRevertsContractNoFunds(address _randomAddress) public {
        vm.assume(_randomAddress != address(0));
        vm.prank(signer1);
        vm.expectRevert(VaultMultisig.VaultIsEmpty.selector);

        vault.initiateTransfer(_randomAddress, 1 wei);
    }

    function test_InitiateTransferRevertsInvalidRecipient() public {
        address recipient = address(0);
        vm.prank(signer1);
        vm.expectRevert(VaultMultisig.InvalidRecipient.selector);

        vault.initiateTransfer(recipient, 1 wei);
    }

    function test_InitiateTransferRevertsInvalidAmount(address _randomAddress) public {
        vm.assume(_randomAddress != address(0));
        vm.prank(signer1);
        vm.expectRevert(VaultMultisig.InvalidAmount.selector);

        vault.initiateTransfer(_randomAddress, 0);
    }

    function test_InitiateTransferWorks(address _randomAddress) public {
        vm.assume(_randomAddress != address(0));
        fundVault(1 ether);

        vm.expectEmit(true, true, false, true);
        emit VaultMultisig.TransferInitiated(0, _randomAddress, 1 ether);

        vm.prank(signer1);
        vault.initiateTransfer(_randomAddress, 1 ether);

        (address to, uint256 amount, uint256 approvals, bool executed) = vault.getTransfer(0);

        assertEq(to, _randomAddress);
        assertEq(amount, 1 ether);
        assertEq(approvals, 1);
        assertFalse(executed);
    }

    function test_ApproveTransferWorks() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        // 1st try to approve
        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.SignerAlreadyApproved.selector, signer1));
        vault.approveTransfer(0);

        // 2nd try to approve
        vm.startPrank(signer2);
        vault.approveTransfer(0);

        // 3rd try to approve
        vm.startPrank(signer3);
        vault.approveTransfer(0);

        (,, uint256 approvals,) = vault.getTransfer(0);
        assertEq(approvals, 3);
    }

    function test_ApproveTransferEmitTransferApproved() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        vm.expectEmit(true, true, false, false);
        emit VaultMultisig.TransferApproved(0, signer2);

        vm.startPrank(signer2);
        vault.approveTransfer(0);
    }

    function test_executeTranferWorks() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.QuorumHasNotBeenReached.selector, 0));
        vault.executeTransfer(0);

        vm.startPrank(signer2);
        vault.approveTransfer(0);

        vm.expectEmit(true, false, false, false);
        emit VaultMultisig.TransferExecuted(0);
        vault.executeTransfer(0);

        vm.expectRevert(abi.encodeWithSelector(VaultMultisig.TransferIsAlreadyExecuted.selector, 0));
        vault.executeTransfer(0);

        (,,, bool executed) = vault.getTransfer(0);
        assertTrue(executed);
    }

    function test_hasSignerdTransferWorks() public {
        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        assertTrue(vault.hasSignedTransfer(0, signer1));
    }

    function test_getTransferCountWorks() public {
        assertEq(vault.getTransferCount(), 0);

        vm.startPrank(signer1);
        fundVault(1 ether);
        vault.initiateTransfer(defaultRecipient, 1 ether);

        assertEq(vault.getTransferCount(), 1);
    }

    function test_onlyMultisigSignerModifierExpectRevert() public {
        vm.prank(stranger);
        fundVault(1 ether);
        vm.expectRevert(VaultMultisig.InvalidMultisigSigner.selector);
        vault.initiateTransfer(defaultRecipient, 1 ether);
    }

    function test_constructorShouldRevertSignersArrayCannotBeEmpty() public {
        address[] memory empty;
        vm.expectRevert(VaultMultisig.SignersArrayCannotBeEmpty.selector);
        new VaultMultisig(empty, 2);
    }

    function test_constructorShouldRevertQuorumGreaterThanSigners() public {
        vm.expectRevert(VaultMultisig.QuorumGreaterThanSigners.selector);
        new VaultMultisig(signers, 4);
    }

    function fundVault(uint256 _amount) internal {
        vm.deal(address(vault), _amount);
    }
}
