// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}


contract PaymentForwarder {
    IERC20 public immutable usdc; // USDC token contract
    address public immutable multiSigWallet; // Multi-sig wallet address
    uint256 public feePercent; // Fee percentage (e.g., 2% = 200 basis points)
    uint256 public totalFeesCollected; // Tracks accumulated fees in USDC

    address[] public teamMembers; // Team members receiving fees
    mapping(address => uint256) public memberShares; // Basis points of each member's share (e.g., 2500 = 25%)
    uint256 public totalShares; // Sum of all shares (should equal 10,000 basis points)

    event TeamUpdated(address[] newTeamMembers, uint256[] newShares);
    event PaymentProcessed(address indexed payer, address indexed recipient, uint256 amount, uint256 fee);
    event FeesDistributed(uint256 totalFees);

    constructor(
        address _usdc,
        address _multiSigWallet,
        uint256 _feePercent, //How much the 'cut' is
        address[] memory _teamMembers, //Any one that gets a piece of the fees
        //Team members:
        //Alex -> 0x1
        //Mike  -> 0x2
        //Roger -> 0x3
        //Austin -> 0x4
        //mwire Distribution Referral Wallet -> 0x5
        uint256[] memory _shares
    ) {
        require(_feePercent <= 10000, "Fee percent too high");
        require(_multiSigWallet != address(0), "Multi-sig wallet cannot be zero");
        require(_usdc != address(0), "USDC token cannot be zero address");
        require(_teamMembers.length == _shares.length, "Team and shares mismatch");

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
}



//Upgradeable = Good idea!
//Auto distribute? 