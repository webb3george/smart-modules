// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IVaultMultisig.sol";

/// @title VaultMultisig
/// @notice A multi-signature vault contract that requires multiple approvals for transfers
/// @author webb3george
contract VaultMultisig is IVaultMultisig {
    uint256 public quorum;

    uint256 public transfersCount;

    /// @notice Modifier to restrict function access to multi-signature signers only
    modifier onlyMultiSigSigner() {
        if (!multiSigSigners[msg.sender]) {
            revert InvalidMultiSigSigner();
        }
        _;
    }

    /// @dev Mapping to store transfer requests
    mapping(uint256 => Transfer) private transfers;

    /// @dev Mapping to store multi-signature signers
    mapping(address => bool) private multiSigSigners;

    /// @notice Constructor to initialize the multi-signature vault
    /// @param _signers Array of multi-signature signer addresses
    /// @param _quorum Number of required approvals for executing a transfer
    constructor(address[] memory _signers, uint256 _quorum) {
        if (_signers.length == 0) {
            revert SignersArrayCantBeEmpty();
        }
        if (_quorum > _signers.length) {
            revert QuorumGreaterThanSigners();
        }
        if (_quorum == 0) {
            revert QuorumCannotBeZero();
        }

        for (uint256 i = 0; i < _signers.length; i++) {
            multiSigSigners[_signers[i]] = true;
        }
        quorum = _quorum;
    }

    /// @inheritdoc IVaultMultisig
    function initiateTransfer(address _to, uint256 _amount) external onlyMultiSigSigner {
        if (_to == address(0)) {
            revert InvalidRecipient();
        }
        if (_amount == 0) {
            revert InvalidAmount();
        }

        uint256 transferId = transfersCount++;
        Transfer storage transfer = transfers[transferId];
        transfer.to = _to;
        transfer.amount = _amount;
        transfer.approvals = 0;
        transfer.executed = false;
        transfer.approved[msg.sender] = true;

        emit TransferInitiated(transferId, _to, _amount);
    }

    /// @inheritdoc IVaultMultisig
    function approveTransfer(uint256 _transferId) external onlyMultiSigSigner {
        Transfer storage transfer = transfers[_transferId];

        if (transfer.executed) {
            revert TransferAlreadyExecuted(_transferId);
        }
        if (transfer.approved[msg.sender]) {
            revert SignerAlreadyApproved(msg.sender);
        }

        transfer.approved[msg.sender] = true;
        transfer.approvals++;

        emit TransferApproved(_transferId, msg.sender);
    }

    /// @inheritdoc IVaultMultisig
    function executeTransfer(uint256 _transferId) external onlyMultiSigSigner {
        Transfer storage transfer = transfers[_transferId];

        if (transfer.executed) {
            revert TransferAlreadyExecuted(_transferId);
        }
        if (transfer.approvals < quorum) {
            revert NotEnoughApprovals();
        }

        uint256 balance = address(this).balance;
        if (balance < transfer.amount) {
            revert InsufficientContractBalance();
        }
        (bool success,) = transfer.to.call{value: transfer.amount}("");
        if (!success) {
            revert TransferFailed(_transferId);
        }

        transfer.executed = true;

        emit TransferExecuted(_transferId, transfer.to, transfer.amount);
    }

    /// @inheritdoc IVaultMultisig
    function getTransferInfo(uint256 _transferId)
        external
        view
        returns (address to, uint256 amount, uint256 approvals, bool executed)
    {
        Transfer storage transfer = transfers[_transferId];
        return (transfer.to, transfer.amount, transfer.approvals, transfer.executed);
    }

    /// @inheritdoc IVaultMultisig
    function hasSignerApproved(uint256 _transferId, address _signer) external view returns (bool) {
        Transfer storage transfer = transfers[_transferId];
        return transfer.approved[_signer];
    }

    /// @inheritdoc IVaultMultisig
    function getTransferCount() external view returns (uint256) {
        return transfersCount;
    }

    /// @notice Fallback function to accept Ether deposits
    receive() external payable {}
}
