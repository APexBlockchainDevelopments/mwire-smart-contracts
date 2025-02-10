// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {PaymentForwarder} from "../../src/PaymentForwarder.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test, console} from "forge-std/Test.sol";
import {MockUSDC} from "../../src/mocks/MockUSDC.sol";

contract PaymentForwarderTest is Test {
    PaymentForwarder paymentForwarder;
    MockUSDC usdc;
    address multiSigWallet = address(0x123456);
    address feeDistributor = makeAddr("feeDistributor");

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        usdc = new MockUSDC(); // Deploy mock USDC

        address[] memory teamMembers = new address[](3);
        teamMembers[0] = address(0x1);
        teamMembers[1] = address(0x2);
        teamMembers[2] = address(0x3);

        uint256[] memory shares = new uint256[](3);
        shares[0] = 3000; // 30%
        shares[1] = 4000; // 40%
        shares[2] = 3000; // 30%

        // Deploy the proxy contract
        PaymentForwarder implementation = new PaymentForwarder();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,address[],uint256[])",
                address(usdc),
                multiSigWallet,
                feeDistributor,
                200, // 2% fee
                teamMembers,
                shares
            )
        );

        paymentForwarder = PaymentForwarder(address(proxy));

        // Verify that the initialization is correct
        assertEq(paymentForwarder.feePercent(), 200, "Fee percent should be 2%");
        assertEq(paymentForwarder.multiSigWallet(), multiSigWallet, "Multi-sig wallet mismatch");
        assertEq(paymentForwarder.feeDistributor(), feeDistributor, "Fee distributor is not set");
        assertEq(paymentForwarder.totalShares(), 10000, "Total shares should equal 10000 basis points");

        usdc.mint(user1, 1000e18);
    }

    function testTakeFee() public {
        uint256 transferAmount = 100e18;
        uint256 expectedFee = (transferAmount * paymentForwarder.feePercent()) / 10000;
        uint256 expectedRecipientAmount = transferAmount - expectedFee;
        
        // Store initial balances
        uint256 initialBalanceUser1 = usdc.balanceOf(user1);
        uint256 initialBalanceUser2 = usdc.balanceOf(user2);
        uint256 initialBalanceForwarder = usdc.balanceOf(address(paymentForwarder));
    
        // Approve the contract to spend `transferAmount`
        vm.startPrank(user1);
        usdc.approve(address(paymentForwarder), transferAmount);
        paymentForwarder.sendPayment(user2, transferAmount);
        vm.stopPrank();
    
        // Assertions
        assertEq(usdc.balanceOf(user1), initialBalanceUser1 - transferAmount, "User1 balance incorrect");
        assertEq(usdc.balanceOf(user2), initialBalanceUser2 + expectedRecipientAmount, "User2 balance incorrect");
        assertEq(usdc.balanceOf(address(paymentForwarder)), initialBalanceForwarder + expectedFee, "Forwarder fee balance incorrect");
    }

    function testDistributeFees() public {
        uint256 transferAmount = 100e18;
        uint256 expectedFee = (transferAmount * paymentForwarder.feePercent()) / 10000;
    
        // Approve and process a payment to accumulate fees
        vm.startPrank(user1);
        usdc.approve(address(paymentForwarder), transferAmount);
        paymentForwarder.sendPayment(user2, transferAmount);
        vm.stopPrank();
    
        // Confirm fees are stored in the contract before distribution
        assertEq(paymentForwarder.getAccruedFees(), expectedFee, "Total fees collected mismatch before distribution");
    
        // Ensure only multi-sig wallet can distribute fees
        vm.expectRevert("Only fee distributor can distribute fees");
        paymentForwarder.distributeFees();
    
        // Store initial balances of team members
        address[] memory teamMembers = paymentForwarder.getTeamMembers();
        uint256[] memory initialBalances = new uint256[](teamMembers.length);
        for (uint256 i = 0; i < 3; i++) {
            initialBalances[i] = usdc.balanceOf(teamMembers[i]);
        }
    
        // Multi-sig wallet distributes fees
        vm.prank(feeDistributor);
        paymentForwarder.distributeFees();
    
        // Ensure total fees collected reset to zero
        assertEq(paymentForwarder.getAccruedFees(), 0, "Total fees collected should be zero after distribution");  //Total Fees naming?? bad name
    
        // Verify each team member received their correct share
        for (uint256 i = 0; i < teamMembers.length; i++) {
            uint256 expectedShare = (expectedFee * paymentForwarder.memberShares(teamMembers[i])) / paymentForwarder.totalShares();
            uint256 newBalance = usdc.balanceOf(teamMembers[i]);
            assertEq(newBalance, initialBalances[i] + expectedShare, "Incorrect fee distribution for team member");
        }
    }
    
    
}
