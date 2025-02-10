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
                "initialize(address,address,uint256,address[],uint256[])",
                address(usdc),
                multiSigWallet,
                200, // 2% fee
                teamMembers,
                shares
            )
        );

        paymentForwarder = PaymentForwarder(address(proxy));

        // Verify that the initialization is correct
        assertEq(paymentForwarder.feePercent(), 200, "Fee percent should be 2%");
        assertEq(paymentForwarder.multiSigWallet(), multiSigWallet, "Multi-sig wallet mismatch");
        assertEq(paymentForwarder.totalShares(), 10000, "Total shares should equal 10000 basis points");
    }
}
