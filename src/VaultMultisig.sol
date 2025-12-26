// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract VaultMultisig {
    uint256 public quorum;

    uint256 public transfersCount;

    error SignersArrayCantBeEmpty();
    error QuorumGreaterThanSigners();
    error QuorumCannotBeZero();
    error InvalidRecipient();
    error InvalidAmount();
    error InvalidMultiSigSigner();
    error TransferAlreadyExecuted(uint256 _transferId);
    error SignerAlreadyApproved(address _signer);
    error NotEnoughApprovals();
    error InsufficientContractBalance();
    error TransferFailed(uint256 _transferId);

    struct Transfer {
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
        mapping(address => bool) approved;
    }

    modifier onlyMultiSigSigner() {
        if (!multiSigSigners[msg.sender]) {
            revert InvalidMultiSigSigner();
        }
        _;
    }

    event TransferInitiated(uint256 indexed transferId, address indexed to, uint256 amount);

    event TransferApproved(uint256 indexed transferId, address indexed signer);

    event TransferExecuted(uint256 indexed transferId, address indexed to, uint256 amount);

    mapping(uint256 => Transfer) private transfers;

    mapping(address => bool) private multiSigSigners;

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

    function getTransferInfo(uint256 _transferId)
        external
        view
        returns (address to, uint256 amount, uint256 approvals, bool executed)
    {
        Transfer storage transfer = transfers[_transferId];
        return (transfer.to, transfer.amount, transfer.approvals, transfer.executed);
    }

    function hasSignerApproved(uint256 _transferId, address _signer) external view returns (bool) {
        Transfer storage transfer = transfers[_transferId];
        return transfer.approved[_signer];
    }

    function getTransferCount() external view returns (uint256) {
        return transfersCount;
    }

    receive() external payable {}
}
