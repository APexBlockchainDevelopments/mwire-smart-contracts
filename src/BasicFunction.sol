// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;


import {UUPSUpgradeable} from "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}


contract PaymentForwarder is OwnableUpgradeable, UUPSUpgradeable {
    uint256 public feePercent; // Fee percentage (e.g., 2% = 200 basis points)
    uint256 public totalFeesCollected; // Tracks accumulated fees in USDC
    uint256 public totalShares; // Sum of all shares (should equal 10,000 basis points)

    IERC20 public usdc; // USDC token contract
    address public multiSigWallet; // Multi-sig wallet address

    address[] public teamMembers; // Team members receiving fees

    mapping(address => uint256) public memberShares; // Basis points of each member's share (e.g., 2500 = 25%)

    event TeamUpdated(address[] newTeamMembers, uint256[] newShares);
    event PaymentProcessed(address indexed payer, address indexed recipient, uint256 amount, uint256 fee);
    event FeesDistributed(uint256 totalFees);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _usdc,
        address _multiSigWallet,
        uint256 _feePercent,
        address[] memory _teamMembers,
        uint256[] memory _shares
    ) public initializer {
        require(_feePercent <= 10000, "Fee percent too high");
        require(_multiSigWallet != address(0), "Multi-sig wallet cannot be zero");
        require(_usdc != address(0), "USDC token cannot be zero address");
        require(_teamMembers.length == _shares.length, "Team and shares mismatch");

        __Ownable_init(_multiSigWallet);
        __UUPSUpgradeable_init();

        uint256 _totalShares = 0;
        for (uint256 i = 0; i < _shares.length; i++) {
            require(_teamMembers[i] != address(0), "Team member cannot be zero");
            require(_shares[i] > 0, "Share must be greater than zero");
            memberShares[_teamMembers[i]] = _shares[i];
            _totalShares += _shares[i];
        }

        require(_totalShares == 10000, "Total shares must equal 10000 basis points");

        usdc = IERC20(_usdc);
        multiSigWallet = _multiSigWallet;
        feePercent = _feePercent;
        teamMembers = _teamMembers;
        totalShares = _totalShares;
    }

    /// @dev Users must approve this contract before calling this function
    //Receipt = Merchant
    function sendPayment(address recipient, uint256 totalAmount) external {
        require(recipient != address(0), "Recipient cannot be zero");
        require(totalAmount > 0, "Amount must be greater than zero");

        uint256 fee = (totalAmount * feePercent) / 10000;
        uint256 amountAfterFee = totalAmount - fee;

        // Transfer funds from sender to contract
        require(usdc.transferFrom(msg.sender, address(this), totalAmount), "USDC transfer failed");

        // Forward remaining funds to recipient
        require(usdc.transfer(recipient, amountAfterFee), "USDC transfer to recipient failed");

        // Accumulate fee
        totalFeesCollected += fee;

        emit PaymentProcessed(msg.sender, recipient, totalAmount, fee);
    }

    /// @dev Allows the multi-sig wallet to distribute accumulated fees
    function distributeFees() external {
        require(msg.sender == multiSigWallet, "Only multi-sig wallet can distribute fees");
        require(totalFeesCollected > 0, "No fees to distribute");

        uint256 feesToDistribute = totalFeesCollected;
        totalFeesCollected = 0; // Reset the fee counter

        // Distribute fees to team members
        for (uint256 i = 0; i < teamMembers.length; i++) {
            address member = teamMembers[i];
            uint256 share = (feesToDistribute * memberShares[member]) / totalShares;
            require(usdc.transfer(member, share), "Fee distribution failed");
        }

        emit FeesDistributed(feesToDistribute);
    }

    /// @dev Updates the team structure (members and their shares)
    function updateTeamStructure(address[] calldata _newTeamMembers, uint256[] calldata _newShares) external {
        require(msg.sender == multiSigWallet, "Only multi-sig wallet can update the team");
        require(_newTeamMembers.length == _newShares.length, "Team and shares mismatch");

        uint256 _totalShares = 0;
        for (uint256 i = 0; i < _newShares.length; i++) {
            require(_newTeamMembers[i] != address(0), "Team member cannot be zero");
            require(_newShares[i] > 0, "Share must be greater than zero");
            _totalShares += _newShares[i];
        }

        require(_totalShares == 10000, "Total shares must equal 10000 basis points");

        // Clear existing team members and shares
        for (uint256 i = 0; i < teamMembers.length; i++) {
            delete memberShares[teamMembers[i]];
        }

        // Update the team structure
        teamMembers = _newTeamMembers;
        for (uint256 i = 0; i < _newTeamMembers.length; i++) {
            memberShares[_newTeamMembers[i]] = _newShares[i];
        }
        totalShares = _totalShares;

        emit TeamUpdated(_newTeamMembers, _newShares);
    }

    function updateFees(uint256 _newFeePercent) public {
        require(_newFeePercent <= 10000, "Fee percent too high");
        feePercent = _newFeePercent;
    }


    function upgradeImplementation(address newImplementation) external onlyOwner() {
        _authorizeUpgrade(newImplementation);
        upgradeToAndCall(newImplementation, "");
    }

        /**
     * @notice Authorizes an upgrade to the contract implementation.
     * @dev Implements the UUPS proxy pattern's authorization mechanism. This function is called during upgrades to validate the new implementation.
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override{}

}



//Upgradeable = Good idea!