// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IVaultMultisig
/// @notice Interface for a multi-signature vault contract
/// @author webb3george
interface IVaultMultisig {
    /// @notice Struct to store information about a transfer
    struct Transfer {
        address to; /// @notice Recipient address
        uint256 amount; /// @notice Transfer amount
        uint256 approvals; /// @notice Number of approvals
        bool executed; /// @notice Whether the transfer has been executed
        mapping(address => bool) approved; /// @notice Mapping of signers who have approved the transfer
    }

    // ----------------------------------------------------------------
    // Errors
    // ----------------------------------------------------------------

    /// @notice Thrown when the signers array is empty
    error SignersArrayCantBeEmpty();
    /// @notice Thrown when the quorum is greater than the number of signers
    error QuorumGreaterThanSigners();
    /// @notice Thrown when the quorum is set to zero
    error QuorumCannotBeZero();
    /// @notice Thrown when the recipient address is invalid
    error InvalidRecipient();
    /// @notice Thrown when the transfer amount is invalid
    error InvalidAmount();
    /// @notice Thrown when the caller is not a valid multi-signature signer
    error InvalidMultiSigSigner();
    /// @notice Thrown when a transfer has already been executed
    error TransferAlreadyExecuted(uint256 _transferId);
    /// @notice Thrown when a signer has already approved a transfer
    error SignerAlreadyApproved(address _signer);
    /// @notice Thrown when there are not enough approvals to execute a transfer
    error NotEnoughApprovals();
    /// @notice Thrown when the contract has insufficient balance to execute a transfer
    error InsufficientContractBalance();
    /// @notice Thrown when a transfer fails
    error TransferFailed(uint256 _transferId);

    // ----------------------------------------------------------------
    // Events
    // ----------------------------------------------------------------

    /// @notice Emitted when a transfer is initiated
    /// @param transferId The ID of the initiated transfer
    /// @param to The recipient address
    /// @param amount The amount to be transferred
    event TransferInitiated(uint256 indexed transferId, address indexed to, uint256 amount);

    /// @notice Emitted when a transfer is approved by a signer
    /// @param transferId The ID of the approved transfer
    /// @param signer The address of the signer who approved the transfer
    event TransferApproved(uint256 indexed transferId, address indexed signer);

    /// @notice Emitted when a transfer is executed
    /// @param transferId The ID of the executed transfer
    /// @param to The recipient address
    /// @param amount The amount that was transferred
    event TransferExecuted(uint256 indexed transferId, address indexed to, uint256 amount);

    // ----------------------------------------------------------------
    // Functions
    // ----------------------------------------------------------------

    /// @notice Initiates a transfer request
    /// @param _to The recipient address
    /// @param _amount The amount to be transferred
    function initiateTransfer(address _to, uint256 _amount) external;

    /// @notice Approves a transfer request
    /// @param _transferId The ID of the transfer to approve
    function approveTransfer(uint256 _transferId) external;

    /// @notice Executes a transfer request if it has enough approvals
    /// @param _transferId The ID of the transfer to execute
    function executeTransfer(uint256 _transferId) external;

    /// @notice Retrieves information about a specific transfer
    /// @param _transferId The ID of the transfer
    /// @return to The recipient address
    /// @return amount The amount to be transferred
    /// @return approvals The number of approvals the transfer has received
    /// @return executed Whether the transfer has been executed
    function getTransferInfo(uint256 _transferId)
        external
        view
        returns (address to, uint256 amount, uint256 approvals, bool executed);

    /// @notice Checks if a specific signer has approved a transfer
    /// @param _transferId The ID of the transfer
    /// @param _signer The address of the signer
    /// @return True if the signer has approved the transfer, false otherwise
    function hasSignerApproved(uint256 _transferId, address _signer) external view returns (bool);

    /// @notice Retrieves the total number of transfers initiated
    /// @return The total number of transfers
    function getTransferCount() external view returns (uint256);
}
